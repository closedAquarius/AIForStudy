import json
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from db import db_cursor
from services.zhipu_client import ZhipuChatClient

BACKEND_DIR = Path(__file__).resolve().parents[1]

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)


class DiaryInsightService:
    """Build and cache a user-level learning insight from recent activity."""

    DIARY_LIMIT = 7

    def get_latest(self, user_id: int) -> dict[str, Any]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM diary_insight_reports
                WHERE user_id=%s
                LIMIT 1
                """,
                (user_id,),
            )
            report = cursor.fetchone()

        if report:
            return self._serialize_report(report)
        return self.refresh(user_id, use_ai=False)

    def refresh(self, user_id: int, use_ai: bool = True) -> dict[str, Any]:
        context = self._load_context(user_id)
        if not context["diaries"]:
            with db_cursor(commit=True) as cursor:
                cursor.execute(
                    "DELETE FROM diary_insight_reports WHERE user_id=%s",
                    (user_id,),
                )
            return self._empty_report()

        result = self._build_local_insight(context)
        ai_generated = False
        if use_ai:
            try:
                result.update(self._call_ai(context))
                ai_generated = True
            except Exception:
                # Diary mutations must remain successful even when the AI provider is busy.
                ai_generated = False

        result["isAiGenerated"] = ai_generated
        self._save_report(user_id, context, result)
        return {
            **result,
            "diaryCount": context["diaryCount"],
            "averageMood": context["averageMood"],
            "answerCount": context["answerCount"],
            "accuracyRate": context["accuracyRate"],
            "studyMinutes": context["studyMinutes"],
            "weakPoints": context["weakPoints"],
            "generatedAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "hasData": True,
        }

    def _load_context(self, user_id: int) -> dict[str, Any]:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT id, entry_date, mood_score, title, content, tags, updated_at
                FROM diary_entries
                WHERE user_id=%s
                ORDER BY entry_date DESC, id DESC
                LIMIT %s
                """,
                (user_id, self.DIARY_LIMIT),
            )
            diaries = cursor.fetchall()

            cursor.execute(
                """
                SELECT COUNT(*) AS answer_count,
                       COALESCE(SUM(is_correct), 0) AS correct_count,
                       COALESCE(SUM(used_seconds), 0) AS used_seconds
                FROM practice_answers
                WHERE user_id=%s
                  AND answered_at>=DATE_SUB(NOW(), INTERVAL 14 DAY)
                """,
                (user_id,),
            )
            practice = cursor.fetchone() or {}

            cursor.execute(
                """
                SELECT q.knowledge_point,
                       COUNT(pa.id) AS answer_count,
                       ROUND(AVG(pa.is_correct) * 100, 1) AS accuracy_rate
                FROM practice_answers pa
                JOIN questions q ON q.id=pa.question_id
                WHERE pa.user_id=%s
                  AND q.knowledge_point IS NOT NULL
                  AND q.knowledge_point<>''
                GROUP BY q.knowledge_point
                HAVING COUNT(pa.id)>=2 AND AVG(pa.is_correct)<0.70
                ORDER BY accuracy_rate ASC, answer_count DESC
                LIMIT 3
                """,
                (user_id,),
            )
            weak_rows = cursor.fetchall()

        moods = [int(row.get("mood_score") or 0) for row in diaries if row.get("mood_score")]
        answer_count = int(practice.get("answer_count") or 0)
        correct_count = int(practice.get("correct_count") or 0)
        weak_points = [
            {
                "name": row.get("knowledge_point") or "",
                "answerCount": int(row.get("answer_count") or 0),
                "accuracyRate": float(row.get("accuracy_rate") or 0),
            }
            for row in weak_rows
        ]
        return {
            "diaries": diaries,
            "diaryCount": len(diaries),
            "averageMood": round(sum(moods) / len(moods), 1) if moods else 0,
            "answerCount": answer_count,
            "accuracyRate": round(correct_count * 100 / answer_count, 1) if answer_count else 0,
            "studyMinutes": round(int(practice.get("used_seconds") or 0) / 60),
            "weakPoints": weak_points,
        }

    def _build_local_insight(self, context: dict[str, Any]) -> dict[str, Any]:
        average_mood = float(context["averageMood"])
        accuracy = float(context["accuracyRate"])
        answer_count = int(context["answerCount"])
        weak_points = context["weakPoints"]

        if average_mood >= 8:
            mood_label = "状态积极"
            mood_trend = "近期心情较好，学习动力比较充足。"
        elif average_mood >= 6:
            mood_label = "状态平稳"
            mood_trend = "近期情绪总体稳定，可以保持当前节奏。"
        elif average_mood >= 4:
            mood_label = "略有压力"
            mood_trend = "近期可能有一些压力，建议适当降低单次任务量。"
        else:
            mood_label = "需要调整"
            mood_trend = "近期状态偏低，先保证休息和小步完成任务。"

        if answer_count == 0:
            learning_status = "近14天暂无刷题记录，学习状态主要依据日记内容判断。"
        elif accuracy >= 80:
            learning_status = f"近14天完成 {answer_count} 道题，正确率 {accuracy:.1f}%，掌握情况较好。"
        elif accuracy >= 60:
            learning_status = f"近14天完成 {answer_count} 道题，正确率 {accuracy:.1f}%，基础较稳但仍需巩固。"
        else:
            learning_status = f"近14天完成 {answer_count} 道题，正确率 {accuracy:.1f}%，建议优先回顾错题。"

        goals = ["每天完成一次不少于20分钟的专注学习", "复习当天产生的错题并写下错误原因"]
        if weak_points:
            goals.insert(0, f"优先巩固薄弱知识点：{weak_points[0]['name']}")
        if average_mood <= 5:
            goals.append("把每日任务拆成小步骤，完成核心任务即可")

        return {
            "moodLabel": mood_label,
            "moodTrend": mood_trend,
            "learningStatus": learning_status,
            "summary": f"综合最近 {context['diaryCount']} 篇日记和近14天学习记录，当前更适合保持稳定、可完成的学习节奏。",
            "goals": goals[:3],
            "suggestions": [
                "每天结束时用一句话记录最清楚和最困惑的知识点。",
                "把薄弱知识点与错题结合复习，避免只重复看答案。",
            ],
            "riskLevel": "medium" if average_mood and average_mood <= 4 else "low",
        }

    def _call_ai(self, context: dict[str, Any]) -> dict[str, Any]:
        api_key = os.getenv("ZHIPU_API_KEY", "")
        if not api_key:
            raise ValueError("ZHIPU_API_KEY is not configured")

        diary_lines = []
        for row in context["diaries"]:
            diary_lines.append(
                f"- {str(row.get('entry_date') or '')[:10]}，心情 {int(row.get('mood_score') or 0)}/10，"
                f"标题：{row.get('title') or ''}，内容：{(row.get('content') or '')[:500]}"
            )
        weak_text = "、".join(item["name"] for item in context["weakPoints"]) or "暂无明确薄弱点"
        prompt = f"""
你是一名克制、具体、不会进行医学诊断的学习状态分析助手。
请综合最近的学习日记和学习数据，分析用户的心情、学习状态，并制定未来3到7天可执行的目标。

最近日记：
{chr(10).join(diary_lines)}

近14天数据：
- 答题数：{context["answerCount"]}
- 正确率：{context["accuracyRate"]}%
- 学习时长：{context["studyMinutes"]}分钟
- 薄弱知识点：{weak_text}

仅返回合法JSON，不要Markdown，不要额外解释：
{{
  "moodLabel": "不超过8个字",
  "moodTrend": "一句具体的情绪趋势判断",
  "learningStatus": "一句学习状态判断，结合数据",
  "summary": "两句话以内的综合分析",
  "goals": ["目标1", "目标2", "目标3"],
  "suggestions": ["建议1", "建议2"],
  "riskLevel": "low或medium或high"
}}
""".strip()

        content = ZhipuChatClient(
            api_key,
            os.getenv("ZHIPU_MODEL", "glm-4.7-flash"),
        ).complete(
            messages=[{"role": "user", "content": prompt}],
            max_tokens=2048,
            temperature=0.4,
        )
        parsed = self._parse_json(content)
        return self._normalize_ai_result(parsed)

    def _parse_json(self, content: str) -> dict[str, Any]:
        text = re.sub(r"^```(?:json)?", "", content.strip()).strip()
        text = re.sub(r"```$", "", text).strip()
        try:
            result = json.loads(text)
        except json.JSONDecodeError:
            start = text.find("{")
            end = text.rfind("}")
            if start < 0 or end <= start:
                raise
            result = json.loads(text[start:end + 1])
        if not isinstance(result, dict):
            raise ValueError("AI insight response must be a JSON object")
        return result

    def _normalize_ai_result(self, result: dict[str, Any]) -> dict[str, Any]:
        goals = result.get("goals") if isinstance(result.get("goals"), list) else []
        suggestions = result.get("suggestions") if isinstance(result.get("suggestions"), list) else []
        risk_level = str(result.get("riskLevel") or "low").lower()
        if risk_level not in ("low", "medium", "high"):
            risk_level = "low"
        return {
            "moodLabel": str(result.get("moodLabel") or "状态平稳")[:30],
            "moodTrend": str(result.get("moodTrend") or "").strip(),
            "learningStatus": str(result.get("learningStatus") or "").strip(),
            "summary": str(result.get("summary") or "").strip(),
            "goals": [str(item).strip() for item in goals if str(item).strip()][:3],
            "suggestions": [str(item).strip() for item in suggestions if str(item).strip()][:3],
            "riskLevel": risk_level,
        }

    def _save_report(
        self,
        user_id: int,
        context: dict[str, Any],
        result: dict[str, Any],
    ) -> None:
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO diary_insight_reports
                  (user_id, source_diary_count, average_mood, answer_count,
                   accuracy_rate, study_minutes, mood_label, mood_trend,
                   learning_status, summary, goals, suggestions, weak_points,
                   risk_level, is_ai_generated, raw_result, generated_at)
                VALUES
                  (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                   %s, %s, %s, CURRENT_TIMESTAMP)
                ON DUPLICATE KEY UPDATE
                  source_diary_count=VALUES(source_diary_count),
                  average_mood=VALUES(average_mood),
                  answer_count=VALUES(answer_count),
                  accuracy_rate=VALUES(accuracy_rate),
                  study_minutes=VALUES(study_minutes),
                  mood_label=VALUES(mood_label),
                  mood_trend=VALUES(mood_trend),
                  learning_status=VALUES(learning_status),
                  summary=VALUES(summary),
                  goals=VALUES(goals),
                  suggestions=VALUES(suggestions),
                  weak_points=VALUES(weak_points),
                  risk_level=VALUES(risk_level),
                  is_ai_generated=VALUES(is_ai_generated),
                  raw_result=VALUES(raw_result),
                  generated_at=CURRENT_TIMESTAMP
                """,
                (
                    user_id,
                    context["diaryCount"],
                    context["averageMood"],
                    context["answerCount"],
                    context["accuracyRate"],
                    context["studyMinutes"],
                    result["moodLabel"],
                    result["moodTrend"],
                    result["learningStatus"],
                    result["summary"],
                    json.dumps(result["goals"], ensure_ascii=False),
                    json.dumps(result["suggestions"], ensure_ascii=False),
                    json.dumps(context["weakPoints"], ensure_ascii=False),
                    result["riskLevel"],
                    1 if result.get("isAiGenerated") else 0,
                    json.dumps(result, ensure_ascii=False),
                ),
            )

    def _serialize_report(self, row: dict[str, Any]) -> dict[str, Any]:
        return {
            "hasData": True,
            "moodLabel": row.get("mood_label") or "",
            "moodTrend": row.get("mood_trend") or "",
            "learningStatus": row.get("learning_status") or "",
            "summary": row.get("summary") or "",
            "goals": self._json_list(row.get("goals")),
            "suggestions": self._json_list(row.get("suggestions")),
            "weakPoints": self._json_list(row.get("weak_points")),
            "riskLevel": row.get("risk_level") or "low",
            "isAiGenerated": bool(row.get("is_ai_generated")),
            "diaryCount": int(row.get("source_diary_count") or 0),
            "averageMood": float(row.get("average_mood") or 0),
            "answerCount": int(row.get("answer_count") or 0),
            "accuracyRate": float(row.get("accuracy_rate") or 0),
            "studyMinutes": int(row.get("study_minutes") or 0),
            "generatedAt": str(row.get("generated_at") or ""),
        }

    def _json_list(self, value: Any) -> list[Any]:
        if isinstance(value, list):
            return value
        if isinstance(value, bytes):
            value = value.decode("utf-8")
        if isinstance(value, str):
            try:
                result = json.loads(value)
                return result if isinstance(result, list) else []
            except json.JSONDecodeError:
                return []
        return []

    def _empty_report(self) -> dict[str, Any]:
        return {
            "hasData": False,
            "moodLabel": "",
            "moodTrend": "",
            "learningStatus": "",
            "summary": "",
            "goals": [],
            "suggestions": [],
            "weakPoints": [],
            "riskLevel": "low",
            "isAiGenerated": False,
            "diaryCount": 0,
            "averageMood": 0,
            "answerCount": 0,
            "accuracyRate": 0,
            "studyMinutes": 0,
            "generatedAt": "",
        }
