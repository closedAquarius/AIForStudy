import hashlib
import os
import secrets
import smtplib
from datetime import datetime, timedelta
from email.message import EmailMessage
from pathlib import Path

from dotenv import load_dotenv

from db import db_cursor

BACKEND_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)


class PasswordResetService:
    CODE_TTL_MINUTES = 10
    SEND_INTERVAL_SECONDS = 60

    def __init__(self):
        self.smtp_host = os.getenv("SMTP_HOST", "smtp.qq.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "465"))
        self.smtp_user = os.getenv("SMTP_USER", "")
        self.smtp_auth_code = os.getenv("SMTP_AUTH_CODE", "")
        self.smtp_sender_name = os.getenv("SMTP_SENDER_NAME", "AI For Study")

    def send_code(self, email: str) -> None:
        normalized_email = email.strip().lower()
        if not normalized_email or "@" not in normalized_email:
            raise ValueError("请输入正确的邮箱地址")
        if not self.smtp_user or not self.smtp_auth_code:
            raise RuntimeError("邮件服务尚未配置")

        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT id, nickname
                FROM users
                WHERE LOWER(email)=%s AND status='active'
                LIMIT 1
                """,
                (normalized_email,),
            )
            user = cursor.fetchone()
            if not user:
                raise ValueError("该邮箱尚未绑定账号")

            cursor.execute(
                """
                SELECT created_at
                FROM password_reset_codes
                WHERE user_id=%s
                ORDER BY id DESC
                LIMIT 1
                """,
                (user["id"],),
            )
            latest = cursor.fetchone()

        if latest and latest.get("created_at"):
            elapsed = (datetime.now() - latest["created_at"]).total_seconds()
            if elapsed < self.SEND_INTERVAL_SECONDS:
                remaining = int(self.SEND_INTERVAL_SECONDS - elapsed) + 1
                raise ValueError(f"请在 {remaining} 秒后重新获取验证码")

        code = f"{secrets.randbelow(1_000_000):06d}"
        expires_at = datetime.now() + timedelta(minutes=self.CODE_TTL_MINUTES)
        self._send_email(normalized_email, user.get("nickname") or "同学", code)

        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                UPDATE password_reset_codes
                SET consumed_at=NOW()
                WHERE user_id=%s AND consumed_at IS NULL
                """,
                (user["id"],),
            )
            cursor.execute(
                """
                INSERT INTO password_reset_codes
                  (user_id, email, code_hash, expires_at)
                VALUES (%s, %s, %s, %s)
                """,
                (user["id"], normalized_email, self._hash_code(code), expires_at),
            )

    def reset_password(self, email: str, code: str, new_password: str) -> None:
        normalized_email = email.strip().lower()
        normalized_code = code.strip()
        if len(normalized_code) != 6 or not normalized_code.isdigit():
            raise ValueError("请输入 6 位数字验证码")
        if len(new_password) < 6:
            raise ValueError("新密码至少需要 6 个字符")

        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                SELECT prc.id, prc.user_id, prc.code_hash
                FROM password_reset_codes prc
                JOIN users u ON u.id=prc.user_id
                WHERE LOWER(prc.email)=%s
                  AND u.status='active'
                  AND prc.consumed_at IS NULL
                  AND prc.expires_at > NOW()
                ORDER BY prc.id DESC
                LIMIT 1
                """,
                (normalized_email,),
            )
            reset_code = cursor.fetchone()
            if not reset_code or not secrets.compare_digest(
                reset_code["code_hash"],
                self._hash_code(normalized_code),
            ):
                raise ValueError("验证码不正确或已过期")

            cursor.execute(
                "UPDATE users SET password=%s WHERE id=%s",
                (new_password, reset_code["user_id"]),
            )
            cursor.execute(
                "UPDATE password_reset_codes SET consumed_at=NOW() WHERE id=%s",
                (reset_code["id"],),
            )
            cursor.execute(
                "DELETE FROM user_sessions WHERE user_id=%s",
                (reset_code["user_id"],),
            )

    def _send_email(self, recipient: str, nickname: str, code: str) -> None:
        message = EmailMessage()
        message["Subject"] = "AI For Study 密码重置验证码"
        message["From"] = f"{self.smtp_sender_name} <{self.smtp_user}>"
        message["To"] = recipient
        message.set_content(
            f"{nickname}，你好：\n\n"
            f"你的密码重置验证码是：{code}\n\n"
            f"验证码将在 {self.CODE_TTL_MINUTES} 分钟后失效，请勿转发给他人。\n"
            "如果不是你本人操作，请忽略这封邮件。\n\n"
            "AI For Study"
        )

        with smtplib.SMTP_SSL(self.smtp_host, self.smtp_port, timeout=20) as client:
            client.login(self.smtp_user, self.smtp_auth_code)
            client.send_message(message)

    @staticmethod
    def _hash_code(code: str) -> str:
        return hashlib.sha256(code.encode("utf-8")).hexdigest()
