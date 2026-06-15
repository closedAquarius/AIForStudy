import json
import random
from datetime import datetime

from flask import Blueprint, request

from api_utils import success, fail, require_current_user
from db import db_cursor

practice_bp = Blueprint("practice_api", __name__)

ALLOWED_COUNTS = {5, 10, 20, 50}
ALLOWED_MODES = {"new_first", "wrong_first"}
OBJECTIVE_TYPES = {"single_choice", "multiple_choice", "true_false"}


def _parse_json(value, fallback=None):
    if fallback is None:
        fallback = {}
    if value is None or value == "":
        return fallback
    if isinstance(value, (dict, list)):
        return value
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return fallback


def _normalize(value):
    return "".join(str(value or "").strip().split()).lower()


def _bool_value(value):
    normalized = _normalize(value)
    if normalized in {"true", "t", "1", "yes", "y", "正确", "对", "是"}:
        return True
    if normalized in {"false", "f", "0", "no", "n", "错误", "错", "否"}:
        return False
    return None


def _type_label(question_type):
    labels = {
        "single_choice": "单选题",
        "multiple_choice": "多选题",
        "true_false": "判断题",
        "blank": "填空题",
        "short_answer": "简答题",
        "essay": "论述题",
    }
    return labels.get(question_type or "", question_type or "题目")


def _row_status(row):
    latest = row.get("latest_is_correct")
    if latest is None:
        return "unpracticed"
    return "correct" if int(latest) == 1 else "wrong"


def _status_label(status):
    if status == "unpracticed":
        return "未刷"
    if status == "wrong":
        return "错题"
    return "已刷"


def _bank_visible(cursor, bank_id, user_id):
    cursor.execute(
        """
        SELECT id, owner_user_id, visibility
        FROM question_banks
        WHERE id=%s
          AND (owner_user_id=%s OR visibility='public')
        LIMIT 1
        """,
        (bank_id, user_id),
    )
    return cursor.fetchone()


def _load_question_pool(cursor, bank_id, user_id):
    cursor.execute(
        """
        SELECT
          q.id, q.type, q.stem, q.analysis, q.difficulty, q.score, q.knowledge_point,
          latest.is_correct AS latest_is_correct,
          uqr.is_favorite, uqr.note AS personal_note
        FROM questions q
        LEFT JOIN (
          SELECT pa.question_id, pa.is_correct
          FROM practice_answers pa
          JOIN (
            SELECT question_id, MAX(id) AS latest_id
            FROM practice_answers
            WHERE user_id=%s
            GROUP BY question_id
          ) last_pa ON last_pa.latest_id = pa.id
        ) latest ON latest.question_id = q.id
        LEFT JOIN user_question_records uqr
          ON uqr.question_id = q.id
         AND uqr.user_id = %s
        WHERE q.question_bank_id=%s
          AND q.status='active'
        ORDER BY q.id ASC
        """,
        (user_id, user_id, bank_id),
    )
    return cursor.fetchall()


def _take_random(bucket, needed, used_ids):
    candidates = [row for row in bucket if row["id"] not in used_ids]
    random.shuffle(candidates)
    picked = candidates[:max(0, needed)]
    for row in picked:
        used_ids.add(row["id"])
    return picked


