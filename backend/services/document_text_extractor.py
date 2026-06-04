import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


class DocumentTextExtractor:
    """Extract plain text from uploaded study documents."""

    def extract(self, file_path: str | Path, original_name: str = "") -> str:
        path = Path(file_path)
        suffix = (Path(original_name).suffix or path.suffix).lower()

        if suffix == ".pptx":
            return self._extract_pptx(path)
        if suffix == ".docx":
            return self._extract_docx(path)
        if suffix == ".txt":
            return self._extract_txt(path)
        if suffix == ".pdf":
            return self._extract_pdf(path)
        if suffix in {".ppt", ".doc"}:
            raise ValueError("暂不支持旧版 .ppt/.doc，请先另存为 .pptx/.docx")
        raise ValueError(f"不支持的文件类型: {suffix or original_name}")

    def _extract_pptx(self, path: Path) -> str:
        texts: list[str] = []
        with zipfile.ZipFile(path) as archive:
            slide_names = sorted(
                name for name in archive.namelist()
                if name.startswith("ppt/slides/slide") and name.endswith(".xml")
            )
            for name in slide_names:
                root = ET.fromstring(archive.read(name))
                for elem in root.iter():
                    if elem.tag.endswith("}t") and elem.text and elem.text.strip():
                        texts.append(elem.text.strip())
        return "\n".join(texts)

    def _extract_docx(self, path: Path) -> str:
        texts: list[str] = []
        with zipfile.ZipFile(path) as archive:
            for name in ["word/document.xml"]:
                if name not in archive.namelist():
                    continue
                root = ET.fromstring(archive.read(name))
                for elem in root.iter():
                    if elem.tag.endswith("}t") and elem.text and elem.text.strip():
                        texts.append(elem.text.strip())
        return "\n".join(texts)

    def _extract_txt(self, path: Path) -> str:
        data = path.read_bytes()
        for encoding in ("utf-8", "gbk", "gb18030"):
            try:
                return data.decode(encoding)
            except UnicodeDecodeError:
                continue
        return data.decode("utf-8", errors="ignore")

    def _extract_pdf(self, path: Path) -> str:
        try:
            from pypdf import PdfReader
        except ImportError as exc:
            raise RuntimeError("请先安装 pypdf 以支持 PDF 解析") from exc

        reader = PdfReader(str(path))
        texts = []
        for page in reader.pages:
            text = page.extract_text() or ""
            if text.strip():
                texts.append(text.strip())
        return "\n".join(texts)
