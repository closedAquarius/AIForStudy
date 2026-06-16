import json
from typing import Any

from db import db_cursor
from services.knowledge_graph_service import KnowledgeGraphService


class QuestionPersistenceService:
    """Persist generated question JSON into the question-bank schema."""

    def save_generated_questions(
        self,
        generated: dict[str, Any],
        owner_user_id: int | None = None,
        question_bank_id: int | None = None,
        status: str = "draft",
    ) -> dict[str, Any]:
        question_bank = generated.get("question_bank") or {}
        questions = generated.get("questions") or []

        if not isinstance(questions, list) or len(questions) == 0:
            raise ValueError("没有可保存的题目")

        with db_cursor(commit=True) as cursor:
            subject_id = self._ensure_subject(cursor, str(question_bank.get("subject") or "未指定学科"))
            owner_id = self._resolve_owner_id(cursor, owner_user_id)

            if question_bank_id is None:
                question_bank_id = self._create_question_bank(
                    cursor=cursor,
                    owner_user_id=owner_id,
                    subject_id=subject_id,
                    name=str(question_bank.get("name") or "AI 生成题库"),
                    description=str(question_bank.get("description") or ""),
                )
            else:
                self._ensure_question_bank_exists(cursor, question_bank_id)

            saved_question_ids: list[int] = []
            for question in questions:
                saved_question_ids.append(
                    self._save_question(
                        cursor=cursor,
                        question_bank_id=question_bank_id,
                        subject_id=subject_id,
                        question=question,
                        status=status,
                    )
                )
            KnowledgeGraphService().sync_bank_by_id(cursor, question_bank_id)

        return {
            "question_bank_id": question_bank_id,
            "subject_id": subject_id,
            "saved_count": len(saved_question_ids),
            "question_ids": saved_question_ids,
            "status": status,
        }

    def _resolve_owner_id(self, cursor, owner_user_id: int | None) -> int | None:
        if owner_user_id is None:
            cursor.execute("SELECT id FROM users ORDER BY id LIMIT 1")
            row = cursor.fetchone()
            return row["id"] if row else None

        cursor.execute("SELECT id FROM users WHERE id=%s LIMIT 1", (owner_user_id,))
        row = cursor.fetchone()
        if not row:
            raise ValueError(f"用户不存在: {owner_user_id}")
        return owner_user_id

    def _ensure_subject(self, cursor, subject_name: str) -> int:
        name = subject_name.strip() or "未指定学科"
        cursor.execute("SELECT id FROM subjects WHERE name=%s LIMIT 1", (name,))
        row = cursor.fetchone()
        if row:
            return row["id"]

        cursor.execute(
            "INSERT INTO subjects (name, description) VALUES (%s, %s)",
            (name, "AI 文档出题自动创建"),
        )
        return cursor.lastrowid

    def _create_question_bank(self, cursor, owner_user_id: int | None, subject_id: int, name: str, description: str) -> int:
        cursor.execute(
            """
            INSERT INTO question_banks
              (owner_user_id, subject_id, name, description, visibility, source_type)
            VALUES
              (%s, %s, %s, %s, 'private', 'document_ai')
            """,
            (owner_user_id, subject_id, name.strip() or "AI 生成题库", description),
        )
        return cursor.lastrowid

    def _ensure_question_bank_exists(self, cursor, question_bank_id: int) -> None:
        cursor.execute("SELECT id FROM question_banks WHERE id=%s LIMIT 1", (question_bank_id,))
        if not cursor.fetchone():
            raise ValueError(f"题库不存在: {question_bank_id}")

    def _save_question(self, cursor, question_bank_id: int, subject_id: int, question: dict[str, Any], status: str) -> int:
        normalized_status = status if status in {"draft", "active"} else "draft"
        extra = question.get("extra") or {}
        cursor.execute(
            """
            INSERT INTO questions
              (question_bank_id, subject_id, type, stem, analysis, difficulty, score,
               knowledge_point, ai_generated, status, extra)
            VALUES
              (%s, %s, %s, %s, %s, %s, %s, %s, 1, %s, %s)
            """,
            (
                question_bank_id,
                subject_id,
                question["type"],
                question["stem"],
                question.get("analysis") or "",
                int(question.get("difficulty") or 3),
                float(question.get("score") or 1),
                question.get("knowledge_point") or "",
                normalized_status,
                json.dumps(extra, ensure_ascii=False),
            ),
        )
        question_id = cursor.lastrowid

        for option in question.get("options") or []:
            self._save_option(cursor, question_id, option)

        for answer in question.get("answers") or []:
            self._save_answer(cursor, question_id, answer)

        for tag_name in question.get("tags") or []:
            tag_id = self._ensure_tag(cursor, str(tag_name))
            cursor.execute(
                """
                INSERT IGNORE INTO question_tags (question_id, tag_id)
                VALUES (%s, %s)
                """,
                (question_id, tag_id),
            )

        return question_id

    def _save_option(self, cursor, question_id: int, option: dict[str, Any]) -> None:
        cursor.execute(
            """
            INSERT INTO question_options
              (question_id, option_key, content, is_correct, sort_order)
            VALUES
              (%s, %s, %s, %s, %s)
            """,
            (
                question_id,
                option.get("option_key") or "",
                option.get("content") or "",
                1 if option.get("is_correct") else 0,
                int(option.get("sort_order") or 0),
            ),
        )

    def _save_answer(self, cursor, question_id: int, answer: dict[str, Any]) -> None:
        answer_json = answer.get("answer_json")
        cursor.execute(
            """
            INSERT INTO question_answers
              (question_id, answer_text, answer_json, is_primary)
            VALUES
              (%s, %s, %s, %s)
            """,
            (
                question_id,
                answer.get("answer_text") or "",
                json.dumps(answer_json, ensure_ascii=False) if answer_json is not None else None,
                1 if answer.get("is_primary", True) else 0,
            ),
        )

    def _ensure_tag(self, cursor, tag_name: str) -> int:
        name = tag_name.strip()
        if not name:
            name = "AI生成"

        cursor.execute(
            "SELECT id FROM tags WHERE name=%s AND category='knowledge' LIMIT 1",
            (name,),
        )
        row = cursor.fetchone()
        if row:
            return row["id"]

        cursor.execute(
            "INSERT INTO tags (name, category, color) VALUES (%s, 'knowledge', '#38C98A')",
            (name,),
        )
        return cursor.lastrowid
