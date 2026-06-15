import os
import json
import uuid
import tempfile
import smtplib
from datetime import datetime, timedelta
from pathlib import Path

from flask import Flask, request, send_from_directory
from pymysql.err import IntegrityError

from api_utils import success, fail, public_user, require_current_user
from question_bank_api import question_bank_bp
from werkzeug.utils import secure_filename

from db import db_cursor
from services.diary_service import DiaryService
from services.ai_learning_service import AiLearningService, AiProviderBusyError
from services.document_text_extractor import DocumentTextExtractor
from services.question_persistence_service import QuestionPersistenceService
from services.zhipu_question_service import ZhipuQuestionService
from services.password_reset_service import PasswordResetService
from practice_api import practice_bp
from question_record_api import question_record_bp
from knowledge_base_api import knowledge_base_bp
from review_plan_api import review_plan_bp



app = Flask(__name__)
app.register_blueprint(question_bank_bp, url_prefix="/api")
app.register_blueprint(practice_bp, url_prefix="/api")
app.register_blueprint(question_record_bp, url_prefix="/api")
app.register_blueprint(knowledge_base_bp, url_prefix="/api")
app.register_blueprint(review_plan_bp, url_prefix="/api")

UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
AVATAR_DIR = UPLOAD_DIR / "avatars"
AVATAR_DIR.mkdir(exist_ok=True)


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/<path:_path>", methods=["OPTIONS"])
def cors_preflight(_path):
    return "", 204


def optional_int(value):
    if value is None or value == "":
        return None
    return int(value)


def to_diary_entry(row):
    raw_tags = row.get("tags")
    tags = []
    if raw_tags:
        if isinstance(raw_tags, str):
            try:
                tags = json.loads(raw_tags)
            except json.JSONDecodeError:
                tags = []
        else:
            tags = raw_tags

    return {
        "id": row["id"],
        "entryDate": str(row.get("entry_date") or "")[:10],
        "moodScore": int(row.get("mood_score") or 0),
        "title": row.get("title") or "",
        "content": row.get("content") or "",
        "tags": tags if isinstance(tags, list) else [],
        "createdAt": str(row.get("created_at") or ""),
    }


@app.get("/api/health")
def health():
    try:
        with db_cursor() as cursor:
            cursor.execute("SELECT 1 AS ok")
            cursor.fetchone()
        return success({"time": datetime.now().isoformat()}, "backend and database are ready")
    except Exception as exc:
        return fail(f"database connection failed: {exc}", 500)


@app.post("/api/auth/register")
def register():
    body = request.get_json(silent=True) or {}
    username = (body.get("username") or "").strip()
    password = (body.get("password") or "").strip()
    nickname = (body.get("nickname") or username).strip()
    email = (body.get("email") or "").strip() or None

    if len(username) < 3:
        return fail("用户名至少需要 3 个字符")
    if len(password) < 6:
        return fail("密码至少需要 6 个字符")

    try:
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO users (username, password, nickname, email, avatar_url)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (username, password, nickname, email, "ailearning_icon.png"),
            )
            user_id = cursor.lastrowid
            cursor.execute("SELECT * FROM users WHERE id=%s", (user_id,))
            user = cursor.fetchone()
            token = uuid.uuid4().hex
            expires_at = datetime.now() + timedelta(days=7)
            cursor.execute(
                """
                INSERT INTO user_sessions (user_id, token, expires_at)
                VALUES (%s, %s, %s)
                """,
                (user_id, token, expires_at),
            )
        return success({"token": token, "user": public_user(user)}, "注册成功", 201)
    except IntegrityError:
        return fail("用户名或邮箱已存在", 409)


