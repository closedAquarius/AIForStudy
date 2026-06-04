import json
import os
import re
from pathlib import Path
from json import JSONDecodeError
from typing import Any

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parents[1]

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)

ALLOWED_QUESTION_TYPES = {
    "single_choice",
    "multiple_choice",
    "true_false",
    "blank",
    "short_answer",
    "essay",
}

QUESTION_JSON_SCHEMA_TEXT = """
{
  "question_bank": {
    "name": "题库名称",
    "description": "题库说明",
    "subject": "学科名称",
    "source_type": "document_ai"
  },
  "questions": [
    {
      "type": "single_choice",
      "stem": "题干",
      "analysis": "解析",
      "difficulty": 3,
      "score": 2,
      "knowledge_point": "知识点",
      "tags": ["标签1", "标签2"],
      "options": [
        {"option_key": "A", "content": "选项A", "is_correct": false, "sort_order": 1},
        {"option_key": "B", "content": "选项B", "is_correct": true, "sort_order": 2}
      ],
      "answers": [
        {"answer_text": "B", "answer_json": {"option_keys": ["B"]}, "is_primary": true}
      ],
      "extra": {
        "source_excerpt": "题目依据的原文片段"
      }
    }
  ]
}
"""


class ZhipuQuestionService:
    """Reusable service for asking Zhipu AI to generate DB-ready questions."""

    def __init__(self, api_key: str | None = None, model: str | None = None):
        self.api_key = api_key or os.getenv("ZHIPU_API_KEY", "")
        self.model = model or os.getenv("ZHIPU_MODEL", "glm-4.7-flash")

    def generate_questions(
        self,
        document_text: str,
        subject: str,
        question_count: int = 5,
        question_types: list[str] | None = None,
        difficulty: int | None = None,
        extra_prompt: str = "",
    ) -> dict[str, Any]:
        if not self.api_key:
            raise ValueError("ZHIPU_API_KEY is not configured")

        cleaned_text = document_text.strip()
        if len(cleaned_text) < 20:
            raise ValueError("document_text is too short")

        normalized_types = self._normalize_question_types(question_types)
        normalized_count = max(1, min(question_count, 30))
        normalized_difficulty = self._normalize_difficulty(difficulty)

        prompt = self._build_prompt(
            document_text=cleaned_text,
            subject=subject.strip() or "未指定学科",
            question_count=normalized_count,
            question_types=normalized_types,
            difficulty=normalized_difficulty,
            extra_prompt=extra_prompt.strip(),
        )

        raw_content = self._call_zhipu(prompt)
        try:
            parsed = self._parse_json_content(raw_content)
        except JSONDecodeError:
            repaired_content = self._repair_json_content(raw_content)
            parsed = self._parse_json_content(repaired_content)
        result = self._normalize_result(parsed)
        result["questions"] = result["questions"][:normalized_count]
        return result

    def _call_zhipu(self, prompt: str) -> str:
        try:
            from zai import ZhipuAiClient
        except ImportError as exc:
            raise RuntimeError("Please install Zhipu SDK first: pip install zai") from exc

        client = ZhipuAiClient(api_key=self.api_key)
        response = client.chat.completions.create(
            model=self.model,
            messages=[
                {
                    "role": "system",
                    "content": "你是一名严谨的教师和题库工程师，擅长把课程资料转换成可入库的结构化题目。",
                },
                {"role": "user", "content": prompt},
            ],
            thinking={"type": "enabled"},
            max_tokens=65536,
            temperature=0.6,
        )

        message = response.choices[0].message
        content = getattr(message, "content", None)
        if content is None and isinstance(message, dict):
            content = message.get("content")
        if not isinstance(content, str):
            content = str(message)
        return content

    def _build_prompt(
        self,
        document_text: str,
        subject: str,
        question_count: int,
        question_types: list[str],
        difficulty: int | None,
        extra_prompt: str,
    ) -> str:
        difficulty_text = "由你根据资料内容判断，范围 1-5"
        if difficulty is not None:
            difficulty_text = f"统一控制在 {difficulty} 级，范围 1-5"

        types_text = "、".join(question_types)
        return f"""
请根据下面的课程资料生成题库题目，返回结果必须严格符合 JSON，不要输出 Markdown，不要输出解释文字。

数据库入库要求：
1. 返回顶层必须包含 question_bank 和 questions。
2. questions 中每道题必须包含 type、stem、analysis、difficulty、score、knowledge_point、tags、options、answers、extra。
3. type 只能取以下值之一：single_choice、multiple_choice、true_false、blank、short_answer、essay。
4. single_choice 和 multiple_choice 必须提供 options，option_key 使用 A、B、C、D。
5. true_false、blank、short_answer、essay 可以让 options 为空数组。
6. answers 必须至少有 1 个答案；选择题 answer_text 使用选项字母，例如 B 或 A,C。
7. difficulty 必须是 1 到 5 的整数。
8. tags 使用字符串数组，适合入库到 tags 和 question_tags。
9. extra.source_excerpt 保存题目依据的原文片段，方便追踪来源。
10. 所有题目必须来自资料内容，不要编造资料外知识。

目标学科：{subject}
题目数量：{question_count}
题型范围：{types_text}
难度要求：{difficulty_text}
额外要求：{extra_prompt or "无"}

请严格按下面 JSON 结构返回：
{QUESTION_JSON_SCHEMA_TEXT}

课程资料：
{document_text}
""".strip()

    def _parse_json_content(self, raw_content: str) -> dict[str, Any]:
        text = raw_content.strip()
        text = re.sub(r"^```(?:json)?", "", text).strip()
        text = re.sub(r"```$", "", text).strip()

        try:
            return json.loads(text)
        except json.JSONDecodeError:
            start = text.find("{")
            end = text.rfind("}")
            if start >= 0 and end > start:
                return json.loads(text[start : end + 1])
            raise

    def _repair_json_content(self, raw_content: str) -> str:
        prompt = f"""
下面是一段不完整或格式有误的 JSON。请只修复 JSON 格式，保持原有题目内容，不要新增解释文字，不要输出 Markdown。

要求：
1. 返回必须是一个合法 JSON 对象。
2. 顶层保留 question_bank 和 questions。
3. 不要省略已有题目。
4. 如果某个字符串缺少引号或逗号，请补齐。

待修复内容：
{raw_content}
""".strip()
        return self._call_zhipu(prompt)

    def _normalize_result(self, result: dict[str, Any]) -> dict[str, Any]:
        bank = result.get("question_bank") or {}
        questions = result.get("questions") or []
        if not isinstance(questions, list) or len(questions) == 0:
            raise ValueError("AI response does not contain questions")

        normalized_questions: list[dict[str, Any]] = []
        for index, question in enumerate(questions, start=1):
            if not isinstance(question, dict):
                raise ValueError(f"question #{index} is not an object")

            question_type = question.get("type")
            if question_type not in ALLOWED_QUESTION_TYPES:
                raise ValueError(f"question #{index} has invalid type: {question_type}")

            stem = str(question.get("stem") or "").strip()
            if not stem:
                raise ValueError(f"question #{index} has empty stem")

            difficulty = self._normalize_difficulty(question.get("difficulty")) or 3
            options = question.get("options") or []
            answers = question.get("answers") or []
            tags = question.get("tags") or []
            extra = question.get("extra") or {}

            if question_type in {"single_choice", "multiple_choice"} and not options:
                raise ValueError(f"question #{index} choice question has no options")
            if not answers:
                raise ValueError(f"question #{index} has no answers")

            normalized_questions.append({
                "type": question_type,
                "stem": stem,
                "analysis": str(question.get("analysis") or "").strip(),
                "difficulty": difficulty,
                "score": float(question.get("score") or 1),
                "knowledge_point": str(question.get("knowledge_point") or "").strip(),
                "tags": [str(tag).strip() for tag in tags if str(tag).strip()],
                "options": self._normalize_options(options),
                "answers": self._normalize_answers(answers),
                "extra": extra if isinstance(extra, dict) else {"raw_extra": extra},
            })

        return {
            "question_bank": {
                "name": str(bank.get("name") or "AI 生成题库").strip(),
                "description": str(bank.get("description") or "").strip(),
                "subject": str(bank.get("subject") or "").strip(),
                "source_type": "document_ai",
            },
            "questions": normalized_questions,
        }

    def _normalize_options(self, options: Any) -> list[dict[str, Any]]:
        if not isinstance(options, list):
            return []
        normalized = []
        for index, option in enumerate(options, start=1):
            if not isinstance(option, dict):
                continue
            normalized.append({
                "option_key": str(option.get("option_key") or chr(64 + index)).strip(),
                "content": str(option.get("content") or "").strip(),
                "is_correct": bool(option.get("is_correct")),
                "sort_order": int(option.get("sort_order") or index),
            })
        return normalized

    def _normalize_answers(self, answers: Any) -> list[dict[str, Any]]:
        if not isinstance(answers, list):
            return []
        normalized = []
        for answer in answers:
            if not isinstance(answer, dict):
                continue
            answer_json = answer.get("answer_json")
            normalized.append({
                "answer_text": str(answer.get("answer_text") or "").strip(),
                "answer_json": answer_json if isinstance(answer_json, dict) else None,
                "is_primary": bool(answer.get("is_primary", True)),
            })
        return normalized

    def _normalize_question_types(self, question_types: list[str] | None) -> list[str]:
        if not question_types:
            return ["single_choice", "true_false", "blank", "short_answer"]

        normalized = []
        for question_type in question_types:
            if question_type in ALLOWED_QUESTION_TYPES:
                normalized.append(question_type)
        return normalized or ["single_choice", "true_false", "blank", "short_answer"]

    def _normalize_difficulty(self, difficulty: Any) -> int | None:
        if difficulty is None or difficulty == "":
            return None
        try:
            value = int(difficulty)
        except (TypeError, ValueError):
            return None
        return max(1, min(value, 5))
