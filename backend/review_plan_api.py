from flask import Blueprint, request

from api_utils import fail, require_current_user, success
from services.review_plan_service import ReviewPlanService

review_plan_bp = Blueprint("review_plan_api", __name__)


@review_plan_bp.get("/review/today")
def get_today_review_plan():
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        return success(ReviewPlanService().get_today_plan(user["id"]))
    except Exception as exc:
        return fail(f"今日复习计划加载失败: {exc}", 500)


@review_plan_bp.post("/review/today/start")
def start_today_review_plan():
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        return success(ReviewPlanService().start_today_plan(user["id"]), "今日复习已开始", 201)
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        return fail(f"今日复习启动失败: {exc}", 500)


@review_plan_bp.post("/review/today/regenerate")
def regenerate_today_review_plan():
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        return success(
            ReviewPlanService().regenerate_today_plan(user["id"]),
            "今日学习任务已重新生成",
        )
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        return fail(f"今日学习任务重新生成失败: {exc}", 500)


@review_plan_bp.put("/review/today/tasks/<int:task_id>")
def update_today_review_task(task_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    action = str((request.get_json(silent=True) or {}).get("action") or "").strip()
    if action not in ("skip", "postpone", "restore"):
        return fail("action 只能是 skip、postpone 或 restore")
    try:
        return success(
            ReviewPlanService().update_task(user["id"], task_id, action),
            "任务状态已更新",
        )
    except LookupError as exc:
        return fail(str(exc), 404)
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        return fail(f"任务状态更新失败: {exc}", 500)