@app.post("/api/auth/login")
def login():
    body = request.get_json(silent=True) or {}
    username = (body.get("username") or "").strip()
    password = (body.get("password") or "").strip()

    if not username or not password:
        return fail("请输入用户名和密码")

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            SELECT * FROM users
            WHERE username=%s AND password=%s AND status='active'
            LIMIT 1
            """,
            (username, password),
        )
        user = cursor.fetchone()
        if not user:
            return fail("用户名或密码错误", 401)

        token = uuid.uuid4().hex
        expires_at = datetime.now() + timedelta(days=7)
        cursor.execute(
            """
            INSERT INTO user_sessions (user_id, token, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user["id"], token, expires_at),
        )

    return success({"token": token, "user": public_user(user)}, "登录成功")


@app.post("/api/auth/password-reset/send-code")
def send_password_reset_code():
    body = request.get_json(silent=True) or {}
    email = str(body.get("email") or "").strip()
    try:
        PasswordResetService().send_code(email)
        return success(message="验证码已发送，请检查邮箱")
    except ValueError as exc:
        return fail(str(exc), 400)
    except (OSError, smtplib.SMTPException) as exc:
        app.logger.exception("send password reset email failed")
        return fail(f"验证码发送失败，请检查邮件服务配置: {exc}", 502)
    except RuntimeError as exc:
        return fail(str(exc), 500)


@app.post("/api/auth/password-reset/confirm")
def confirm_password_reset():
    body = request.get_json(silent=True) or {}
    email = str(body.get("email") or "").strip()
    code = str(body.get("code") or "").strip()
    new_password = str(body.get("new_password") or "")
    try:
        PasswordResetService().reset_password(email, code, new_password)
        return success(message="密码重置成功，请使用新密码登录")
    except ValueError as exc:
        return fail(str(exc), 400)


@app.get("/api/me")
def me():
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "", 1).strip()
    if not token:
        return fail("缺少登录凭证", 401)

    with db_cursor() as cursor:
        cursor.execute(
            """
            SELECT u.*
            FROM user_sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token=%s
              AND (s.expires_at IS NULL OR s.expires_at > NOW())
              AND u.status='active'
            LIMIT 1
            """,
            (token,),
        )
        user = cursor.fetchone()

    if not user:
        return fail("登录已过期，请重新登录", 401)
    return success({"user": public_user(user)})


def build_learning_evaluation(total_answers, accuracy_rate, current_wrong_count, diary_count, average_mood):
    if total_answers == 0:
        return "还没有刷题记录。建议先完成一组基础练习，让系统逐步了解你的学习情况。"

    if accuracy_rate >= 85:
        level_text = "当前知识掌握较扎实"
    elif accuracy_rate >= 65:
        level_text = "当前学习状态较稳定"
    else:
        level_text = "当前仍有较大的巩固空间"

    if current_wrong_count == 0:
        review_text = "目前没有待复习错题，可以适当提高题目难度。"
    elif current_wrong_count <= 5:
        review_text = f"还有 {current_wrong_count} 道错题需要复习，建议近期逐题消化。"
    else:
        review_text = f"当前积累了 {current_wrong_count} 道错题，建议优先进行错题专项训练。"

    if diary_count == 0:
        diary_text = "可以开始记录学习日记，帮助系统持续分析学习节奏。"
    elif average_mood >= 7:
        diary_text = "近期学习情绪良好，适合保持当前节奏。"
    elif average_mood >= 5:
        diary_text = "近期状态整体平稳，注意安排休息和复盘。"
    else:
        diary_text = "近期学习状态偏低，建议降低单次任务量并优先完成关键目标。"

    return f"{level_text}，累计正确率为 {accuracy_rate:.1f}%。{review_text}{diary_text}"


