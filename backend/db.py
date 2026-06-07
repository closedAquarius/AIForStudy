import os
from contextlib import contextmanager
from pathlib import Path

import pymysql
from dotenv import load_dotenv

load_dotenv(Path(__file__).with_name(".env"))
load_dotenv(Path(__file__).with_name(".env.example"), override=False)


def get_db_config():
    return {
        "host": os.getenv("DB_HOST", "127.0.0.1"),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root"),
        "password": os.getenv("DB_PASSWORD", "123"),
        "database": os.getenv("DB_NAME", "ai_for_study"),
        "charset": "utf8mb4",
        "cursorclass": pymysql.cursors.DictCursor,
        "autocommit": False,
    }


def get_connection():
    return pymysql.connect(**get_db_config())


@contextmanager
def db_cursor(commit=False):
    connection = get_connection()
    try:
        with connection.cursor() as cursor:
            yield cursor
        if commit:
            connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
