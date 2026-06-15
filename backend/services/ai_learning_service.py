import base64
import json
import os
import uuid
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from db import db_cursor
from services.diary_service import DiaryService
from services.document_text_extractor import DocumentTextExtractor

BACKEND_DIR = Path(__file__).resolve().parents[1]
LOAD_DIR = BACKEND_DIR / "uploads"

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)


class AiProviderBusyError(RuntimeError):
    """Raised when the upstream model is temporarily overloaded or rate limited."""


class AiLearningService:
    """AI tutoring, wrong-question explanation and diary planning helper."""

    def __init__(self):
        self.api_key = os.getenv("ZHIPU_API_KEY", "")
        self.model = os.getenv("ZHIPU_MODEL", "glm-4.7-flash")
        self.upload_dir = LOAD_DIR
        self.upload_dir.mkdir(exist_ok=True)

    def chat(
        self,
        user_id: int,
        message: str,
        scene: str = "qa",
        conversation_id: int | None = None,
        related_question_id: int | None = None,
        attachment_path: str | None = None,
        attachment_name: str | None = None,
        attachment_type: str | None = None,
    ) -> dict[str, Any]:
        if not message.strip():
            raise ValueError("消息内容不能为空")

        conversation = self._resolve_conversation(user_id, conversation_id, scene, message)
        attachment_context = self._save_attachment_if_needed(user_id, attachment_path, attachment_name, attachment_type)
        question_context = self._load_question_context(user_id, related_question_id)
        diary_context = self._load_diary_context(user_id) if scene == "diary_analysis" else ""

        memory_messages = self._load_memory_messages(conversation["id"])
        prompt_messages = self._build_messages(
            scene=scene,
            user_message=message,
            attachment_context=attachment_context,
            question_context=question_context,
            diary_context=diary_context,
            memory_messages=memory_messages,
        )
        assistant_text = self._call_zhipu(prompt_messages)
        self._store_message(conversation["id"], "user", self._compose_user_message(message, attachment_context), related_question_id)
        self._store_message(conversation["id"], "assistant", assistant_text, related_question_id)

        return {
            "conversation_id": conversation["id"],
            "conversation_title": conversation["title"],
            "scene": conversation["scene"],
            "assistant_message": assistant_text,
            "attachment": attachment_context,
            "question_context": question_context,
            "diary_context": diary_context,
        }

    def list_conversations(self, user_id: int, limit: int = 20) -> list[dict[str, Any]]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT c.id, c.title, c.scene, c.updated_at,
                       (
                         SELECT content
                         FROM ai_messages m
                         WHERE m.conversation_id = c.id
                         ORDER BY m.created_at DESC, m.id DESC
                         LIMIT 1
                       ) AS last_message
                FROM ai_conversations c
                WHERE c.user_id = %s
                ORDER BY c.updated_at DESC, c.id DESC
                LIMIT %s
                """,
                (user_id, limit),
            )
            rows = cursor.fetchall()

        return [
            {
                "id": row["id"],
                "title": row.get("title") or "AI辅学对话",
                "scene": row.get("scene") or "qa",
                "updatedAt": str(row.get("updated_at") or ""),
                "lastMessage": row.get("last_message") or "",
            }
            for row in rows
        ]

    def list_wrong_questions(self, user_id: int, bank_id: int | None = None, limit: int = 30) -> list[dict[str, Any]]:
        with db_cursor() as cursor:
            params: list[Any] = [user_id]
            bank_filter = ""
            if bank_id:
                bank_filter = " AND q.question_bank_id = %s "
                params.append(bank_id)

            cursor.execute(
                f"""
                SELECT
                  q.id,
                  q.question_bank_id,
                  q.type,
                  q.stem,
                  q.analysis,
                  q.difficulty,
                  q.score,
                  q.knowledge_point,
                  qb.name AS bank_name,
                  GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ',') AS tag_names,
                  last_pa.is_correct AS latest_is_correct,
                  last_pa.answered_at AS latest_answered_at
                FROM questions q
                JOIN question_banks qb ON qb.id = q.question_bank_id
                JOIN practice_answers last_pa ON last_pa.id = (
                  SELECT pa2.id
                  FROM practice_answers pa2
                  WHERE pa2.user_id = %s
                    AND pa2.question_id = q.id
                  ORDER BY pa2.answered_at DESC, pa2.id DESC
                  LIMIT 1
                )
                LEFT JOIN question_tags qt ON qt.question_id = q.id
                LEFT JOIN tags t ON t.id = qt.tag_id
                WHERE q.status = 'active'
                  AND last_pa.is_correct = 0
                  {bank_filter}
                GROUP BY q.id, q.question_bank_id, q.type, q.stem, q.analysis, q.difficulty,
                         q.score, q.knowledge_point, qb.name, last_pa.is_correct, last_pa.answered_at
                ORDER BY last_pa.answered_at DESC, q.id DESC
                LIMIT %s
                """,
                params + [limit],
            )
            rows = cursor.fetchall()

        result = []
        for row in rows:
            tags = row.get("tag_names") or ""
            result.append({
                "id": row["id"],
                "bankId": row["question_bank_id"],
                "bankName": row.get("bank_name") or "",
                "type": row.get("type") or "",
                "stem": row.get("stem") or "",
                "analysis": row.get("analysis") or "",
                "difficulty": int(row.get("difficulty") or 1),
                "score": float(row.get("score") or 0),
                "knowledgePoint": row.get("knowledge_point") or "",
                "tags": [item for item in tags.split(",") if item],
                "latestIsCorrect": int(row.get("latest_is_correct") or 0),
                "latestAnsweredAt": str(row.get("latest_answered_at") or ""),
            })
        return result

    def explain_wrong_question(self, user_id: int, question_id: int) -> dict[str, Any]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  q.id,
                  q.question_bank_id,
                  q.type,
                  q.stem,
                  q.analysis,
                  q.difficulty,
                  q.score,
                  q.knowledge_point,
                  qb.name AS bank_name,
                  GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ',') AS tag_names,
                  last_pa.is_correct AS latest_is_correct,
                  last_pa.user_answer AS latest_answer_text
                FROM questions q
                JOIN question_banks qb ON qb.id = q.question_bank_id
                LEFT JOIN question_tags qt ON qt.question_id = q.id
                LEFT JOIN tags t ON t.id = qt.tag_id
                LEFT JOIN practice_answers last_pa ON last_pa.id = (
                  SELECT pa2.id
                  FROM practice_answers pa2
                  WHERE pa2.user_id = %s
                    AND pa2.question_id = q.id
                  ORDER BY pa2.answered_at DESC, pa2.id DESC
                  LIMIT 1
                )
                WHERE q.id = %s
                GROUP BY q.id, q.question_bank_id, q.type, q.stem, q.analysis, q.difficulty,
                         q.score, q.knowledge_point, qb.name, last_pa.is_correct, last_pa.user_answer
                LIMIT 1
                """,
                (user_id, question_id),
            )
            row = cursor.fetchone()

        if not row:
            raise ValueError("题目不存在或无权访问")

        tags = row.get("tag_names") or ""
        question = {
            "id": row["id"],
            "bankId": row["question_bank_id"],
            "bankName": row.get("bank_name") or "",
            "type": row.get("type") or "",
            "stem": row.get("stem") or "",
            "analysis": row.get("analysis") or "",
            "difficulty": int(row.get("difficulty") or 1),
            "score": float(row.get("score") or 0),
            "knowledgePoint": row.get("knowledge_point") or "",
            "tags": [item for item in tags.split(",") if item],
            "latestIsCorrect": int(row.get("latest_is_correct") or 0),
            "latestAnswerText": row.get("latest_answer_text") or "",
        }
        prompt = self._build_question_explain_prompt(question)
        answer = self._call_zhipu([{"role": "system", "content": prompt["system"]}, {"role": "user", "content": prompt["user"]}])
        return {"question": question, "explanation": answer}

    def list_messages(self, user_id: int, conversation_id: int, limit: int = 40) -> list[dict[str, Any]]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT m.id, m.role, m.content, m.related_question_id, m.created_at
                FROM ai_messages m
                JOIN ai_conversations c ON c.id = m.conversation_id
                WHERE m.conversation_id = %s AND c.user_id = %s
                ORDER BY m.created_at ASC, m.id ASC
                LIMIT %s
                """,
                (conversation_id, user_id, limit),
            )
            rows = cursor.fetchall()

        return [
            {
                "id": row["id"],
                "role": row.get("role") or "user",
                "content": row.get("content") or "",
                "relatedQuestionId": row.get("related_question_id"),
                "createdAt": str(row.get("created_at") or ""),
            }
            for row in rows
        ]

    def build_study_plan(self, user_id: int, days: int = 3) -> dict[str, Any]:
        diary_entries = DiaryService().list_entries(user_id)
        recent_entries = diary_entries[:7]
        if not recent_entries:
            raise ValueError("暂无学习日记，无法生成学习建议")

        user_prompt = self._build_diary_plan_prompt(recent_entries, days)
        answer = self._call_zhipu([
            {"role": "system", "content": "你是一名务实的学习教练，需要根据学习日记输出清晰可执行的未来几天学习方向。"},
            {"role": "user", "content": user_prompt},
        ])
        return {
            "days": days,
            "recent_diaries": recent_entries,
            "plan": answer,
        }

    def _resolve_conversation(self, user_id: int, conversation_id: int | None, scene: str, message: str) -> dict[str, Any]:
        if conversation_id:
            with db_cursor() as cursor:
                cursor.execute(
                    "SELECT id, user_id, title, scene FROM ai_conversations WHERE id=%s AND user_id=%s LIMIT 1",
                    (conversation_id, user_id),
                )
                row = cursor.fetchone()
            if row:
                return row

        title = self._build_conversation_title(scene, message)
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO ai_conversations (user_id, title, scene)
                VALUES (%s, %s, %s)
                """,
                (user_id, title, scene),
            )
            new_id = cursor.lastrowid
        return {"id": new_id, "title": title, "scene": scene}

    def _build_conversation_title(self, scene: str, message: str) -> str:
        prefix_map = {
            "qa": "AI辅学",
            "explain_question": "错题讲解",
            "diary_analysis": "日记分析",
            "study_plan": "学习计划",
        }
        prefix = prefix_map.get(scene, "AI辅学")
        text = (message or "").strip()
        if not text:
            return prefix
        short_text = text.replace("\n", " ").strip()
        if len(short_text) > 18:
            short_text = short_text[:18] + "..."
        return f"{prefix} - {short_text}"

    def _load_memory_messages(self, conversation_id: int, limit: int = 12) -> list[dict[str, str]]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT role, content
                FROM ai_messages
                WHERE conversation_id = %s
                ORDER BY created_at DESC, id DESC
                LIMIT %s
                """,
                (conversation_id, limit),
            )
            rows = list(reversed(cursor.fetchall()))
        return [{"role": row["role"], "content": row["content"]} for row in rows]

    def _store_message(
        self,
        conversation_id: int,
        role: str,
        content: str,
        related_question_id: int | None = None,
    ) -> None:
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO ai_messages (conversation_id, role, content, related_question_id)
                VALUES (%s, %s, %s, %s)
                """,
                (conversation_id, role, content, related_question_id),
            )
            cursor.execute(
                "UPDATE ai_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = %s",
                (conversation_id,),
            )

    def _save_attachment_if_needed(
        self,
        user_id: int,
        attachment_path: str | None,
        attachment_name: str | None,
        attachment_type: str | None,
    ) -> dict[str, Any]:
        if not attachment_path or not attachment_name:
            return {}

        path = Path(attachment_path)
        if not path.exists():
            raise ValueError("附件文件不存在")

        suffix = path.suffix.lower().lstrip(".")
        file_type = suffix if suffix in {"ppt", "pptx", "doc", "docx", "pdf", "txt"} else "other"
        storage_name = f"{uuid.uuid4().hex}-{secure_name(attachment_name)}"
        saved_path = self.upload_dir / storage_name
        saved_path.write_bytes(path.read_bytes())

        extracted_text = ""
        ai_summary = ""
        parse_status = "uploaded"
        if file_type in {"pptx", "docx", "pdf", "txt", "ppt", "doc"}:
            try:
                extracted_text = DocumentTextExtractor().extract(saved_path, attachment_name)
                parse_status = "parsed" if extracted_text.strip() else "failed"
                ai_summary = extracted_text[:300]
            except Exception as exc:
                parse_status = "failed"
                ai_summary = f"解析失败：{exc}"
        else:
            ai_summary = f"附件文件：{attachment_name}"

        metadata = {
            "attachment_type": attachment_type or file_type,
            "parse_status": parse_status,
            "original_name": attachment_name,
        }
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO documents
                  (owner_user_id, subject_id, title, file_name, file_type, storage_path, parse_status, extracted_text, ai_summary, metadata)
                VALUES
                  (%s, NULL, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    attachment_name,
                    attachment_name,
                    file_type if file_type in {"ppt", "pptx", "doc", "docx", "pdf", "txt"} else "other",
                    str(saved_path),
                    parse_status,
                    extracted_text or None,
                    ai_summary or None,
                    json.dumps(metadata, ensure_ascii=False),
                ),
            )
            doc_id = cursor.lastrowid

        return {
            "document_id": doc_id,
            "file_name": attachment_name,
            "file_type": file_type,
            "parse_status": parse_status,
            "text_length": len(extracted_text),
            "summary": ai_summary,
        }

    def _load_question_context(self, user_id: int, related_question_id: int | None) -> str:
        if not related_question_id:
            return ""

        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  q.id,
                  q.type,
                  q.stem,
                  q.analysis,
                  q.difficulty,
                  q.score,
                  q.knowledge_point,
                  GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ',') AS tag_names,
                  last_pa.user_answer AS latest_answer_text,
                  last_pa.is_correct AS latest_is_correct
                FROM questions q
                LEFT JOIN question_tags qt ON qt.question_id = q.id
                LEFT JOIN tags t ON t.id = qt.tag_id
                LEFT JOIN practice_answers last_pa ON last_pa.id = (
                  SELECT pa2.id
                  FROM practice_answers pa2
                  WHERE pa2.user_id = %s
                    AND pa2.question_id = q.id
                  ORDER BY pa2.answered_at DESC, pa2.id DESC
                  LIMIT 1
                )
                WHERE q.id = %s
                GROUP BY q.id, q.type, q.stem, q.analysis, q.difficulty, q.score, q.knowledge_point,
                         last_pa.user_answer, last_pa.is_correct
                LIMIT 1
                """,
                (user_id, related_question_id),
            )
            row = cursor.fetchone()

        if not row:
            return ""

        tags = row.get("tag_names") or ""
        return (
            f"题目信息：\n"
            f"- 类型：{row.get('type') or ''}\n"
            f"- 题干：{row.get('stem') or ''}\n"
            f"- 解析：{row.get('analysis') or ''}\n"
            f"- 难度：{int(row.get('difficulty') or 1)}\n"
            f"- 分值：{float(row.get('score') or 0)}\n"
            f"- 知识点：{row.get('knowledge_point') or ''}\n"
            f"- 标签：{tags}\n"
            f"- 最近作答：{row.get('latest_answer_text') or ''}\n"
            f"- 最近结果：{'正确' if int(row.get('latest_is_correct') or 0) == 1 else '错误或未记录'}"
        )

    def _load_diary_context(self, user_id: int) -> str:
        entries = DiaryService().list_entries(user_id)[:7]
        if not entries:
            return ""
        lines = []
        for entry in entries:
            lines.append(
                f"{entry.get('entryDate', '')} | 心情 {entry.get('moodScore', 0)} | {entry.get('title', '')} | {entry.get('content', '')[:180]}"
            )
        return "最近学习日记：\n" + "\n".join(lines)

    def _compose_user_message(self, message: str, attachment_context: dict[str, Any]) -> str:
        if not attachment_context:
            return message
        return f"{message}\n\n附件信息：{json.dumps(attachment_context, ensure_ascii=False)}"

    def _build_messages(
        self,
        scene: str,
        user_message: str,
        attachment_context: dict[str, Any],
        question_context: str,
        diary_context: str,
        memory_messages: list[dict[str, str]],
    ) -> list[dict[str, str]]:
        system_prompt = self._scene_prompt(scene)
        if attachment_context:
            system_prompt += f"\n附件信息：{json.dumps(attachment_context, ensure_ascii=False)}"
        if question_context:
            system_prompt += f"\n{question_context}"
        if diary_context:
            system_prompt += f"\n{diary_context}"

        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(memory_messages)
        messages.append({"role": "user", "content": user_message})
        return messages

    def _scene_prompt(self, scene: str) -> str:
        if scene == "explain_question":
            return (
                "你是一名辅学老师。请基于题目内容、作答情况和用户提问，给出清晰、分步骤、可执行的错题讲解。"
                "先讲思路，再讲知识点，最后给出相似题练习建议。"
            )
        if scene == "diary_analysis":
            return (
                "你是一名学习教练。请基于学习日记分析学习状态、情绪波动和最近的学习重心，"
                "并给出未来 3 到 7 天的具体学习方向、每日行动建议和需要避免的问题。"
            )
        return (
            "你是一名耐心的辅学助手。回答要简洁、准确、分步骤。"
            "如果用户提供了附件，请优先利用附件内容。"
            "如果信息不足，请说明还缺什么，而不是胡编。"
        )

    def _build_question_explain_prompt(self, question: dict[str, Any]) -> dict[str, str]:
        system = (
            "你是一名错题讲解老师。请针对题目进行解析，先给出正确答案判断，再解释原因，"
            "最后给出 1 条同类题的复习建议。回答要适合学生阅读。"
        )
        user = (
            f"题目类型：{question.get('type')}\n"
            f"题干：{question.get('stem')}\n"
            f"参考解析：{question.get('analysis')}\n"
            f"知识点：{question.get('knowledgePoint')}\n"
            f"标签：{', '.join(question.get('tags') or [])}\n"
            f"最近作答：{question.get('latestAnswerText')}\n"
            f"最近结果：{'正确' if question.get('latestIsCorrect') == 1 else '错误或未作答'}"
        )
        return {"system": system, "user": user}

    def _build_diary_plan_prompt(self, diary_entries: list[dict[str, Any]], days: int) -> str:
        lines = []
        for entry in diary_entries:
            lines.append(
                f"{entry.get('entryDate', '')} | 心情 {entry.get('moodScore', 0)} | {entry.get('title', '')} | {entry.get('content', '')[:200]}"
            )
        return (
            f"请根据以下学习日记，为未来 {days} 天输出学习方向建议。\n"
            "要求：\n"
            "1. 先总结当前状态。\n"
            "2. 再给出每天的学习重点。\n"
            "3. 最后给出一个情绪和效率建议。\n"
            "4. 输出尽量具体，不要空话。\n\n"
            + "\n".join(lines)
        )

    def _call_zhipu(self, messages: list[dict[str, str]]) -> str:
        if not self.api_key:
            raise ValueError("ZHIPU_API_KEY is not configured")

        try:
            from zai import ZhipuAiClient
        except ImportError as exc:
            raise RuntimeError("Please install Zhipu SDK first: pip install zai") from exc

        client = ZhipuAiClient(api_key=self.api_key)
        try:
            response = client.chat.completions.create(
                model=self.model,
                messages=messages,
                thinking={"type": "enabled"},
                max_tokens=8192,
                temperature=0.6,
            )
        except Exception as exc:
            error_text = str(exc)
            error_name = exc.__class__.__name__
            if "APIReachLimitError" in error_name or "429" in error_text or "1305" in error_text:
                raise AiProviderBusyError("AI 模型当前访问量过大，请稍后再试。") from exc
            raise
        message = response.choices[0].message
        content = getattr(message, "content", None)
        if content is None and isinstance(message, dict):
            content = message.get("content")
        if not isinstance(content, str):
            content = str(message)
        return content.strip()

    def generate_answer(self, messages: list[dict[str, str]]) -> str:
        return self._call_zhipu(messages)


def secure_name(name: str) -> str:
    text = "".join(ch for ch in name if ch.isalnum() or ch in ("-", "_", ".", " "))
    return text.strip().replace(" ", "_") or "attachment"
