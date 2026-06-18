import json
import os

from pathlib import Path

from db import db_cursor
from dotenv import load_dotenv
from services.zhipu_client import ZhipuChatClient

BACKEND_DIR = Path(__file__).resolve().parents[1]

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)


class DiaryService:
    """Read and serialize study diary entries."""

    def polish_content(self, content: str) -> str:
        if not content or not content.strip():
            raise ValueError("日记内容不能为空")

        api_key = os.getenv("ZHIPU_API_KEY", "")
        if not api_key:
            raise ValueError("ZHIPU_API_KEY 未配置，无法使用AI润色")

        model = os.getenv("ZHIPU_MODEL", "glm-4-flash")

        # Configure max tokens for polishing. Keep a sensible default to avoid
        # very long generation times when input is large. Can be overridden
        # by environment `DIARY_POLISH_MAX_TOKENS`.
        try:
            default_max_tokens = int(os.getenv("DIARY_POLISH_MAX_TOKENS", "2048"))
        except (TypeError, ValueError):
            default_max_tokens = 512

        # If the input content is very long, prefer a smaller generation size
        # to reduce latency and avoid client-side timeouts.
        content_len = len(content or "")
        if content_len > 3000:
            max_tokens = min(default_max_tokens, 1024)
        else:
            max_tokens = default_max_tokens

        return ZhipuChatClient(api_key, model).complete(
            messages=[
                {
                    "role": "system",
                    "content": (
                        "你是一名学习日记润色助手。用户会给你一篇简短的学习日记内容，"
                        "你需要将其扩充为一段完整、连贯、有深度的学习反思。\n\n"
                        "润色要求：\n"
                        "1. 保持原文的核心意思和情感基调\n"
                        "2. 扩充内容：遇到的困难、解决过程、个人思考\n"
                        "3. 使表达更加生动、具体，避免空泛的表述，但不要过火\n"
                        "4. 用词准确、句式多样，符合日记的文体风格\n"
                        "5. 字数控制在70-130字之间\n\n"
                        "重要：只返回润色后的完整文本内容，不要加任何前缀、标注或解释。"
                    ),
                },
                {"role": "user", "content": content},
            ],
            max_tokens=max_tokens,
            temperature=0.7,
        )

    def list_entries(self, user_id):
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  id,
                  entry_date,
                  mood_score,
                  title,
                  content,
                  tags
                FROM diary_entries
                WHERE user_id = %s
                ORDER BY entry_date DESC, id DESC
                """,
                (user_id,),
            )
            rows = cursor.fetchall()

        return [self.to_entry(row) for row in rows]

    def update_entry(self, entry_id, user_id, entry_date, mood_score, title, content, tags):
        normalized_tags = [str(tag).strip() for tag in tags if str(tag).strip()]
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                SELECT id
                FROM diary_entries
                WHERE user_id = %s AND entry_date = %s AND id <> %s
                LIMIT 1
                """,
                (user_id, entry_date, entry_id),
            )
            if cursor.fetchone():
                raise ValueError("该日期已有其他日记，请选择其他日期")

            cursor.execute(
                """
                UPDATE diary_entries
                SET entry_date = %s,
                    mood_score = %s,
                    title = %s,
                    content = %s,
                    tags = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = %s AND user_id = %s
                """,
                (
                    entry_date,
                    mood_score,
                    title,
                    content,
                    json.dumps(normalized_tags, ensure_ascii=False),
                    entry_id,
                    user_id,
                ),
            )
            if cursor.rowcount == 0:
                return None
            cursor.execute(
                """
                SELECT id, entry_date, mood_score, title, content, tags, created_at
                FROM diary_entries
                WHERE id = %s
                """,
                (entry_id,),
            )
            return self.to_entry(cursor.fetchone())

    def delete_entry(self, entry_id, user_id):
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                "DELETE FROM diary_entries WHERE id = %s AND user_id = %s",
                (entry_id, user_id),
            )
            return cursor.rowcount > 0

    def to_entry(self, row):
        entry_date = row.get("entry_date")
        if entry_date is not None and hasattr(entry_date, "strftime"):
            entry_date_text = entry_date.strftime("%Y-%m-%d")
        else:
            entry_date_text = str(entry_date or "")[:10]

        return {
            "id": row["id"],
            "entryDate": entry_date_text,
            "title": row.get("title") or "",
            "moodScore": int(row.get("mood_score") or 0),
            "tags": self.parse_tags(row.get("tags")),
            "content": row.get("content") or "",
        }

    def parse_tags(self, raw_tags):
        if not raw_tags:
            return []

        if isinstance(raw_tags, list):
            return raw_tags

        if isinstance(raw_tags, bytes):
            raw_tags = raw_tags.decode("utf-8")

        if isinstance(raw_tags, str):
            try:
                parsed = json.loads(raw_tags)
            except json.JSONDecodeError:
                return []
            return parsed if isinstance(parsed, list) else []

        return []