def _build_sample(pool, count, mode):
    buckets = {
        "unpracticed": [],
        "correct": [],
        "wrong": [],
    }
    for row in pool:
        buckets[_row_status(row)].append(row)

    if mode == "wrong_first":
        quotas = {
            "wrong": count * 6 // 10,
            "correct": count * 2 // 10,
            "unpracticed": count - (count * 6 // 10) - (count * 2 // 10),
        }
        order = ["wrong", "correct", "unpracticed"]
    else:
        quotas = {
            "unpracticed": count * 6 // 10,
            "correct": count * 2 // 10,
            "wrong": count - (count * 6 // 10) - (count * 2 // 10),
        }
        order = ["unpracticed", "correct", "wrong"]

    selected = []
    used_ids = set()
    for category in order:
        selected.extend(_take_random(buckets[category], quotas[category], used_ids))

    # 某一类题目不足时，用其它类型随机补齐，避免抽题数量不足。
    remaining = [row for row in pool if row["id"] not in used_ids]
    random.shuffle(remaining)
    for row in remaining:
        if len(selected) >= count:
            break
        selected.append(row)
        used_ids.add(row["id"])

    random.shuffle(selected)
    return selected[:count]


def _load_options_and_answers(cursor, question_ids):
    if not question_ids:
        return {}, {}

    placeholders = ",".join(["%s"] * len(question_ids))
    cursor.execute(
        f"""
        SELECT question_id, option_key, content, is_correct, sort_order
        FROM question_options
        WHERE question_id IN ({placeholders})
        ORDER BY question_id ASC, sort_order ASC, option_key ASC
        """,
        tuple(question_ids),
    )
    options_map = {}
    for row in cursor.fetchall():
        qid = row["question_id"]
        options_map.setdefault(qid, []).append({
            "optionKey": row.get("option_key") or "",
            "content": row.get("content") or "",
            "isCorrect": int(row.get("is_correct") or 0),
        })

    cursor.execute(
        f"""
        SELECT question_id, answer_text, answer_json, is_primary
        FROM question_answers
        WHERE question_id IN ({placeholders})
        ORDER BY question_id ASC, is_primary DESC, id ASC
        """,
        tuple(question_ids),
    )
    answers_map = {}
    for row in cursor.fetchall():
        qid = row["question_id"]
        answers_map.setdefault(qid, []).append({
            "answerText": row.get("answer_text") or "",
            "answerJson": row.get("answer_json"),
            "isPrimary": int(row.get("is_primary") or 0),
        })

    return options_map, answers_map


def _serialize_question(row, seq, options_map, include_answer=False, answers_map=None):
    qid = row["id"]
    item = {
        "id": qid,
        "seq": seq,
        "type": row.get("type") or "",
        "typeLabel": _type_label(row.get("type")),
        "stem": row.get("stem") or "",
        "analysis": row.get("analysis") or "",
        "difficulty": int(row.get("difficulty") or 1),
        "score": float(row.get("score") or 0),
        "knowledgePoint": row.get("knowledge_point") or "",
        "practiceStatus": _row_status(row),
        "practiceStatusLabel": _status_label(_row_status(row)),
        "isFavorite": int(row.get("is_favorite") or 0),
        "personalNote": row.get("personal_note") or "",
        "options": options_map.get(qid, []),
    }
    if include_answer and answers_map is not None:
        answers = answers_map.get(qid, [])
        item["answerText"] = "；".join([answer["answerText"] for answer in answers if answer["answerText"]])
    return item


def _fetch_session_questions(cursor, session, include_answer=False):
    config = _parse_json(session.get("filter_config"), {})
    question_ids = config.get("question_ids") or []
    if not question_ids:
        return []

    placeholders = ",".join(["%s"] * len(question_ids))
    cursor.execute(
        f"""
        SELECT
          q.id, q.type, q.stem, q.analysis, q.difficulty, q.score, q.knowledge_point,
          latest.is_correct AS latest_is_correct,
          uqr.is_favorite, uqr.note AS personal_note
        FROM questions q
        LEFT JOIN (
          SELECT pa.question_id, pa.is_correct
          FROM practice_answers pa
          JOIN (
            SELECT question_id, MAX(id) AS latest_id
            FROM practice_answers
            WHERE user_id=%s
            GROUP BY question_id
          ) last_pa ON last_pa.latest_id = pa.id
        ) latest ON latest.question_id = q.id
        LEFT JOIN user_question_records uqr
          ON uqr.question_id = q.id
         AND uqr.user_id = %s
        WHERE q.id IN ({placeholders})
        """,
        tuple([session["user_id"], session["user_id"]] + question_ids),
    )
    rows_by_id = {row["id"]: row for row in cursor.fetchall()}
    options_map, answers_map = _load_options_and_answers(cursor, question_ids)

    questions = []
    for index, qid in enumerate(question_ids):
        row = rows_by_id.get(qid)
        if row:
            questions.append(_serialize_question(row, index + 1, options_map, include_answer, answers_map))
    return questions


def _answer_texts(answers):
    texts = []
    for item in answers:
        text = item.get("answerText") or ""
        if text.strip():
            texts.append(text.strip())
        answer_json = _parse_json(item.get("answerJson"), None)
        if isinstance(answer_json, list):
            for value in answer_json:
                if str(value).strip():
                    texts.append(str(value).strip())
        elif isinstance(answer_json, dict):
            for key in ["answer", "answers", "correct", "value"]:
                value = answer_json.get(key)
                if isinstance(value, list):
                    texts.extend([str(v).strip() for v in value if str(v).strip()])
                elif value is not None and str(value).strip():
                    texts.append(str(value).strip())
    return texts


def _split_multi(value):
    if isinstance(value, list):
        return sorted([str(item).strip().upper() for item in value if str(item).strip()])
    return sorted([item.strip().upper() for item in str(value or "").split(",") if item.strip()])


def _judge_answer(question, options, answers, user_answer):
    q_type = question.get("type") or ""
    correct_keys = sorted([item["optionKey"].strip().upper() for item in options if int(item.get("isCorrect") or 0) == 1])
    answer_texts = _answer_texts(answers)

    if q_type == "multiple_choice":
        return _split_multi(user_answer) == correct_keys, ",".join(correct_keys) if correct_keys else "；".join(answer_texts)

    if q_type == "single_choice":
        if correct_keys:
            return str(user_answer or "").strip().upper() == correct_keys[0], correct_keys[0]
        normalized_user = _normalize(user_answer)
        normalized_answers = [_normalize(text) for text in answer_texts]
        return normalized_user in normalized_answers, "；".join(answer_texts)

    if q_type == "true_false":
        if correct_keys:
            return str(user_answer or "").strip().upper() == correct_keys[0], correct_keys[0]
        user_bool = _bool_value(user_answer)
        for text in answer_texts:
            answer_bool = _bool_value(text)
            if user_bool is not None and answer_bool is not None:
                return user_bool == answer_bool, text
        return _normalize(user_answer) in [_normalize(text) for text in answer_texts], "；".join(answer_texts)

    normalized_user = _normalize(user_answer)
    normalized_answers = [_normalize(text) for text in answer_texts]
    return normalized_user != "" and normalized_user in normalized_answers, "；".join(answer_texts)


@practice_bp.post("/practice/start")
def start_practice():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    try:
        bank_id = int(body.get("bank_id") or 0)
        count = int(body.get("count") or 10)
    except (TypeError, ValueError):
        return fail("刷题参数错误")
    mode = (body.get("mode") or "new_first").strip()

    if bank_id <= 0:
        return fail("题库 ID 不能为空")
    if count not in ALLOWED_COUNTS:
        return fail("刷题数量只能选择 5、10、20、50")
    if mode not in ALLOWED_MODES:
        return fail("刷题模式只能选择新题优先或错题优先")

    with db_cursor(commit=True) as cursor:
        if not _bank_visible(cursor, bank_id, user["id"]):
            return fail("题库不存在或无权访问", 404)

        pool = _load_question_pool(cursor, bank_id, user["id"])
        if not pool:
            return fail("当前题库暂无可刷题目")

        selected = _build_sample(pool, count, mode)
        question_ids = [row["id"] for row in selected]
        if not question_ids:
            return fail("未抽取到题目，请先导入题目")

        db_mode = "review" if mode == "new_first" else "wrong_only"
        filter_config = {
            "selected_mode": mode,
            "requested_count": count,
            "actual_count": len(question_ids),
            "question_ids": question_ids,
        }
        cursor.execute(
            """
            INSERT INTO practice_sessions
              (user_id, question_bank_id, mode, filter_config, started_at, total_count, correct_count, wrong_count, duration_seconds)
            VALUES
              (%s, %s, %s, %s, NOW(), %s, 0, 0, 0)
            """,
            (user["id"], bank_id, db_mode, json.dumps(filter_config, ensure_ascii=False), len(question_ids)),
        )
        session_id = cursor.lastrowid

        options_map, _ = _load_options_and_answers(cursor, question_ids)
        questions = [
            _serialize_question(row, index + 1, options_map, False, None)
            for index, row in enumerate(selected)
        ]

    return success({
        "sessionId": session_id,
        "bankId": bank_id,
        "mode": mode,
        "requestedCount": count,
        "actualCount": len(question_ids),
        "questions": questions,
    }, "刷题会话创建成功", 201)


@practice_bp.get("/practice-sessions/<int:session_id>")
def get_practice_session(session_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    with db_cursor() as cursor:
        cursor.execute(
            """
            SELECT ps.*, qb.name AS bank_name
            FROM practice_sessions ps
            LEFT JOIN question_banks qb ON qb.id = ps.question_bank_id
            WHERE ps.id=%s AND ps.user_id=%s
            LIMIT 1
            """,
            (session_id, user["id"]),
        )
        session = cursor.fetchone()
        if not session:
            return fail("刷题会话不存在", 404)

        questions = _fetch_session_questions(cursor, session, include_answer=False)

    return success({
        "sessionId": session["id"],
        "bankId": session["question_bank_id"],
        "bankName": session.get("bank_name") or "今日复习",
        "mode": _parse_json(session.get("filter_config"), {}).get("selected_mode") or session.get("mode"),
        "totalCount": int(session.get("total_count") or len(questions)),
        "startedAt": str(session.get("started_at") or ""),
        "finishedAt": str(session.get("finished_at") or ""),
        "questions": questions,
    })


@practice_bp.post("/practice-sessions/<int:session_id>/submit")
def submit_practice_session(session_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    submitted_answers = body.get("answers") or []
    if not isinstance(submitted_answers, list):
        return fail("answers 必须是数组")

    answer_map = {}
    for item in submitted_answers:
        if isinstance(item, dict) and item.get("question_id") is not None:
            try:
                qid = int(item.get("question_id"))
            except (TypeError, ValueError):
                continue
            answer_map[qid] = {
                "user_answer": str(item.get("user_answer") or ""),
                "used_seconds": max(0, int(item.get("used_seconds") or 0)),
            }

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            SELECT *
            FROM practice_sessions
            WHERE id=%s AND user_id=%s
            LIMIT 1
            """,
            (session_id, user["id"]),
        )
        session = cursor.fetchone()
        if not session:
            return fail("刷题会话不存在", 404)

        config = _parse_json(session.get("filter_config"), {})
        question_ids = config.get("question_ids") or []
        if not question_ids:
            return fail("刷题会话题目为空")

        placeholders = ",".join(["%s"] * len(question_ids))
        cursor.execute(
            f"""
            SELECT id, type, stem, analysis, difficulty, score, knowledge_point
            FROM questions
            WHERE id IN ({placeholders})
            """,
            tuple(question_ids),
        )
        question_map = {row["id"]: row for row in cursor.fetchall()}
        options_map, answers_map = _load_options_and_answers(cursor, question_ids)

        correct_count = 0
        wrong_count = 0
        results = []
        for qid in question_ids:
            question = question_map.get(qid)
            if not question:
                continue
            submitted = answer_map.get(qid, {"user_answer": "", "used_seconds": 0})
            user_answer = submitted["user_answer"]
            is_correct, correct_answer = _judge_answer(
                question,
                options_map.get(qid, []),
                answers_map.get(qid, []),
                user_answer,
            )
            if is_correct:
                correct_count += 1
            else:
                wrong_count += 1

            review_status = "mastered" if is_correct else "needs_review"
            cursor.execute(
                """
                INSERT INTO practice_answers
                  (session_id, user_id, question_id, user_answer, is_correct, used_seconds, review_status, answered_at)
                VALUES
                  (%s, %s, %s, %s, %s, %s, %s, NOW())
                """,
                (session_id, user["id"], qid, user_answer, 1 if is_correct else 0, submitted["used_seconds"], review_status),
            )
            results.append({
                "questionId": qid,
                "userAnswer": user_answer,
                "isCorrect": 1 if is_correct else 0,
                "correctAnswer": correct_answer,
                "analysis": question.get("analysis") or "",
            })

        cursor.execute(
            """
            UPDATE practice_sessions
            SET finished_at=NOW(),
                total_count=%s,
                correct_count=%s,
                wrong_count=%s,
                duration_seconds=TIMESTAMPDIFF(SECOND, started_at, NOW())
            WHERE id=%s AND user_id=%s
            """,
            (len(results), correct_count, wrong_count, session_id, user["id"]),
        )

    from services.review_plan_service import ReviewPlanService
    ReviewPlanService().complete_practice_session(user["id"], session_id, results)

    accuracy = round(correct_count * 100 / len(results), 1) if results else 0
    return success({
        "sessionId": session_id,
        "totalCount": len(results),
        "correctCount": correct_count,
        "wrongCount": wrong_count,
        "accuracyRate": accuracy,
        "answers": results,
    }, "答题卡已提交")
