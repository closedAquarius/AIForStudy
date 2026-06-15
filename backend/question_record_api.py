from flask import Blueprint, request

from api_utils import fail, require_current_user, success
from db import db_cursor


question_record_bp = Blueprint("question_record_api", __name__)


def _record_payload(row, question_id):
    note = (row.get("note") or "") if row else ""
    updated_at = str(row.get("updated_at") or "") if row else ""
    return {
        "questionId": question_id,
        "isFavorite": int(row.get("is_favorite") or 0) if row else 0,
        "note": note,
        "updatedAt": updated_at,
    }


def _question_exists(cursor, question_id, user_id):
    cursor.execute(
        """
        SELECT q.id
        FROM questions q
        JOIN question_banks qb ON qb.id=q.question_bank_id
        WHERE q.id=%s
          AND q.status='active'
          AND (qb.owner_user_id=%s OR qb.visibility IN ('public', 'class'))
        LIMIT 1
        """,
        (question_id, user_id),
    )
    return cursor.fetchone() is not None


@question_record_bp.get("/questions/<int:question_id>/personal-record")
def get_question_record(question_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    with db_cursor() as cursor:
        if not _question_exists(cursor, question_id, user["id"]):
            return fail("题目不存在", 404)
        cursor.execute(
            """
            SELECT is_favorite, note, updated_at
            FROM user_question_records
            WHERE user_id=%s AND question_id=%s
            LIMIT 1
            """,
            (user["id"], question_id),
        )
        row = cursor.fetchone()
    return success(_record_payload(row, question_id))


@question_record_bp.put("/questions/<int:question_id>/personal-record")
def update_question_record(question_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    payload = request.get_json(silent=True) or {}
    favorite_value = payload.get("is_favorite")
    is_favorite = 1 if favorite_value is True or favorite_value == 1 else 0
    note = str(payload.get("note") or "").strip()
    if len(note) > 5000:
        return fail("笔记不能超过 5000 个字符")

    with db_cursor(commit=True) as cursor:
        if not _question_exists(cursor, question_id, user["id"]):
            return fail("题目不存在", 404)
        cursor.execute(
            """
            INSERT INTO user_question_records (user_id, question_id, is_favorite, note)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              is_favorite=VALUES(is_favorite),
              note=VALUES(note),
              updated_at=CURRENT_TIMESTAMP
            """,
            (user["id"], question_id, is_favorite, note or None),
        )
        cursor.execute(
            """
            SELECT is_favorite, note, updated_at
            FROM user_question_records
            WHERE user_id=%s AND question_id=%s
            LIMIT 1
            """,
            (user["id"], question_id),
        )
        row = cursor.fetchone()
    return success(_record_payload(row, question_id), "题目记录已保存")


@question_record_bp.get("/favorite-questions")
def list_favorite_questions():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    keyword = request.args.get("keyword", "").strip()
    try:
        page = max(1, int(request.args.get("page", "1")))
        page_size = min(100, max(1, int(request.args.get("pageSize", "50"))))
    except ValueError:
        return fail("分页参数错误")

    where = [
        "uqr.user_id=%s",
        "uqr.is_favorite=1",
        "q.status='active'",
        "(qb.owner_user_id=%s OR qb.visibility IN ('public', 'class'))",
    ]
    params = [user["id"], user["id"]]
    if keyword:
        where.append("(q.stem LIKE %s OR q.knowledge_point LIKE %s OR qb.name LIKE %s OR uqr.note LIKE %s)")
        pattern = f"%{keyword}%"
        params.extend([pattern, pattern, pattern, pattern])
    where_sql = " AND ".join(where)

    with db_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT COUNT(*) AS total
            FROM user_question_records uqr
            JOIN questions q ON q.id=uqr.question_id
            JOIN question_banks qb ON qb.id=q.question_bank_id
            WHERE {where_sql}
            """,
            tuple(params),
        )
        total = int(cursor.fetchone()["total"])
        cursor.execute(
            f"""
            SELECT
              q.id, q.type, q.stem, q.analysis, q.difficulty, q.knowledge_point,
              qb.name AS bank_name, uqr.note, uqr.updated_at
            FROM user_question_records uqr
            JOIN questions q ON q.id=uqr.question_id
            JOIN question_banks qb ON qb.id=q.question_bank_id
            WHERE {where_sql}
            ORDER BY uqr.updated_at DESC, uqr.id DESC
            LIMIT %s OFFSET %s
            """,
            tuple(params + [page_size, (page - 1) * page_size]),
        )
        rows = cursor.fetchall()

    questions = [
        {
            "id": row["id"],
            "type": row.get("type") or "",
            "stem": row.get("stem") or "",
            "analysis": row.get("analysis") or "",
            "difficulty": int(row.get("difficulty") or 1),
            "knowledgePoint": row.get("knowledge_point") or "",
            "bankName": row.get("bank_name") or "",
            "note": row.get("note") or "",
            "updatedAt": str(row.get("updated_at") or ""),
        }
        for row in rows
    ]
    return success({
        "questions": questions,
        "total": total,
        "page": page,
        "pageSize": page_size,
    })