@app.get("/api/profile/overview")
def profile_overview():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    user_id = user["id"]
    with db_cursor() as cursor:
        cursor.execute(
            """
            SELECT
              COUNT(*) AS total_answers,
              COALESCE(SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END), 0) AS correct_answers,
              COALESCE(SUM(CASE WHEN is_correct = 0 THEN 1 ELSE 0 END), 0) AS wrong_answers,
              COALESCE(SUM(used_seconds), 0) AS answer_seconds
            FROM practice_answers
            WHERE user_id=%s
            """,
            (user_id,),
        )
        answer_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT COUNT(*) AS current_wrong_count
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
            (user_id,),
        )
        wrong_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT
              COUNT(*) AS session_count,
              COALESCE(SUM(duration_seconds), 0) AS session_seconds
            FROM practice_sessions
            WHERE user_id=%s AND finished_at IS NOT NULL
            """,
            (user_id,),
        )
        session_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT
              COUNT(*) AS diary_count,
              COALESCE(AVG(mood_score), 0) AS average_mood
            FROM diary_entries
            WHERE user_id=%s
            """,
            (user_id,),
        )
        diary_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT
              COALESCE(SUM(CASE WHEN owner_user_id=%s THEN 1 ELSE 0 END), 0) AS owned_bank_count,
              COUNT(*) AS available_bank_count
            FROM question_banks
            WHERE owner_user_id=%s OR visibility='public'
            """,
            (user_id, user_id),
        )
        bank_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT
              COUNT(*) AS owned_question_count,
              COALESCE(SUM(CASE WHEN q.ai_generated=1 THEN 1 ELSE 0 END), 0) AS ai_generated_question_count
            FROM questions q
            JOIN question_banks qb ON qb.id=q.question_bank_id
            WHERE qb.owner_user_id=%s
            """,
            (user_id,),
        )
        question_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT COUNT(*) AS document_count
            FROM documents
            WHERE owner_user_id=%s
            """,
            (user_id,),
        )
        document_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT COUNT(*) AS ai_conversation_count
            FROM ai_conversations
            WHERE user_id=%s
            """,
            (user_id,),
        )
        conversation_stats = cursor.fetchone()

        cursor.execute(
            """
            SELECT DATE(answered_at) AS stat_date, COUNT(*) AS answer_count
            FROM practice_answers
            WHERE user_id=%s
              AND answered_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
            GROUP BY DATE(answered_at)
            ORDER BY stat_date
            """,
            (user_id,),
        )
        recent_rows = cursor.fetchall()

    total_answers = int(answer_stats.get("total_answers") or 0)
    correct_answers = int(answer_stats.get("correct_answers") or 0)
    wrong_answers = int(answer_stats.get("wrong_answers") or 0)
    current_wrong_count = int(wrong_stats.get("current_wrong_count") or 0)
    session_count = int(session_stats.get("session_count") or 0)
    study_seconds = max(
        int(answer_stats.get("answer_seconds") or 0),
        int(session_stats.get("session_seconds") or 0),
    )
    diary_count = int(diary_stats.get("diary_count") or 0)
    average_mood = round(float(diary_stats.get("average_mood") or 0), 1)
    owned_bank_count = int(bank_stats.get("owned_bank_count") or 0)
    available_bank_count = int(bank_stats.get("available_bank_count") or 0)
    owned_question_count = int(question_stats.get("owned_question_count") or 0)
    ai_generated_question_count = int(question_stats.get("ai_generated_question_count") or 0)
    document_count = int(document_stats.get("document_count") or 0)
    ai_conversation_count = int(conversation_stats.get("ai_conversation_count") or 0)
    accuracy_rate = round(correct_answers * 100 / total_answers, 1) if total_answers else 0.0

    recent_map = {str(row["stat_date"]): int(row.get("answer_count") or 0) for row in recent_rows}
    recent_activity = []
    for offset in range(6, -1, -1):
        stat_date = (datetime.now() - timedelta(days=offset)).date()
        date_text = stat_date.isoformat()
        recent_activity.append(
            {
                "date": date_text,
                "label": f"{stat_date.month}/{stat_date.day}",
                "count": recent_map.get(date_text, 0),
            }
        )

    evaluation = build_learning_evaluation(
        total_answers,
        accuracy_rate,
        current_wrong_count,
        diary_count,
        average_mood,
    )

    return success(
        {
            "totalAnswers": total_answers,
            "correctAnswers": correct_answers,
            "wrongAnswers": wrong_answers,
            "currentWrongCount": current_wrong_count,
            "accuracyRate": accuracy_rate,
            "sessionCount": session_count,
            "studyMinutes": round(study_seconds / 60),
            "diaryCount": diary_count,
            "averageMood": average_mood,
            "ownedBankCount": owned_bank_count,
            "availableBankCount": available_bank_count,
            "ownedQuestionCount": owned_question_count,
            "aiGeneratedQuestionCount": ai_generated_question_count,
            "documentCount": document_count,
            "aiConversationCount": ai_conversation_count,
            "recentActivity": recent_activity,
            "evaluation": evaluation,
        }
    )


