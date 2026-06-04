from flask import Blueprint, request

from db import db_cursor
from api_utils import success, fail, require_current_user


question_bank_bp = Blueprint("question_bank_api", __name__)


QUESTION_TYPE_LABELS = {
    "single_choice": "单选题",
    "multiple_choice": "多选题",
    "true_false": "判断题",
    "blank": "填空题",
    "short_answer": "简答题",
    "essay": "论述题",
}


def to_bank_summary(row, current_user_id):
    return {
        "id": row["id"],
        "name": row["name"],
        "description": row.get("description") or "",
        "subjectName": row.get("subject_name") or "未分类",
        "visibility": row.get("visibility") or "private",
        "sourceType": row.get("source_type") or "manual",
        "totalCount": int(row.get("total_count") or 0),
        "practicedCount": int(row.get("practiced_count") or 0),
        "wrongCount": int(row.get("wrong_count") or 0),
        "canManage": row.get("owner_user_id") == current_user_id,
        "createdAt": str(row.get("created_at") or ""),
        "updatedAt": str(row.get("updated_at") or ""),
    }


def fetch_bank_summary(cursor, bank_id, user_id):
    cursor.execute(
        """
        SELECT
          qb.id,
          qb.owner_user_id,
          qb.subject_id,
          qb.name,
          qb.description,
          qb.visibility,
          qb.source_type,
          qb.created_at,
          qb.updated_at,
          s.name AS subject_name,
          COUNT(DISTINCT q.id) AS total_count,
          COUNT(DISTINCT pa_done.question_id) AS practiced_count,
          COUNT(DISTINCT pa_wrong.question_id) AS wrong_count
        FROM question_banks qb
        LEFT JOIN subjects s ON s.id = qb.subject_id
        LEFT JOIN questions q
          ON q.question_bank_id = qb.id
         AND q.status = 'active'
        LEFT JOIN practice_answers pa_done
          ON pa_done.question_id = q.id
         AND pa_done.user_id = %s
        LEFT JOIN practice_answers pa_wrong
          ON pa_wrong.question_id = q.id
         AND pa_wrong.user_id = %s
         AND pa_wrong.is_correct = 0
        WHERE qb.id = %s
          AND (qb.owner_user_id = %s OR qb.visibility IN ('public', 'class'))
        GROUP BY
          qb.id, qb.owner_user_id, qb.subject_id, qb.name, qb.description,
          qb.visibility, qb.source_type, qb.created_at, qb.updated_at, s.name
        LIMIT 1
        """,
        (user_id, user_id, bank_id, user_id),
    )
    return cursor.fetchone()


@question_bank_bp.get("/question-banks")
def list_question_banks():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    with db_cursor() as cursor:
        cursor.execute(
            """
            SELECT
              qb.id,
              qb.owner_user_id,
              qb.subject_id,
              qb.name,
              qb.description,
              qb.visibility,
              qb.source_type,
              qb.created_at,
              qb.updated_at,
              s.name AS subject_name,
              COUNT(DISTINCT q.id) AS total_count,
              COUNT(DISTINCT pa_done.question_id) AS practiced_count,
              COUNT(DISTINCT pa_wrong.question_id) AS wrong_count
            FROM question_banks qb
            LEFT JOIN subjects s ON s.id = qb.subject_id
            LEFT JOIN questions q
              ON q.question_bank_id = qb.id
             AND q.status = 'active'
            LEFT JOIN practice_answers pa_done
              ON pa_done.question_id = q.id
             AND pa_done.user_id = %s
            LEFT JOIN practice_answers pa_wrong
              ON pa_wrong.question_id = q.id
             AND pa_wrong.user_id = %s
             AND pa_wrong.is_correct = 0
            WHERE qb.owner_user_id = %s
               OR qb.visibility IN ('public', 'class')
            GROUP BY
              qb.id, qb.owner_user_id, qb.subject_id, qb.name, qb.description,
              qb.visibility, qb.source_type, qb.created_at, qb.updated_at, s.name
            ORDER BY qb.updated_at DESC, qb.id DESC
            """,
            (user["id"], user["id"], user["id"]),
        )
        rows = cursor.fetchall()

    banks = [to_bank_summary(row, user["id"]) for row in rows]
    return success({"banks": banks}, "题库列表获取成功")


