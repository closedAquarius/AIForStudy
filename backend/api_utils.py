from flask import jsonify, request

from db import db_cursor


def success(data=None, message="ok", status=200):
    payload = {"success": True, "message": message}
    if data is not None:
        payload["data"] = data
    return jsonify(payload), status


def fail(message, status=400):
    return jsonify({"success": False, "message": message}), status


def public_user(row):
    avatar_url = row.get("avatar_url") or "ailearning_icon.png"
    if avatar_url.startswith("/api/"):
        avatar_url = request.host_url.rstrip("/") + avatar_url
    return {
        "id": row["id"],
        "username": row["username"],
        "nickname": row["nickname"],
        "email": row.get("email"),
        "avatarUrl": avatar_url,
        "role": row["role"],
    }


def get_current_user():
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "", 1).strip()
    if not token:
        return None

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
        return cursor.fetchone()


def require_current_user():
    user = get_current_user()
    if not user:
        return None, fail("登录已过期，请重新登录", 401)
    return user, None
