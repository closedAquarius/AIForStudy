import json
import re
import uuid
from pathlib import Path

from db import db_cursor
from services.ai_learning_service import AiLearningService
from services.document_text_extractor import DocumentTextExtractor


BACKEND_DIR = Path(__file__).resolve().parents[1]
KNOWLEDGE_UPLOAD_DIR = BACKEND_DIR / "uploads" / "knowledge"
ALLOWED_FILE_TYPES = {"pptx", "docx", "pdf", "txt"}


class KnowledgeBaseService:
    def __init__(self):
        self.upload_dir = KNOWLEDGE_UPLOAD_DIR
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    def list_bases(self, user_id):
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  kb.id, kb.name, kb.description, kb.created_at, kb.updated_at,
                  COUNT(DISTINCT kbd.document_id) AS document_count,
                  COUNT(DISTINCT dc.id) AS chunk_count
                FROM knowledge_bases kb
                LEFT JOIN knowledge_base_documents kbd
                  ON kbd.knowledge_base_id=kb.id
                LEFT JOIN document_chunks dc
                  ON dc.document_id=kbd.document_id
                WHERE kb.owner_user_id=%s
                GROUP BY kb.id, kb.name, kb.description, kb.created_at, kb.updated_at
                ORDER BY kb.updated_at DESC, kb.id DESC
                """,
                (user_id,),
            )
            rows = cursor.fetchall()
        return [self._base_payload(row) for row in rows]

    def create_base(self, user_id, name, description):
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO knowledge_bases (owner_user_id, name, description)
                VALUES (%s, %s, %s)
                """,
                (user_id, name, description or None),
            )
            base_id = cursor.lastrowid
            cursor.execute(
                """
                SELECT id, name, description, created_at, updated_at
                FROM knowledge_bases
                WHERE id=%s
                """,
                (base_id,),
            )
            row = cursor.fetchone()
        row["document_count"] = 0
        row["chunk_count"] = 0
        return self._base_payload(row)

    def delete_base(self, user_id, base_id):
        orphan_documents = []
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                SELECT d.id, d.storage_path
                FROM knowledge_base_documents kbd
                JOIN documents d ON d.id=kbd.document_id
                WHERE kbd.knowledge_base_id=%s AND d.owner_user_id=%s
                """,
                (base_id, user_id),
            )
            linked_documents = cursor.fetchall()
            cursor.execute(
                "DELETE FROM knowledge_bases WHERE id=%s AND owner_user_id=%s",
                (base_id, user_id),
            )
            if cursor.rowcount == 0:
                return False
            for document in linked_documents:
                cursor.execute(
                    "SELECT COUNT(*) AS total FROM knowledge_base_documents WHERE document_id=%s",
                    (document["id"],),
                )
                if int(cursor.fetchone()["total"]) == 0:
                    cursor.execute(
                        "DELETE FROM documents WHERE id=%s AND owner_user_id=%s",
                        (document["id"], user_id),
                    )
                    orphan_documents.append(document)
        for document in orphan_documents:
            self._safe_unlink(Path(document["storage_path"]))
        return True

    def list_documents(self, user_id, base_id):
        self._require_base(user_id, base_id)
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  d.id, d.title, d.file_name, d.file_type, d.parse_status,
                  d.ai_summary, d.created_at, COUNT(dc.id) AS chunk_count
                FROM knowledge_base_documents kbd
                JOIN documents d ON d.id=kbd.document_id
                LEFT JOIN document_chunks dc ON dc.document_id=d.id
                WHERE kbd.knowledge_base_id=%s
                GROUP BY
                  d.id, d.title, d.file_name, d.file_type,
                  d.parse_status, d.ai_summary, d.created_at
                ORDER BY kbd.created_at DESC
                """,
                (base_id,),
            )
            rows = cursor.fetchall()
        return [self._document_payload(row) for row in rows]

    def add_document(self, user_id, base_id, uploaded_file):
        self._require_base(user_id, base_id)
        original_name = Path(uploaded_file.filename or "").name
        suffix = Path(original_name).suffix.lower().lstrip(".")
        if suffix not in ALLOWED_FILE_TYPES:
            raise ValueError("仅支持 PPTX、DOCX、PDF、TXT 文件")

        storage_name = f"{uuid.uuid4().hex}.{suffix}"
        saved_path = self.upload_dir / storage_name
        uploaded_file.save(saved_path)

        try:
            units = DocumentTextExtractor().extract_units(saved_path, original_name)
            extracted_text = "\n".join(unit["text"] for unit in units).strip()
            if len(extracted_text) < 20:
                raise ValueError("文档解析出的文本过短，无法加入知识库")
            chunks = self.split_units(units)
            summary = extracted_text[:300]
            metadata = json.dumps(
                {"knowledge_base_id": base_id, "chunk_count": len(chunks)},
                ensure_ascii=False,
            )
            with db_cursor(commit=True) as cursor:
                cursor.execute(
                    """
                    INSERT INTO documents
                      (owner_user_id, subject_id, title, file_name, file_type,
                       storage_path, parse_status, extracted_text, ai_summary, metadata)
                    VALUES
                      (%s, NULL, %s, %s, %s, %s, 'parsed', %s, %s, %s)
                    """,
                    (
                        user_id,
                        Path(original_name).stem[:180],
                        original_name,
                        suffix,
                        str(saved_path),
                        extracted_text,
                        summary,
                        metadata,
                    ),
                )
                document_id = cursor.lastrowid
                cursor.execute(
                    """
                    INSERT INTO knowledge_base_documents (knowledge_base_id, document_id)
                    VALUES (%s, %s)
                    """,
                    (base_id, document_id),
                )
                cursor.executemany(
                    """
                    INSERT INTO document_chunks
                      (document_id, chunk_index, content, char_start, char_end, metadata)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            document_id,
                            chunk["index"],
                            chunk["content"],
                            chunk["start"],
                            chunk["end"],
                            json.dumps({
                                "source": f"片段 {chunk['index'] + 1}",
                                "page_number": chunk["page_number"],
                                "page_label": chunk["page_label"],
                                "unit_type": chunk["unit_type"],
                            }, ensure_ascii=False),
                        )
                        for chunk in chunks
                    ],
                )
                cursor.execute(
                    """
                    SELECT
                      d.id, d.title, d.file_name, d.file_type, d.parse_status,
                      d.ai_summary, d.created_at, COUNT(dc.id) AS chunk_count
                    FROM documents d
                    LEFT JOIN document_chunks dc ON dc.document_id=d.id
                    WHERE d.id=%s
                    GROUP BY
                      d.id, d.title, d.file_name, d.file_type,
                      d.parse_status, d.ai_summary, d.created_at
                    """,
                    (document_id,),
                )
                row = cursor.fetchone()
                cursor.execute(
                    "UPDATE knowledge_bases SET updated_at=CURRENT_TIMESTAMP WHERE id=%s",
                    (base_id,),
                )
            return self._document_payload(row)
        except Exception:
            self._safe_unlink(saved_path)
            raise

    def remove_document(self, user_id, base_id, document_id):
        self._require_base(user_id, base_id)
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                SELECT d.storage_path
                FROM knowledge_base_documents kbd
                JOIN documents d ON d.id=kbd.document_id
                WHERE kbd.knowledge_base_id=%s
                  AND kbd.document_id=%s
                  AND d.owner_user_id=%s
                LIMIT 1
                """,
                (base_id, document_id, user_id),
            )
            row = cursor.fetchone()
            if not row:
                return False
            cursor.execute(
                """
                DELETE FROM knowledge_base_documents
                WHERE knowledge_base_id=%s AND document_id=%s
                """,
                (base_id, document_id),
            )
            cursor.execute(
                "SELECT COUNT(*) AS total FROM knowledge_base_documents WHERE document_id=%s",
                (document_id,),
            )
            if int(cursor.fetchone()["total"]) == 0:
                cursor.execute(
                    "DELETE FROM documents WHERE id=%s AND owner_user_id=%s",
                    (document_id, user_id),
                )
                self._safe_unlink(Path(row["storage_path"]))
            cursor.execute(
                "UPDATE knowledge_bases SET updated_at=CURRENT_TIMESTAMP WHERE id=%s",
                (base_id,),
            )
        return True

    def ask(self, user_id, base_id, question):
        base = self._require_base(user_id, base_id)
        sources = self.retrieve(base_id, question, limit=5)
        if not sources:
            raise ValueError("知识库中还没有可检索的文档")

        context_lines = []
        for index, source in enumerate(sources, start=1):
            context_lines.append(
                f"[来源{index}：{source['fileName']} / {source['pageLabel']}]\n"
                f"{source['content']}"
            )
        messages = [
            {
                "role": "system",
                "content": (
                    "你是一名严谨的课程知识库助教。只能依据提供的资料回答。"
                    "资料不足时明确说明，不要编造。回答应清晰、有条理，"
                    "并在相关结论后使用 [来源1]、[来源2] 的形式标注依据。"
                    "使用纯文本回答，不要输出 Markdown 标记。"
                ),
            },
            {
                "role": "user",
                "content": (
                    f"知识库：{base['name']}\n"
                    f"问题：{question}\n\n"
                    "参考资料：\n"
                    + "\n\n".join(context_lines)
                ),
            },
        ]
        answer = AiLearningService().generate_answer(messages)
        public_sources = [
            {
                "documentId": source["documentId"],
                "fileName": source["fileName"],
                "chunkIndex": source["chunkIndex"],
                "pageLabel": source["pageLabel"],
                "content": source["content"],
                "score": round(source["score"], 2),
            }
            for source in sources
        ]
        with db_cursor(commit=True) as cursor:
            cursor.execute(
                """
                INSERT INTO knowledge_queries
                  (knowledge_base_id, user_id, question, answer, sources)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    base_id,
                    user_id,
                    question,
                    answer,
                    json.dumps(public_sources, ensure_ascii=False),
                ),
            )
            query_id = cursor.lastrowid
            cursor.execute(
                "UPDATE knowledge_bases SET updated_at=CURRENT_TIMESTAMP WHERE id=%s",
                (base_id,),
            )
        return {
            "queryId": query_id,
            "answer": answer,
            "sources": public_sources,
        }

    def list_queries(self, user_id, base_id, limit=30):
        self._require_base(user_id, base_id)
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT id, question, answer, sources, created_at
                FROM knowledge_queries
                WHERE knowledge_base_id=%s AND user_id=%s
                ORDER BY created_at DESC, id DESC
                LIMIT %s
                """,
                (base_id, user_id, limit),
            )
            rows = cursor.fetchall()
        result = []
        for row in reversed(rows):
            sources = row.get("sources")
            if isinstance(sources, str):
                try:
                    sources = json.loads(sources)
                except json.JSONDecodeError:
                    sources = []
            normalized_sources = []
            if isinstance(sources, list):
                for source in sources:
                    if not isinstance(source, dict):
                        continue
                    normalized_source = dict(source)
                    if not normalized_source.get("pageLabel"):
                        chunk_index = int(normalized_source.get("chunkIndex") or 0)
                        normalized_source["pageLabel"] = f"片段 {chunk_index + 1}"
                    normalized_sources.append(normalized_source)
            result.append({
                "id": row["id"],
                "question": row.get("question") or "",
                "answer": row.get("answer") or "",
                "sources": normalized_sources,
                "createdAt": str(row.get("created_at") or ""),
            })
        return result

    def retrieve(self, base_id, question, limit=5):
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT
                  dc.id, dc.document_id, dc.chunk_index, dc.content, dc.metadata,
                  d.file_name
                FROM knowledge_base_documents kbd
                JOIN documents d ON d.id=kbd.document_id
                JOIN document_chunks dc ON dc.document_id=d.id
                WHERE kbd.knowledge_base_id=%s
                  AND d.parse_status='parsed'
                ORDER BY dc.document_id, dc.chunk_index
                LIMIT 3000
                """,
                (base_id,),
            )
            rows = cursor.fetchall()

        terms = self.search_terms(question)
        ranked = []
        for row in rows:
            content_lower = (row.get("content") or "").lower()
            score = 0.0
            for term in terms:
                count = content_lower.count(term)
                if count:
                    score += count * (2.0 if len(term) >= 4 else 1.0)
            if question.strip().lower() in content_lower:
                score += 8.0
            if score > 0:
                ranked.append((score, row))

        if not ranked:
            ranked = [(0.1, row) for row in rows[:limit]]
        ranked.sort(key=lambda item: (-item[0], item[1]["chunk_index"]))
        return [
            {
                "documentId": row["document_id"],
                "fileName": row.get("file_name") or "",
                "chunkIndex": int(row.get("chunk_index") or 0),
                "pageLabel": self._chunk_page_label(row),
                "content": row.get("content") or "",
                "score": score,
            }
            for score, row in ranked[:limit]
        ]

    @classmethod
    def split_units(cls, units):
        chunks = []
        char_offset = 0
        for unit in units:
            unit_chunks = cls.split_text(unit.get("text") or "")
            for chunk in unit_chunks:
                chunks.append({
                    "index": len(chunks),
                    "content": chunk["content"],
                    "start": char_offset + chunk["start"],
                    "end": char_offset + chunk["end"],
                    "page_number": int(unit.get("page_number") or 0),
                    "page_label": unit.get("page_label") or f"片段 {len(chunks) + 1}",
                    "unit_type": unit.get("unit_type") or "section",
                })
            char_offset += len(unit.get("text") or "") + 1
        return chunks

    @staticmethod
    def split_text(text, target_size=900, overlap=120):
        normalized = re.sub(r"\r\n?", "\n", text)
        paragraphs = [part.strip() for part in re.split(r"\n{1,}", normalized) if part.strip()]
        chunks = []
        current = ""
        start = 0
        cursor = 0

        for paragraph in paragraphs:
            paragraph_start = normalized.find(paragraph, cursor)
            if paragraph_start < 0:
                paragraph_start = cursor
            cursor = paragraph_start + len(paragraph)
            candidate = f"{current}\n{paragraph}".strip() if current else paragraph
            if current and len(candidate) > target_size:
                chunks.append({
                    "index": len(chunks),
                    "content": current,
                    "start": start,
                    "end": start + len(current),
                })
                tail = current[-overlap:] if overlap > 0 else ""
                current = f"{tail}\n{paragraph}".strip()
                start = max(0, paragraph_start - len(tail))
            else:
                if not current:
                    start = paragraph_start
                current = candidate

        if current:
            chunks.append({
                "index": len(chunks),
                "content": current,
                "start": start,
                "end": start + len(current),
            })
        return chunks

    @staticmethod
    def search_terms(question):
        lower = question.strip().lower()
        terms = set(re.findall(r"[a-z0-9_]{2,}|[\u4e00-\u9fff]{2,}", lower))
        for sequence in re.findall(r"[\u4e00-\u9fff]{3,}", lower):
            for index in range(len(sequence) - 1):
                terms.add(sequence[index:index + 2])
        return sorted(terms, key=len, reverse=True)

    @staticmethod
    def _chunk_page_label(row):
        metadata = row.get("metadata")
        if isinstance(metadata, str):
            try:
                metadata = json.loads(metadata)
            except json.JSONDecodeError:
                metadata = {}
        if isinstance(metadata, dict) and metadata.get("page_label"):
            return str(metadata["page_label"])
        return f"片段 {int(row.get('chunk_index') or 0) + 1}"

    def _require_base(self, user_id, base_id):
        with db_cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, description
                FROM knowledge_bases
                WHERE id=%s AND owner_user_id=%s
                LIMIT 1
                """,
                (base_id, user_id),
            )
            row = cursor.fetchone()
        if not row:
            raise LookupError("知识库不存在或无权访问")
        return row

    @staticmethod
    def _base_payload(row):
        return {
            "id": row["id"],
            "name": row.get("name") or "",
            "description": row.get("description") or "",
            "documentCount": int(row.get("document_count") or 0),
            "chunkCount": int(row.get("chunk_count") or 0),
            "createdAt": str(row.get("created_at") or ""),
            "updatedAt": str(row.get("updated_at") or ""),
        }

    @staticmethod
    def _document_payload(row):
        return {
            "id": row["id"],
            "title": row.get("title") or "",
            "fileName": row.get("file_name") or "",
            "fileType": row.get("file_type") or "",
            "parseStatus": row.get("parse_status") or "",
            "summary": row.get("ai_summary") or "",
            "chunkCount": int(row.get("chunk_count") or 0),
            "createdAt": str(row.get("created_at") or ""),
        }

    @staticmethod
    def _safe_unlink(path):
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass
