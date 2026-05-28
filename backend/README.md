# AIForStudy Backend

Flask 后端模板，已包含 MySQL 连接、健康检查、注册、登录和当前用户接口。

## 初始化数据库

```bash
mysql -u root -p < ../database/schema.sql
```

## 启动后端

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python app.py
```

默认接口地址是 `http://127.0.0.1:5000/api`。如果真机调试，前端里的 `API_BASE_URL` 需要改成电脑在局域网中的 IP。
