from flask import Blueprint, request

from api_utils import fail, require_current_user, success
from db import db_cursor
from services.knowledge_graph_service import KnowledgeGraphService

knowledge_graph_bp = Blueprint("knowledge_graph_api", __name__)


def _accessible_bank(cursor, bank_id: int, user_id: int):
    cursor.execute(
        """
        SELECT id,owner_user_id,name
        FROM question_banks
        WHERE id=%s AND (owner_user_id=%s OR visibility IN ('public','class'))
        LIMIT 1
        """,
        (bank_id, user_id),
    )
    return cursor.fetchone()


def _node_level(answer_count: int, accuracy: float) -> str:
    if answer_count == 0:
        return "unlearned"
    if accuracy >= 80:
        return "mastered"
    if accuracy >= 60:
        return "learning"
    return "weak"


@knowledge_graph_bp.get("/knowledge-graph")
def get_knowledge_graph():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    try:
        bank_id = int(request.args.get("bankId") or 0)
    except ValueError:
        return fail("题库参数错误")

    with db_cursor(commit=True) as cursor:
        if bank_id > 0:
            bank = _accessible_bank(cursor, bank_id, user["id"])
            if not bank:
                return fail("题库不存在或无权访问", 404)
            banks = [bank]
        else:
            cursor.execute(
                """
                SELECT id,owner_user_id,name
                FROM question_banks
                WHERE owner_user_id=%s OR visibility IN ('public','class')
                ORDER BY updated_at DESC
                LIMIT 20
                """,
                (user["id"],),
            )
            banks = cursor.fetchall()

        graph_service = KnowledgeGraphService()
        for bank in banks:
            graph_service.sync_bank(cursor, bank)

        bank_ids = [int(bank["id"]) for bank in banks]
        if not bank_ids:
            return success({
                "banks": [],
                "nodes": [],
                "relations": [],
                "summary": {
                    "totalCount": 0,
                    "masteredCount": 0,
                    "learningCount": 0,
                    "weakCount": 0,
                    "unlearnedCount": 0,
                },
            })

        placeholders = ",".join(["%s"] * len(bank_ids))
        cursor.execute(
            f"""
            SELECT
              kn.id,kn.question_bank_id,kn.node_type,kn.name,kn.description,
              qb.name bank_name,
              COUNT(DISTINCT q.id) question_count,
              COUNT(pa.id) answer_count,
              COALESCE(SUM(CASE WHEN pa.is_correct=1 THEN 1 ELSE 0 END),0) correct_count
            FROM knowledge_nodes kn
            JOIN question_banks qb ON qb.id=kn.question_bank_id
            LEFT JOIN questions q ON q.question_bank_id=kn.question_bank_id
              AND q.status='active'
              AND kn.node_type='knowledge' AND q.knowledge_point=kn.name
            LEFT JOIN practice_answers pa ON pa.question_id=q.id AND pa.user_id=%s
            WHERE kn.question_bank_id IN ({placeholders})
            GROUP BY kn.id,kn.question_bank_id,kn.node_type,kn.name,kn.description,qb.name
            ORDER BY kn.question_bank_id,kn.node_type,kn.id
            """,
            [user["id"], *bank_ids],
        )
        node_rows = cursor.fetchall()

        cursor.execute(
            f"""
            SELECT id,question_bank_id,source_node_id,target_node_id,relation_type,weight
            FROM knowledge_relations
            WHERE question_bank_id IN ({placeholders})
            ORDER BY id
            """,
            bank_ids,
        )
        relation_rows = cursor.fetchall()

    nodes = []
    summary = {
        "totalCount": 0,
        "masteredCount": 0,
        "learningCount": 0,
        "weakCount": 0,
        "unlearnedCount": 0,
    }
    for row in node_rows:
        answer_count = int(row.get("answer_count") or 0)
        correct_count = int(row.get("correct_count") or 0)
        accuracy = round(correct_count * 100 / answer_count, 1) if answer_count else 0
        level = "course" if row["node_type"] == "course" else _node_level(answer_count, accuracy)
        if row["node_type"] == "knowledge":
            summary["totalCount"] += 1
            summary[f"{level}Count"] += 1
        nodes.append({
            "id": int(row["id"]),
            "bankId": int(row["question_bank_id"]),
            "bankName": row["bank_name"],
            "type": row["node_type"],
            "name": row["name"],
            "description": row.get("description") or "",
            "questionCount": int(row.get("question_count") or 0),
            "answerCount": answer_count,
            "correctCount": correct_count,
            "accuracyRate": accuracy,
            "level": level,
        })

    return success({
        "banks": [{"id": int(bank["id"]), "name": bank["name"]} for bank in banks],
        "nodes": nodes,
        "relations": [{
            "id": int(row["id"]),
            "bankId": int(row["question_bank_id"]),
            "sourceId": int(row["source_node_id"]),
            "targetId": int(row["target_node_id"]),
            "type": row["relation_type"],
            "weight": float(row.get("weight") or 1),
        } for row in relation_rows],
        "summary": summary,
    })


@knowledge_graph_bp.post("/knowledge-graph/sync")
def sync_knowledge_graph():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    bank_id = int(body.get("bankId") or 0)
    with db_cursor(commit=True) as cursor:
        graph_service = KnowledgeGraphService()
        if bank_id > 0:
            bank = _accessible_bank(cursor, bank_id, user["id"])
            if not bank:
                return fail("题库不存在或无权访问", 404)
            results = [graph_service.sync_bank(cursor, bank)]
        else:
            cursor.execute(
                """
                SELECT id,owner_user_id,name
                FROM question_banks
                WHERE owner_user_id=%s OR visibility IN ('public','class')
                ORDER BY updated_at DESC
                LIMIT 20
                """,
                (user["id"],),
            )
            results = [graph_service.sync_bank(cursor, bank) for bank in cursor.fetchall()]

    return success({"results": [item for item in results if item]}, "知识图谱已同步")
