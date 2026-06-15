from flask import Blueprint

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