@question_bank_bp.post("/question-banks")
def create_question_bank_api():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    name = (body.get("name") or "").strip()
    description = (body.get("description") or "").strip()

    if len(name) == 0:
        return fail("题库名称不能为空")
    if len(name) > 128:
        return fail("题库名称不能超过 128 个字符")

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            INSERT INTO question_banks
              (owner_user_id, subject_id, name, description, visibility, source_type)
            VALUES
              (%s, NULL, %s, %s, 'private', 'manual')
            """,
            (user["id"], name, description),
        )
        bank_id = cursor.lastrowid
        row = fetch_bank_summary(cursor, bank_id, user["id"])

    return success({"bank": to_bank_summary(row, user["id"])}, "题库创建成功", 201)


@question_bank_bp.put("/question-banks/<int:bank_id>")
def update_question_bank_api(bank_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    name = (body.get("name") or "").strip()

    if len(name) == 0:
        return fail("题库名称不能为空")
    if len(name) > 128:
        return fail("题库名称不能超过 128 个字符")

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            UPDATE question_banks
            SET name = %s
            WHERE id = %s AND owner_user_id = %s
            """,
            (name, bank_id, user["id"]),
        )

        if cursor.rowcount == 0:
            return fail("只能修改自己创建的题库", 403)

        row = fetch_bank_summary(cursor, bank_id, user["id"])

    return success({"bank": to_bank_summary(row, user["id"])}, "题库名称已修改")


