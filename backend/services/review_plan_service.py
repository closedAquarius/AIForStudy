import json
from datetime import date, timedelta
from typing import Any

from db import db_cursor


class ReviewPlanService:
    BASE_TARGET = 10
    MIN_TARGET = 5
    MAX_TARGET = 15

    def get_today_plan(self, user_id: int) -> dict[str, Any]:
        today = date.today()
        with db_cursor(commit=True) as cursor:
            self._sync_wrong_schedules(cursor, user_id, today)
            plan = self._find_plan(cursor, user_id, today)
            if not plan:
                plan_id = self._create_plan(cursor, user_id, today)
                plan = self._find_plan_by_id(cursor, plan_id)
            tasks = self._load_tasks(cursor, plan["id"])

        return self._serialize_plan(plan, tasks, self._learning_streak(user_id))

    def start_today_plan(self, user_id: int) -> dict[str, Any]:
        today_plan = self.get_today_plan(user_id)
        if today_plan["totalCount"] == 0:
            raise ValueError("今天暂无需要复习的题目")
        if today_plan["status"] == "completed":
            raise ValueError("今天的复习任务已经完成")

        plan_id = int(today_plan["id"])
        with db_cursor(commit=True) as cursor:
            plan = self._find_plan_by_id(cursor, plan_id)
            session_id = int(plan.get("practice_session_id") or 0)
            if session_id > 0:
                cursor.execute(
                    """
                    SELECT id, finished_at
                    FROM practice_sessions
                    WHERE id=%s AND user_id=%s
                    LIMIT 1
                    """,
                    (session_id, user_id),
                )
                session = cursor.fetchone()
                if session and not session.get("finished_at"):
                    return {"sessionId": session_id, "planId": plan_id}

            cursor.execute(
                """
                SELECT question_id
                FROM daily_review_tasks
                WHERE plan_id=%s AND status='pending'
                ORDER BY sort_order, id
                """,
                (plan_id,),
            )
            question_ids = [int(row["question_id"]) for row in cursor.fetchall()]
            if not question_ids:
                raise ValueError("今天的复习任务已经完成")

            filter_config = {
                "selected_mode": "daily_review",
                "review_plan_id": plan_id,
                "question_ids": question_ids,
            }
            cursor.execute(
                """
                INSERT INTO practice_sessions
                  (user_id, question_bank_id, mode, filter_config, started_at,
                   total_count, correct_count, wrong_count, duration_seconds)
                VALUES (%s, NULL, 'review', %s, NOW(), %s, 0, 0, 0)
                """,
                (user_id, json.dumps(filter_config, ensure_ascii=False), len(question_ids)),
            )
            session_id = cursor.lastrowid
            cursor.execute(
                """
                UPDATE daily_review_plans
                SET practice_session_id=%s, status='in_progress'
                WHERE id=%s AND user_id=%s
                """,
                (session_id, plan_id, user_id),
            )
        return {"sessionId": session_id, "planId": plan_id}

    def complete_practice_session(
        self,
        user_id: int,
        session_id: int,
        results: list[dict[str, Any]],
    ) -> None:
        if not results:
            return

        today = date.today()
        result_map = {
            int(item["questionId"]): int(item.get("isCorrect") or 0)
            for item in results
        }
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                SELECT id
                FROM daily_review_plans
                WHERE user_id=%s AND practice_session_id=%s
                LIMIT 1
                """,
                (user_id, session_id),
            )
            plan = cursor.fetchone()
            if not plan:
                return

            plan_id = int(plan["id"])
            for question_id, is_correct in result_map.items():
                cursor.execute(
                    """
                    UPDATE daily_review_tasks
                    SET status='completed', is_correct=%s, completed_at=NOW()
                    WHERE plan_id=%s AND question_id=%s
                    """,
                    (is_correct, plan_id, question_id),
                )
                self._advance_schedule(cursor, user_id, question_id, is_correct == 1, today)

            cursor.execute(
                """
                SELECT COUNT(*) AS total_count,
                       COALESCE(SUM(status='completed'), 0) AS completed_count
                FROM daily_review_tasks
                WHERE plan_id=%s
                """,
                (plan_id,),
            )
            counts = cursor.fetchone() or {}
            total_count = int(counts.get("total_count") or 0)
            completed_count = int(counts.get("completed_count") or 0)
            completed = total_count > 0 and completed_count >= total_count
            cursor.execute(
                """
                UPDATE daily_review_plans
                SET completed_count=%s,
                    status=%s,
                    completed_at=CASE WHEN %s=1 THEN NOW() ELSE completed_at END
                WHERE id=%s
                """,
                (completed_count, "completed" if completed else "in_progress", 1 if completed else 0, plan_id),
            )

    def _sync_wrong_schedules(self, cursor, user_id: int, today: date) -> None:
        cursor.execute(
            """
            INSERT IGNORE INTO review_schedules
              (user_id, question_id, review_stage, next_review_date,
               last_result, consecutive_correct, status)
            SELECT %s, pa.question_id, 0, %s, 'wrong', 0, 'active'
            FROM practice_answers pa
            WHERE pa.user_id=%s
              AND pa.id = (
                SELECT MAX(pa2.id)
                FROM practice_answers pa2
                WHERE pa2.user_id=pa.user_id
                  AND pa2.question_id=pa.question_id
              )
              AND pa.is_correct=0
              AND pa.review_status='needs_review'
            """,
            (user_id, today, user_id),
        )

    def _create_plan(self, cursor, user_id: int, today: date) -> int:
        target_count, adjustment, mood_summary = self._mood_adjustment(cursor, user_id)
        due_rows = self._due_questions(cursor, user_id, today, target_count)
        selected_ids = {int(row["question_id"]) for row in due_rows}

        remaining = max(0, target_count - len(due_rows))
        weak_rows = self._weak_knowledge_questions(cursor, user_id, selected_ids, remaining)
        tasks = due_rows + weak_rows

        wrong_count = sum(1 for row in tasks if row["source_type"] == "wrong_question")
        weak_count = len(tasks) - wrong_count
        reason = (
            f"根据 {wrong_count} 道到期错题和 {weak_count} 道薄弱知识点题目生成。"
            f"{mood_summary}"
        )
        cursor.execute(
            """
            INSERT INTO daily_review_plans
              (user_id, plan_date, target_count, completed_count, mood_adjustment,
               mood_summary, generation_reason, status)
            VALUES (%s, %s, %s, 0, %s, %s, %s, %s)
            """,
            (
                user_id,
                today,
                len(tasks),
                adjustment,
                mood_summary,
                reason,
                "completed" if not tasks else "pending",
            ),
        )
        plan_id = cursor.lastrowid
        for index, row in enumerate(tasks):
            cursor.execute(
                """
                INSERT INTO daily_review_tasks
                  (plan_id, question_id, source_type, knowledge_point, sort_order)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    plan_id,
                    row["question_id"],
                    row["source_type"],
                    row.get("knowledge_point") or "",
                    index + 1,
                ),
            )
        return plan_id

    def _mood_adjustment(self, cursor, user_id: int) -> tuple[int, int, str]:
        cursor.execute(
            """
            SELECT mood_score, title, content
            FROM diary_entries
            WHERE user_id=%s
            ORDER BY entry_date DESC, id DESC
            LIMIT 3
            """,
            (user_id,),
        )
        entries = cursor.fetchall()
        scores = [int(row.get("mood_score") or 0) for row in entries if row.get("mood_score")]
        if not scores:
            return self.BASE_TARGET, 0, "近期没有日记记录，保持标准任务量。"

        average = sum(scores) / len(scores)
        adjustment = 0
        if average <= 4:
            adjustment = -4
            summary = f"近期平均心情 {average:.1f}/10，任务量已明显降低，优先保持节奏。"
        elif average <= 6:
            adjustment = -2
            summary = f"近期平均心情 {average:.1f}/10，任务量已适当降低。"
        elif average >= 8:
            adjustment = 2
            summary = f"近期平均心情 {average:.1f}/10，状态较好，任务量适当增加。"
        else:
            summary = f"近期平均心情 {average:.1f}/10，保持标准任务量。"
        target = max(self.MIN_TARGET, min(self.MAX_TARGET, self.BASE_TARGET + adjustment))
        return target, adjustment, summary

    def _due_questions(self, cursor, user_id: int, today: date, limit: int) -> list[dict[str, Any]]:
        cursor.execute(
            """
            SELECT rs.question_id, q.knowledge_point, 'wrong_question' AS source_type
            FROM review_schedules rs
            JOIN questions q ON q.id=rs.question_id AND q.status='active'
            JOIN question_banks qb ON qb.id=q.question_bank_id
            WHERE rs.user_id=%s
              AND rs.status='active'
              AND rs.next_review_date<=%s
              AND (qb.owner_user_id=%s OR qb.visibility='public')
            ORDER BY rs.next_review_date, rs.review_stage, rs.updated_at
            LIMIT %s
            """,
            (user_id, today, user_id, limit),
        )
        return cursor.fetchall()

    def _weak_knowledge_questions(
        self,
        cursor,
        user_id: int,
        excluded_ids: set[int],
        limit: int,
    ) -> list[dict[str, Any]]:
        if limit <= 0:
            return []
        cursor.execute(
            """
            SELECT q.knowledge_point,
                   COUNT(pa.id) AS answer_count,
                   AVG(pa.is_correct) AS accuracy
            FROM practice_answers pa
            JOIN questions q ON q.id=pa.question_id
            WHERE pa.user_id=%s
              AND q.knowledge_point IS NOT NULL
              AND q.knowledge_point<>''
            GROUP BY q.knowledge_point
            HAVING COUNT(pa.id)>=2 AND AVG(pa.is_correct)<0.70
            ORDER BY accuracy ASC, answer_count DESC
            LIMIT 8
            """,
            (user_id,),
        )
        weak_points = [row["knowledge_point"] for row in cursor.fetchall()]
        if not weak_points:
            return []

        placeholders = ",".join(["%s"] * len(weak_points))
        params: list[Any] = [user_id, *weak_points]
        exclude_sql = ""
        if excluded_ids:
            exclude_sql = f" AND q.id NOT IN ({','.join(['%s'] * len(excluded_ids))}) "
            params.extend(sorted(excluded_ids))
        params.append(limit)
        cursor.execute(
            f"""
            SELECT q.id AS question_id, q.knowledge_point,
                   'weak_knowledge' AS source_type
            FROM questions q
            JOIN question_banks qb ON qb.id=q.question_bank_id
            LEFT JOIN review_schedules rs
              ON rs.user_id=%s AND rs.question_id=q.id
            WHERE q.status='active'
              AND q.knowledge_point IN ({placeholders})
              AND (qb.owner_user_id=%s OR qb.visibility='public')
              AND (rs.id IS NULL OR rs.status='mastered')
              {exclude_sql}
            ORDER BY q.difficulty, q.id
            LIMIT %s
            """,
            [params[0], *params[1:1 + len(weak_points)], user_id, *params[1 + len(weak_points):]],
        )
        return cursor.fetchall()

    def _advance_schedule(
        self,
        cursor,
        user_id: int,
        question_id: int,
        is_correct: bool,
        today: date,
    ) -> None:
        cursor.execute(
            """
            SELECT *
            FROM review_schedules
            WHERE user_id=%s AND question_id=%s
            LIMIT 1
            """,
            (user_id, question_id),
        )
        schedule = cursor.fetchone()
        if not schedule:
            cursor.execute(
                """
                INSERT INTO review_schedules
                  (user_id, question_id, review_stage, next_review_date,
                   last_result, consecutive_correct, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    question_id,
                    1 if is_correct else 0,
                    today + timedelta(days=1),
                    "correct" if is_correct else "wrong",
                    1 if is_correct else 0,
                    "active",
                ),
            )
            return

        if not is_correct:
            cursor.execute(
                """
                UPDATE review_schedules
                SET review_stage=0, next_review_date=%s, last_result='wrong',
                    consecutive_correct=0, status='active'
                WHERE id=%s
                """,
                (today + timedelta(days=1), schedule["id"]),
            )
            return

        current_stage = int(schedule.get("review_stage") or 0)
        if current_stage >= 3:
            cursor.execute(
                """
                UPDATE review_schedules
                SET last_result='correct',
                    consecutive_correct=consecutive_correct+1,
                    status='mastered'
                WHERE id=%s
                """,
                (schedule["id"],),
            )
            return

        next_stage = current_stage + 1
        interval_days = {1: 1, 2: 3, 3: 7}[next_stage]
        cursor.execute(
            """
            UPDATE review_schedules
            SET review_stage=%s, next_review_date=%s, last_result='correct',
                consecutive_correct=consecutive_correct+1, status='active'
            WHERE id=%s
            """,
            (next_stage, today + timedelta(days=interval_days), schedule["id"]),
        )

    def _find_plan(self, cursor, user_id: int, plan_date: date):
        cursor.execute(
            """
            SELECT *
            FROM daily_review_plans
            WHERE user_id=%s AND plan_date=%s
            LIMIT 1
            """,
            (user_id, plan_date),
        )
        return cursor.fetchone()

    def _find_plan_by_id(self, cursor, plan_id: int):
        cursor.execute("SELECT * FROM daily_review_plans WHERE id=%s LIMIT 1", (plan_id,))
        return cursor.fetchone()

    def _load_tasks(self, cursor, plan_id: int) -> list[dict[str, Any]]:
        cursor.execute(
            """
            SELECT drt.id, drt.question_id, drt.source_type, drt.knowledge_point,
                   drt.sort_order, drt.status, drt.is_correct,
                   q.type, q.stem, q.difficulty, qb.name AS bank_name
            FROM daily_review_tasks drt
            JOIN questions q ON q.id=drt.question_id
            JOIN question_banks qb ON qb.id=q.question_bank_id
            WHERE drt.plan_id=%s
            ORDER BY drt.sort_order, drt.id
            """,
            (plan_id,),
        )
        return cursor.fetchall()

    def _learning_streak(self, user_id: int) -> int:
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT plan_date
                FROM daily_review_plans
                WHERE user_id=%s AND status='completed' AND target_count>0
                ORDER BY plan_date DESC
                LIMIT 180
                """,
                (user_id,),
            )
            completed_dates = {row["plan_date"] for row in cursor.fetchall()}

        cursor_date = date.today()
        if cursor_date not in completed_dates:
            cursor_date -= timedelta(days=1)
        streak = 0
        while cursor_date in completed_dates:
            streak += 1
            cursor_date -= timedelta(days=1)
        return streak

    def _serialize_plan(
        self,
        plan: dict[str, Any],
        tasks: list[dict[str, Any]],
        streak: int,
    ) -> dict[str, Any]:
        return {
            "id": int(plan["id"]),
            "planDate": str(plan["plan_date"]),
            "targetCount": int(plan.get("target_count") or 0),
            "completedCount": int(plan.get("completed_count") or 0),
            "totalCount": len(tasks),
            "moodAdjustment": int(plan.get("mood_adjustment") or 0),
            "moodSummary": plan.get("mood_summary") or "",
            "generationReason": plan.get("generation_reason") or "",
            "status": plan.get("status") or "pending",
            "practiceSessionId": int(plan.get("practice_session_id") or 0),
            "streakDays": streak,
            "tasks": [
                {
                    "id": int(row["id"]),
                    "questionId": int(row["question_id"]),
                    "sourceType": row["source_type"],
                    "knowledgePoint": row.get("knowledge_point") or "",
                    "status": row["status"],
                    "isCorrect": None if row.get("is_correct") is None else int(row["is_correct"]),
                    "type": row.get("type") or "",
                    "stem": row.get("stem") or "",
                    "difficulty": int(row.get("difficulty") or 1),
                    "bankName": row.get("bank_name") or "",
                }
                for row in tasks
            ],
        }
