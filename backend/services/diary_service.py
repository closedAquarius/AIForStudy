import json
import os

from pathlib import Path

from db import db_cursor
from dotenv import load_dotenv

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

        model = os.getenv("ZHIPU_MODEL", "glm-4.7-flash")

        try:
            from zai import ZhipuAiClient
        except ImportError as exc:
            raise RuntimeError("请先安装智谱 SDK: pip install zai-sdk") from exc

        client = ZhipuAiClient(api_key=api_key)
        response = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "你是一名学习日记润色助手。用户会给你一篇学习日记的内容，"
                        "请你对其进行润色优化，使表达更加流畅、结构更加清晰、用词更加准确，"
                        "同时保持原文的核心意思和语气不变。"
                        "只返回润色后的文本内容，不要加任何前缀、标注或解释。"
                    ),
                },
                {"role": "user", "content": content},
            ],
            max_tokens=4096,
            temperature=0.5,
        )

        message = response.choices[0].message
        result = getattr(message, "content", None)
        if result is None and isinstance(message, dict):
            result = message.get("content")
        if not isinstance(result, str):
            result = str(message)
        return result.strip()

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
        return {
            "id": row["id"],
            "entryDate": str(row.get("entry_date") or ""),
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
