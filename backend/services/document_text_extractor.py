import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
import re


class DocumentTextExtractor:
    """Extract plain text from uploaded study documents."""

    def extract(self, file_path: str | Path, original_name: str = "") -> str:
        units = self.extract_units(file_path, original_name)
        return "\n".join(unit["text"] for unit in units if unit["text"].strip())

    def extract_units(self, file_path: str | Path, original_name: str = "") -> list[dict]:
        path = Path(file_path)
        suffix = (Path(original_name).suffix or path.suffix).lower()

        if suffix == ".pptx":
            return self._extract_pptx_units(path)
        if suffix == ".docx":
            return self._extract_docx_units(path)
        if suffix == ".txt":
            return self._extract_txt_units(path)
        if suffix == ".pdf":
            return self._extract_pdf_units(path)
        if suffix in {".ppt", ".doc"}:
            raise ValueError("暂不支持旧版 .ppt/.doc，请先另存为 .pptx/.docx")
        raise ValueError(f"不支持的文件类型: {suffix or original_name}")

    def _extract_pptx_units(self, path: Path) -> list[dict]:
        units = []
        with zipfile.ZipFile(path) as archive:
            slide_names = sorted(
                (
                    name for name in archive.namelist()
                    if name.startswith("ppt/slides/slide") and name.endswith(".xml")
                ),
                key=self._slide_number,
            )
            for page_number, name in enumerate(slide_names, start=1):
                root = ET.fromstring(archive.read(name))
                texts = []
                for elem in root.iter():
                    if elem.tag.endswith("}t") and elem.text and elem.text.strip():
                        texts.append(elem.text.strip())
                if texts:
                    units.append({
                        "text": "\n".join(texts),
                        "page_number": page_number,
                        "page_label": f"第 {page_number} 页",
                        "unit_type": "slide",
                    })
        return units

    def _extract_docx_units(self, path: Path) -> list[dict]:
        texts: list[str] = []
        with zipfile.ZipFile(path) as archive:
            for name in ["word/document.xml"]:
                if name not in archive.namelist():
                    continue
                root = ET.fromstring(archive.read(name))
                for elem in root.iter():
                    if elem.tag.endswith("}t") and elem.text and elem.text.strip():
                        texts.append(elem.text.strip())
        return self._paragraph_units(texts)

    def _extract_txt_units(self, path: Path) -> list[dict]:
        data = path.read_bytes()
        for encoding in ("utf-8", "gbk", "gb18030"):
            try:
                return self._paragraph_units(data.decode(encoding).splitlines())
            except UnicodeDecodeError:
                continue
        return self._paragraph_units(data.decode("utf-8", errors="ignore").splitlines())

    def _extract_pdf_units(self, path: Path) -> list[dict]:
        try:
            from pypdf import PdfReader
        except ImportError as exc:
            raise RuntimeError("请先安装 pypdf 以支持 PDF 解析") from exc

        reader = PdfReader(str(path))
        units = []
        for page_number, page in enumerate(reader.pages, start=1):
            text = page.extract_text() or ""
            if text.strip():
                units.append({
                    "text": text.strip(),
                    "page_number": page_number,
                    "page_label": f"第 {page_number} 页",
                    "unit_type": "page",
                })
        return units

    @staticmethod
    def _slide_number(name: str) -> int:
        match = re.search(r"slide(\d+)\.xml$", name)
        return int(match.group(1)) if match else 0

    @staticmethod
    def _paragraph_units(lines: list[str], group_size: int = 12) -> list[dict]:
        paragraphs = [line.strip() for line in lines if line and line.strip()]
        units = []
        for start in range(0, len(paragraphs), group_size):
            group_number = len(units) + 1
            units.append({
                "text": "\n".join(paragraphs[start:start + group_size]),
                "page_number": 0,
                "page_label": f"第 {group_number} 段",
                "unit_type": "paragraph_group",
            })
        return units
