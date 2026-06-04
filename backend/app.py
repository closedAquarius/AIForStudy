import os
import uuid
from datetime import datetime, timedelta

from flask import Flask, request
from pymysql.err import IntegrityError

from api_utils import success, fail, public_user
from question_bank_api import question_bank_bp

from db import db_cursor


app = Flask(__name__)
app.register_blueprint(question_bank_bp, url_prefix="/api")


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/<path:_path>", methods=["OPTIONS"])
def cors_preflight(_path):
    return "", 204


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


if __name__ == "__main__":
    host = os.getenv("FLASK_HOST", "0.0.0.0")
    port = int(os.getenv("FLASK_PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "true").lower() == "true"
    app.run(host=host, port=port, debug=debug)