@app.get("/api/profile/avatar/<path:filename>")
def profile_avatar(filename):
    return send_from_directory(AVATAR_DIR, filename)


@app.post("/api/profile/update")
def update_profile():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    nickname = (request.form.get("nickname") or "").strip()
    email = (request.form.get("email") or "").strip() or None
    if not nickname:
        return fail("昵称不能为空")
    if len(nickname) > 64:
        return fail("昵称不能超过 64 个字符")
    if email and ("@" not in email or len(email) > 128):
        return fail("邮箱格式不正确")

    avatar_url = user.get("avatar_url") or "ailearning_icon.png"
    avatar_file = request.files.get("avatar") or request.files.get("file")
    if avatar_file and avatar_file.filename:
        suffix = Path(secure_filename(avatar_file.filename)).suffix.lower()
        if suffix not in {".png", ".jpg", ".jpeg", ".webp"}:
            return fail("头像仅支持 PNG、JPG、JPEG 或 WEBP")
        avatar_name = f"user-{user['id']}-{uuid.uuid4().hex}{suffix}"
        avatar_file.save(AVATAR_DIR / avatar_name)
        avatar_url = f"/api/profile/avatar/{avatar_name}"

    try:
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                UPDATE users
                SET nickname=%s, email=%s, avatar_url=%s
                WHERE id=%s
                """,
                (nickname, email, avatar_url, user["id"]),
            )
            cursor.execute("SELECT * FROM users WHERE id=%s", (user["id"],))
            updated_user = cursor.fetchone()
        return success({"user": public_user(updated_user)}, "个人资料更新成功")
    except IntegrityError:
        return fail("该邮箱已被其他账号使用", 409)


@app.post("/api/profile/change-password")
def change_profile_password():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    old_password = str(body.get("old_password") or "")
    new_password = str(body.get("new_password") or "")
    if old_password != user["password"]:
        return fail("原密码不正确", 400)
    if len(new_password) < 6:
        return fail("新密码至少需要 6 个字符", 400)
    if old_password == new_password:
        return fail("新密码不能与原密码相同", 400)

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            "UPDATE users SET password=%s WHERE id=%s",
            (new_password, user["id"]),
        )
    return success(message="密码修改成功")


@app.get("/api/dashboard/summary")
def dashboard_summary():
    return success({
        "featureCards": [
            {"title": "题库刷题", "value": "Excel / AI 生成", "status": "规划中"},
            {"title": "学习日记", "value": "AI 状态分析", "status": "规划中"},
            {"title": "可视化分析", "value": "正确率 / 错题趋势", "status": "规划中"},
            {"title": "AI 辅学", "value": "提问、讲解、出卷", "status": "规划中"},
        ]
    })


@app.get("/api/diary/list")
def list_diary_entries():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    entries = DiaryService().list_entries(user["id"])
    return success(entries)


@app.post("/api/diary/create")
def create_diary_entry():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    entry_date = (body.get("entry_date") or "").strip()
    title = (body.get("title") or "").strip()
    content = (body.get("content") or "").strip()
    tags = body.get("tags") or []

    try:
        mood_score = int(body.get("mood_score"))
    except (TypeError, ValueError):
        return fail("今日学习心情必须是 1-10 的整数")

    if not entry_date:
        return fail("日期不能为空")
    try:
        datetime.strptime(entry_date, "%Y-%m-%d")
    except ValueError:
        return fail("日期格式必须为 YYYY-MM-DD")

    if not title:
        return fail("日记标题不能为空")
    if not content:
        return fail("学习日记内容不能为空")
    if mood_score < 1 or mood_score > 10:
        return fail("今日学习心情必须在 1-10 分之间")
    if not isinstance(tags, list):
        return fail("标签必须是数组")

    normalized_tags = [str(tag).strip() for tag in tags if str(tag).strip()]

    with db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            INSERT INTO diary_entries
              (user_id, entry_date, mood_score, title, content, tags)
            VALUES
              (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              mood_score = VALUES(mood_score),
              title = VALUES(title),
              content = VALUES(content),
              tags = VALUES(tags),
              updated_at = CURRENT_TIMESTAMP
            """,
            (
                user["id"],
                entry_date,
                mood_score,
                title,
                content,
                json.dumps(normalized_tags, ensure_ascii=False),
            ),
        )
        cursor.execute(
            """
            SELECT id, entry_date, mood_score, title, content, tags, created_at
            FROM diary_entries
            WHERE user_id = %s AND entry_date = %s
            LIMIT 1
            """,
            (user["id"], entry_date),
        )
        row = cursor.fetchone()

    return success(to_diary_entry(row), "学习日记保存成功", 201)


