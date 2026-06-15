from flask import Blueprint, request

from api_utils import fail, require_current_user, success
from services.ai_learning_service import AiProviderBusyError
from services.knowledge_base_service import KnowledgeBaseService


knowledge_base_bp = Blueprint("knowledge_base_api", __name__)


@knowledge_base_bp.get("/knowledge-bases")
def list_knowledge_bases():
    user, error_response = require_current_user()
    if error_response:
        return error_response
    return success({"knowledgeBases": KnowledgeBaseService().list_bases(user["id"])})


@knowledge_base_bp.post("/knowledge-bases")
def create_knowledge_base():
    user, error_response = require_current_user()
    if error_response:
        return error_response
    body = request.get_json(silent=True) or {}
    name = str(body.get("name") or "").strip()
    description = str(body.get("description") or "").strip()
    if not name:
        return fail("知识库名称不能为空")
    if len(name) > 120 or len(description) > 500:
        return fail("知识库名称或描述过长")
    result = KnowledgeBaseService().create_base(user["id"], name, description)
    return success(result, "知识库创建成功", 201)


@knowledge_base_bp.delete("/knowledge-bases/<int:base_id>")
def delete_knowledge_base(base_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    if not KnowledgeBaseService().delete_base(user["id"], base_id):
        return fail("知识库不存在或无权删除", 404)
    return success(None, "知识库已删除")


@knowledge_base_bp.get("/knowledge-bases/<int:base_id>/documents")
def list_knowledge_documents(base_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        documents = KnowledgeBaseService().list_documents(user["id"], base_id)
        return success({"documents": documents})
    except LookupError as exc:
        return fail(str(exc), 404)


@knowledge_base_bp.post("/knowledge-bases/<int:base_id>/documents")
def upload_knowledge_document(base_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    uploaded_file = request.files.get("file")
    if uploaded_file is None or not uploaded_file.filename:
        return fail("请选择要上传的文档")
    try:
        document = KnowledgeBaseService().add_document(user["id"], base_id, uploaded_file)
        return success(document, "文档已解析并加入知识库", 201)
    except LookupError as exc:
        return fail(str(exc), 404)
    except (ValueError, RuntimeError) as exc:
        return fail(str(exc))
    except Exception as exc:
        return fail(f"文档处理失败：{exc}", 500)


@knowledge_base_bp.delete("/knowledge-bases/<int:base_id>/documents/<int:document_id>")
def remove_knowledge_document(base_id, document_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        removed = KnowledgeBaseService().remove_document(user["id"], base_id, document_id)
        if not removed:
            return fail("文档不存在或无权删除", 404)
        return success(None, "文档已移出知识库")
    except LookupError as exc:
        return fail(str(exc), 404)


@knowledge_base_bp.post("/knowledge-bases/<int:base_id>/ask")
def ask_knowledge_base(base_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    body = request.get_json(silent=True) or {}
    question = str(body.get("question") or "").strip()
    if not question:
        return fail("问题不能为空")
    if len(question) > 2000:
        return fail("问题不能超过 2000 个字符")
    try:
        result = KnowledgeBaseService().ask(user["id"], base_id, question)
        return success(result, "回答生成成功")
    except LookupError as exc:
        return fail(str(exc), 404)
    except ValueError as exc:
        return fail(str(exc))
    except AiProviderBusyError as exc:
        return fail(str(exc), 429)
    except Exception as exc:
        return fail(f"知识库问答失败：{exc}", 500)


@knowledge_base_bp.get("/knowledge-bases/<int:base_id>/queries")
def list_knowledge_queries(base_id):
    user, error_response = require_current_user()
    if error_response:
        return error_response
    try:
        limit = min(100, max(1, int(request.args.get("limit", "30"))))
        queries = KnowledgeBaseService().list_queries(user["id"], base_id, limit)
        return success({"queries": queries})
    except ValueError:
        return fail("limit 参数错误")
    except LookupError as exc:
        return fail(str(exc), 404)