@question_bank_bp.delete("/question-banks/<int:bank_id>")
def delete_question_bank_api(bank_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            DELETE FROM question_banks
            WHERE id = %s AND owner_user_id = %s
            """,
            (bank_id, user["id"]),
        )

        if cursor.rowcount == 0:
            return fail("只能删除自己创建的题库", 403)

    return success(None, "题库已删除")

@question_bank_bp.get("/question-banks/<int:bank_id>")
def question_bank_detail_api(bank_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    with db_cursor() as cursor:
        bank_row = fetch_bank_summary(cursor, bank_id, user["id"])
        if not bank_row:
            return fail("题库不存在或无权访问", 404)

        cursor.execute(
            """
            SELECT COUNT(*) AS total_questions
            FROM questions
            WHERE question_bank_id = %s AND status = 'active'
            """,
            (bank_id,),
        )
        total_questions = int((cursor.fetchone() or {}).get("total_questions") or 0)

        cursor.execute(
            """
            SELECT COUNT(DISTINCT q.id) AS practiced_questions
            FROM questions q
            JOIN practice_answers pa ON pa.question_id = q.id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
              AND pa.user_id = %s
            """,
            (bank_id, user["id"]),
        )
        practiced_questions = int((cursor.fetchone() or {}).get("practiced_questions") or 0)

        cursor.execute(
            """
            SELECT COUNT(DISTINCT q.id) AS wrong_questions
            FROM questions q
            JOIN practice_answers pa ON pa.question_id = q.id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
              AND pa.user_id = %s
              AND pa.is_correct = 0
            """,
            (bank_id, user["id"]),
        )
        wrong_questions = int((cursor.fetchone() or {}).get("wrong_questions") or 0)

        cursor.execute(
            """
            SELECT COUNT(DISTINCT q.id) AS needs_review_questions
            FROM questions q
            JOIN practice_answers pa ON pa.question_id = q.id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
              AND pa.user_id = %s
              AND pa.review_status = 'needs_review'
            """,
            (bank_id, user["id"]),
        )
        needs_review_questions = int((cursor.fetchone() or {}).get("needs_review_questions") or 0)

        cursor.execute(
            """
            SELECT
              COUNT(pa.id) AS answer_count,
              COALESCE(SUM(CASE WHEN pa.is_correct = 1 THEN 1 ELSE 0 END), 0) AS correct_answer_count
            FROM practice_answers pa
            JOIN questions q ON q.id = pa.question_id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
              AND pa.user_id = %s
            """,
            (bank_id, user["id"]),
        )
        answer_row = cursor.fetchone() or {}
        answer_count = int(answer_row.get("answer_count") or 0)
        correct_answer_count = int(answer_row.get("correct_answer_count") or 0)
        accuracy_rate = round(correct_answer_count * 100 / answer_count, 1) if answer_count > 0 else 0

        cursor.execute(
            """
            SELECT type, COUNT(*) AS count_value
            FROM questions
            WHERE question_bank_id = %s AND status = 'active'
            GROUP BY type
            ORDER BY count_value DESC
            """,
            (bank_id,),
        )
        type_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT difficulty, COUNT(*) AS count_value
            FROM questions
            WHERE question_bank_id = %s AND status = 'active'
            GROUP BY difficulty
            ORDER BY difficulty
            """,
            (bank_id,),
        )
        difficulty_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT t.name, COUNT(*) AS count_value
            FROM question_tags qt
            JOIN tags t ON t.id = qt.tag_id
            JOIN questions q ON q.id = qt.question_id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
            GROUP BY t.id, t.name
            ORDER BY count_value DESC
            LIMIT 8
            """,
            (bank_id,),
        )
        tag_rows = cursor.fetchall()

        cursor.execute(
            """
            SELECT
              q.id,
              q.type,
              q.stem,
              q.difficulty,
              q.knowledge_point,
              GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ',') AS tag_names
            FROM questions q
            LEFT JOIN question_tags qt ON qt.question_id = q.id
            LEFT JOIN tags t ON t.id = qt.tag_id
            WHERE q.question_bank_id = %s
              AND q.status = 'active'
            GROUP BY q.id, q.type, q.stem, q.difficulty, q.knowledge_point
            ORDER BY q.created_at DESC, q.id DESC
            LIMIT 8
            """,
            (bank_id,),
        )
        question_rows = cursor.fetchall()

    def chart_ratio(value):
        if total_questions <= 0:
            return 0
        return round(int(value or 0) * 100 / total_questions, 1)

    type_distribution = [
        {
            "label": QUESTION_TYPE_LABELS.get(row["type"], row["type"]),
            "value": int(row["count_value"] or 0),
            "ratio": chart_ratio(row["count_value"]),
        }
        for row in type_rows
    ]

    difficulty_distribution = [
        {
            "label": f"难度 {row['difficulty']}",
            "value": int(row["count_value"] or 0),
            "ratio": chart_ratio(row["count_value"]),
        }
        for row in difficulty_rows
    ]

    tag_distribution = [
        {
            "label": row["name"],
            "value": int(row["count_value"] or 0),
            "ratio": chart_ratio(row["count_value"]),
        }
        for row in tag_rows
    ]

    recent_questions = []
    for row in question_rows:
        tag_names = row.get("tag_names") or ""
        recent_questions.append({
            "id": row["id"],
            "type": row["type"],
            "typeLabel": QUESTION_TYPE_LABELS.get(row["type"], row["type"]),
            "stem": row["stem"],
            "difficulty": int(row["difficulty"] or 3),
            "knowledgePoint": row.get("knowledge_point") or "",
            "tags": [item for item in tag_names.split(",") if item],
        })

    stats = {
        "totalQuestions": total_questions,
        "practicedQuestions": practiced_questions,
        "unpracticedQuestions": max(total_questions - practiced_questions, 0),
        "wrongQuestions": wrong_questions,
        "needsReviewQuestions": needs_review_questions,
        "answerCount": answer_count,
        "correctAnswerCount": correct_answer_count,
        "accuracyRate": accuracy_rate,
    }

    return success({
        "bank": to_bank_summary(bank_row, user["id"]),
        "stats": stats,
        "typeDistribution": type_distribution,
        "difficultyDistribution": difficulty_distribution,
        "tagDistribution": tag_distribution,
        "recentQuestions": recent_questions,
    }, "题库详情获取成功")