import os
import uuid
from datetime import datetime, timedelta
from pathlib import Path

from flask import Flask, jsonify, request
from pymysql.err import IntegrityError
from werkzeug.utils import secure_filename

from db import db_cursor
from services.document_text_extractor import DocumentTextExtractor
from services.question_persistence_service import QuestionPersistenceService
from services.zhipu_question_service import ZhipuQuestionService


app = Flask(__name__)

UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/<path:_path>", methods=["OPTIONS"])
def cors_preflight(_path):
    return "", 204


def success(data=None, message="ok", status=200):
    payload = {"success": True, "message": message}
    if data is not None:
        payload["data"] = data
    return jsonify(payload), status


def fail(message, status=400):
    return jsonify({"success": False, "message": message}), status


def public_user(row):
    return {
        "id": row["id"],
        "username": row["username"],
        "nickname": row["nickname"],
        "email": row.get("email"),
        "role": row["role"],
    }


def optional_int(value):
    if value is None or value == "":
        return None
    return int(value)


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
                INSERT INTO users (username, password, nickname, email)
                VALUES (%s, %s, %s, %s)
                """,
                (username, password, nickname, email),
            )
            user_id = cursor.lastrowid
            cursor.execute("SELECT * FROM users WHERE id=%s", (user_id,))
            user = cursor.fetchone()
        return success({"user": public_user(user)}, "注册成功", 201)
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
