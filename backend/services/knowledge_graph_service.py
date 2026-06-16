from typing import Any


class KnowledgeGraphService:
    """Build and refresh graph nodes from active questions in a question bank."""

    def sync_bank_by_id(self, cursor, bank_id: int) -> dict[str, Any] | None:
        cursor.execute(
            """
            SELECT id,owner_user_id,name
            FROM question_banks
            WHERE id=%s
            LIMIT 1
            """,
            (bank_id,),
        )
        bank = cursor.fetchone()
        if not bank:
            return None
        return self.sync_bank(cursor, bank)

    def sync_banks_by_ids(self, cursor, bank_ids: list[int]) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for bank_id in sorted({int(item) for item in bank_ids if int(item) > 0}):
            result = self.sync_bank_by_id(cursor, bank_id)
            if result:
                results.append(result)
        return results

    def sync_bank(self, cursor, bank: dict[str, Any]) -> dict[str, Any] | None:
        owner_user_id = bank.get("owner_user_id")
        if owner_user_id is None:
            return None

        owner_id = int(owner_user_id)
        bank_id = int(bank["id"])
        course_id = self._ensure_course_node(cursor, owner_id, bank_id, str(bank.get("name") or "未命名题库"))
        points = self._active_knowledge_points(cursor, bank_id)

        cursor.execute("DELETE FROM knowledge_relations WHERE question_bank_id=%s", (bank_id,))
        self._delete_stale_knowledge_nodes(cursor, bank_id, [item["knowledge_point"] for item in points])

        node_ids: list[int] = []
        for point in points:
            cursor.execute(
                """
                INSERT INTO knowledge_nodes(owner_user_id,question_bank_id,node_type,name,description)
                VALUES(%s,%s,'knowledge',%s,%s)
                ON DUPLICATE KEY UPDATE
                  description=VALUES(description),
                  updated_at=NOW()
                """,
                (
                    owner_id,
                    bank_id,
                    point["knowledge_point"],
                    f"关联 {int(point['question_count'])} 道题",
                ),
            )
            cursor.execute(
                """
                SELECT id
                FROM knowledge_nodes
                WHERE question_bank_id=%s AND node_type='knowledge' AND name=%s
                LIMIT 1
                """,
                (bank_id, point["knowledge_point"]),
            )
            row = cursor.fetchone()
            if not row:
                continue
            node_id = int(row["id"])
            node_ids.append(node_id)
            cursor.execute(
                """
                INSERT IGNORE INTO knowledge_relations
                  (question_bank_id,source_node_id,target_node_id,relation_type,weight)
                VALUES(%s,%s,%s,'contains',1)
                """,
                (bank_id, course_id, node_id),
            )

        for index in range(len(node_ids) - 1):
            cursor.execute(
                """
                INSERT IGNORE INTO knowledge_relations
                  (question_bank_id,source_node_id,target_node_id,relation_type,weight)
                VALUES(%s,%s,%s,'related',0.5)
                """,
                (bank_id, node_ids[index], node_ids[index + 1]),
            )

        return {
            "question_bank_id": bank_id,
            "knowledge_count": len(points),
            "relation_count": max(0, len(node_ids) * 2 - 1) if node_ids else 0,
        }

    def _ensure_course_node(self, cursor, owner_id: int, bank_id: int, bank_name: str) -> int:
        cursor.execute(
            """
            SELECT id
            FROM knowledge_nodes
            WHERE question_bank_id=%s AND node_type='course'
            ORDER BY id
            LIMIT 1
            """,
            (bank_id,),
        )
        row = cursor.fetchone()
        if row:
            course_id = int(row["id"])
            cursor.execute(
                """
                DELETE FROM knowledge_nodes
                WHERE question_bank_id=%s AND node_type='course' AND id<>%s
                """,
                (bank_id, course_id),
            )
            cursor.execute(
                """
                UPDATE knowledge_nodes
                SET owner_user_id=%s,name=%s,description='题库课程节点',updated_at=NOW()
                WHERE id=%s
                """,
                (owner_id, bank_name, course_id),
            )
            return course_id

        cursor.execute(
            """
            INSERT INTO knowledge_nodes(owner_user_id,question_bank_id,node_type,name,description)
            VALUES(%s,%s,'course',%s,'题库课程节点')
            """,
            (owner_id, bank_id, bank_name),
        )
        return int(cursor.lastrowid)

    def _active_knowledge_points(self, cursor, bank_id: int) -> list[dict[str, Any]]:
        cursor.execute(
            """
            SELECT knowledge_point,MIN(id) first_question_id,COUNT(*) question_count
            FROM questions
            WHERE question_bank_id=%s AND status='active'
              AND knowledge_point IS NOT NULL AND knowledge_point<>''
            GROUP BY knowledge_point
            ORDER BY first_question_id
            """,
            (bank_id,),
        )
        return cursor.fetchall()

    def _delete_stale_knowledge_nodes(self, cursor, bank_id: int, active_names: list[str]) -> None:
        active_names = [name for name in active_names if name]
        if not active_names:
            cursor.execute(
                "DELETE FROM knowledge_nodes WHERE question_bank_id=%s AND node_type='knowledge'",
                (bank_id,),
            )
            return

        placeholders = ",".join(["%s"] * len(active_names))
        cursor.execute(
            f"""
            DELETE FROM knowledge_nodes
            WHERE question_bank_id=%s
              AND node_type='knowledge'
              AND name NOT IN ({placeholders})
            """,
            [bank_id, *active_names],
        )