@app.put("/api/diary/update/<int:entry_id>")
def update_diary_entry(entry_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    entry_date = (body.get("entry_date") or "").strip()
    title = (body.get("title") or "").strip()
    content = (body.get("content") or "").strip()
    tags = body.get("tags") or []

    try:
        mood_score = int(body.get("mood_score"))
    except (TypeError, ValueError):
        return fail("今日学习心情必须是 1-10 的整数")

    if not entry_date:
        return fail("日期不能为空")
    try:
        datetime.strptime(entry_date, "%Y-%m-%d")
    except ValueError:
        return fail("日期格式必须为 YYYY-MM-DD")

    if not title:
        return fail("日记标题不能为空")
    if not content:
        return fail("学习日记内容不能为空")
    if mood_score < 1 or mood_score > 10:
        return fail("今日学习心情必须在 1-10 分之间")
    if not isinstance(tags, list):
        return fail("标签必须是数组")

    try:
        result = DiaryService().update_entry(
            entry_id, user["id"], entry_date, mood_score, title, content, tags
        )
    except ValueError as exc:
        return fail(str(exc))

    if result is None:
        return fail("日记不存在或无权修改", 404)
    return success(result, "学习日记更新成功")


@app.delete("/api/diary/delete/<int:entry_id>")
def delete_diary_entry(entry_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    deleted = DiaryService().delete_entry(entry_id, user["id"])
    if not deleted:
        return fail("日记不存在或无权删除", 404)
    return success(None, "学习日记已删除")


@app.post("/api/diary/polish")
def polish_diary_content():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    content = (body.get("content") or "").strip()

    if not content:
        return fail("日记内容不能为空")

    try:
        polished = DiaryService().polish_content(content)
    except ValueError as exc:
        return fail(str(exc))
    except RuntimeError as exc:
        return fail(str(exc), 500)
    except Exception as exc:
        return fail(f"AI润色失败：{exc}", 500)

    return success({"result": polished}, "润色完成")


@app.get("/api/ai-learning/conversations")
def ai_learning_conversations():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    limit = optional_int(request.args.get("limit") or 20)
    conversations = AiLearningService().list_conversations(user["id"], max(1, min(limit or 20, 50)))
    return success({"conversations": conversations}, "会话列表获取成功")


@app.get("/api/ai-learning/conversations/<int:conversation_id>/messages")
def ai_learning_conversation_messages(conversation_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    limit = optional_int(request.args.get("limit") or 40)
    messages = AiLearningService().list_messages(user["id"], conversation_id, max(1, min(limit or 40, 100)))
    return success({"messages": messages}, "会话消息获取成功")


@app.get("/api/ai-learning/wrong-questions")
def ai_learning_wrong_questions():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    bank_id = optional_int(request.args.get("bank_id"))
    limit = optional_int(request.args.get("limit") or 30)
    questions = AiLearningService().list_wrong_questions(user["id"], bank_id, max(1, min(limit or 30, 100)))
    return success({"questions": questions}, "错题获取成功")


@app.delete("/api/ai-learning/wrong-questions/<int:question_id>")
def ai_learning_remove_wrong_question(question_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response

    removed = AiLearningService().remove_wrong_question(user["id"], question_id)
    if not removed:
        return fail("错题不存在或已经移出", 404)
    return success(None, "已移出错题本")


@app.post("/api/ai-learning/chat")
def ai_learning_chat():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    scene = (request.form.get("scene") or "qa").strip()
    message = (request.form.get("message") or "").strip()
    conversation_id = optional_int(request.form.get("conversation_id"))
    related_question_id = optional_int(request.form.get("related_question_id"))

    attachment_path = None
    attachment_name = None
    attachment_type = None
    upload_file = request.files.get("file")
    if upload_file and upload_file.filename:
        attachment_name = upload_file.filename
        suffix = Path(secure_filename(upload_file.filename)).suffix or ".bin"
        temp_name = f"ai-learning-{uuid.uuid4().hex}{suffix}"
        attachment_path = str(Path(tempfile.gettempdir()) / temp_name)
        upload_file.save(attachment_path)
        attachment_type = (request.form.get("attachment_type") or "").strip() or suffix.lstrip(".")

    try:
        result = AiLearningService().chat(
            user_id=user["id"],
            message=message,
            scene=scene,
            conversation_id=conversation_id,
            related_question_id=related_question_id,
            attachment_path=attachment_path,
            attachment_name=attachment_name,
            attachment_type=attachment_type,
        )
        return success(result, "AI 回复成功")
    except ValueError as exc:
        return fail(str(exc), 400)
    except AiProviderBusyError as exc:
        return fail(str(exc), 429)
    except RuntimeError as exc:
        return fail(str(exc), 500)
    except Exception as exc:
        app.logger.exception("ai learning chat failed")
        return fail(f"AI 回复失败: {exc}", 500)


@app.post("/api/ai-learning/explain-question")
def ai_learning_explain_question():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    question_id = optional_int(body.get("question_id"))
    if not question_id:
        return fail("question_id 不能为空")

    try:
        result = AiLearningService().explain_wrong_question(user["id"], question_id)
        return success(result, "错题讲解成功")
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        if isinstance(exc, AiProviderBusyError):
            return fail(str(exc), 429)
        app.logger.exception("ai learning explain question failed")
        return fail(f"错题讲解失败: {exc}", 500)


@app.post("/api/ai-learning/diary-plan")
def ai_learning_diary_plan():
    user, error_response = require_current_user()
    if error_response:
        return error_response

    body = request.get_json(silent=True) or {}
    days = optional_int(body.get("days") or 3) or 3

    try:
        result = AiLearningService().build_study_plan(user["id"], max(1, min(days, 14)))
        return success(result, "学习建议生成成功")
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        if isinstance(exc, AiProviderBusyError):
            return fail(str(exc), 429)
        app.logger.exception("ai learning diary plan failed")
        return fail(f"学习建议生成失败: {exc}", 500)


@app.post("/api/ai/generate-questions")
def generate_questions_from_document_text():
    body = request.get_json(silent=True) or {}
    document_text = (body.get("document_text") or "").strip()
    subject = (body.get("subject") or "").strip()
    question_count = body.get("question_count") or 5
    question_types = body.get("question_types") or None
    difficulty = body.get("difficulty")
    extra_prompt = (body.get("extra_prompt") or "").strip()
    save_to_db = bool(body.get("save_to_db", False))
    owner_user_id = body.get("owner_user_id")
    question_bank_id = body.get("question_bank_id")

    if len(document_text) < 20:
        return fail("document_text 内容过短，无法生成题目")
    if question_types is not None and not isinstance(question_types, list):
        return fail("question_types 必须是数组，例如 ['single_choice', 'blank']")

    try:
        service = ZhipuQuestionService()
        result = service.generate_questions(
            document_text=document_text,
            subject=subject,
            question_count=int(question_count),
            question_types=question_types,
            difficulty=difficulty,
            extra_prompt=extra_prompt,
        )
        if save_to_db:
            save_result = QuestionPersistenceService().save_generated_questions(
                generated=result,
                owner_user_id=optional_int(owner_user_id),
                question_bank_id=optional_int(question_bank_id),
            )
            result["saved"] = save_result
        return success(result, "AI 出题成功")
    except ValueError as exc:
        return fail(str(exc), 400)
    except RuntimeError as exc:
        return fail(str(exc), 500)
    except Exception as exc:
        return fail(f"AI 出题失败: {exc}", 500)


@app.post("/api/questions/save-generated")
def save_generated_questions():
    body = request.get_json(silent=True) or {}
    generated = body.get("generated") or {}
    owner_user_id = body.get("owner_user_id")
    question_bank_id = body.get("question_bank_id")

    if not isinstance(generated, dict):
        return fail("generated 必须是 AI 出题接口返回的数据对象")

    try:
        save_result = QuestionPersistenceService().save_generated_questions(
            generated=generated,
            owner_user_id=optional_int(owner_user_id),
            question_bank_id=optional_int(question_bank_id),
        )
        return success(save_result, "题目保存成功")
    except ValueError as exc:
        return fail(str(exc), 400)
    except Exception as exc:
        return fail(f"题目保存失败: {exc}", 500)


@app.post("/api/documents/generate-questions-from-file")
def generate_questions_from_uploaded_file():
    uploaded_file = request.files.get("file")
    if uploaded_file is None or uploaded_file.filename == "":
        return fail("请上传课程文档文件")

    subject = (request.form.get("subject") or "").strip()
    question_count = request.form.get("question_count") or 5
    difficulty = request.form.get("difficulty")
    extra_prompt = (request.form.get("extra_prompt") or "").strip()
    save_to_db = (request.form.get("save_to_db") or "true").lower() == "true"
    owner_user_id = request.form.get("owner_user_id")
    question_bank_id = request.form.get("question_bank_id")
    raw_question_types = request.form.get("question_types") or ""
    question_types = [item.strip() for item in raw_question_types.split(",") if item.strip()]

    original_name = uploaded_file.filename
    safe_name = secure_filename(original_name)
    if not safe_name:
        safe_name = f"upload-{uuid.uuid4().hex}"
    saved_path = UPLOAD_DIR / f"{uuid.uuid4().hex}-{safe_name}"
    uploaded_file.save(saved_path)

    try:
        document_text = DocumentTextExtractor().extract(saved_path, original_name)
        if len(document_text.strip()) < 20:
            return fail("文档解析出的文本过短，无法生成题目")

        service = ZhipuQuestionService()
        result = service.generate_questions(
            document_text=document_text[:20000],
            subject=subject,
            question_count=int(question_count),
            question_types=question_types,
            difficulty=difficulty,
            extra_prompt=extra_prompt,
        )

        if save_to_db:
            save_result = QuestionPersistenceService().save_generated_questions(
                generated=result,
                owner_user_id=optional_int(owner_user_id),
                question_bank_id=optional_int(question_bank_id),
            )
            result["saved"] = save_result

        result["document"] = {
            "file_name": original_name,
            "text_length": len(document_text),
            "used_text_length": min(len(document_text), 20000),
        }
        return success(result, "文档解析、AI 出题并保存成功" if save_to_db else "文档解析和 AI 出题成功")
    except ValueError as exc:
        return fail(str(exc), 200)
    except RuntimeError as exc:
        return fail(str(exc), 200)
    except Exception as exc:
        app.logger.exception("generate questions from uploaded file failed")
        return fail(f"文档出题失败: {exc}", 200)


if __name__ == "__main__":
    host = os.getenv("FLASK_HOST", "0.0.0.0")
    port = int(os.getenv("FLASK_PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "true").lower() == "true"
    app.run(host=host, port=port, debug=debug)
