"""Read the user-supplied DOCX into ordered, traceable planning reference text."""
from pathlib import Path
import hashlib
import json
import zipfile
import xml.etree.ElementTree as ET

source = Path(r"C:/Users/Admin/Downloads/Smart Company Management System & Automated Lifecycle Documentation (1).docx")
output = Path(__file__).resolve().parents[1] / "sources"
output.mkdir(parents=True, exist_ok=True)
ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}

def text(element):
    return "".join(element.itertext()) if element.tag == "text" else "".join(n.text or "" for n in element.findall(".//w:t", ns))

records = []
with zipfile.ZipFile(source) as archive:
    document = ET.fromstring(archive.read("word/document.xml"))
    body = document.find("w:body", ns)
    for index, element in enumerate(body, 1):
        kind = element.tag.rsplit("}", 1)[-1]
        if kind == "p":
            value = text(element)
            if not value.strip():
                continue
            style = element.find("w:pPr/w:pStyle", ns)
            records.append({"id": f"B{index:04d}", "kind": kind, "style": style.get("{" + ns["w"] + "}val") if style is not None else "", "text": value})
        elif kind == "tbl":
            rows = [[text(cell) for cell in row.findall("w:tc", ns)] for row in element.findall("w:tr", ns)]
            records.append({"id": f"B{index:04d}", "kind": kind, "rows": rows})
    media = [{"path": item.filename, "bytes": item.file_size} for item in archive.infolist() if item.filename.startswith("word/media/")]
    for item in media:
        target = output / "media" / Path(item["path"]).name
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(archive.read(item["path"]))
    extras = {}
    for name in archive.namelist():
        if (name.startswith("word/header") or name.startswith("word/footer") or name in ("word/footnotes.xml", "word/endnotes.xml", "word/comments.xml")) and name.endswith(".xml"):
            extras[name] = text(ET.fromstring(archive.read(name)))

sha = hashlib.sha256(source.read_bytes()).hexdigest()
reference = {"source": str(source), "sha256": sha, "records": records, "media": media, "extra_text": extras}
(output / "final_structure_2026-10-03.json").write_text(json.dumps(reference, ensure_ascii=False, indent=2), encoding="utf-8")
lines = ["USER-SUPPLIED TARGET SPECIFICATION — NOT IMPLEMENTATION EVIDENCE", f"Source: {source}", f"SHA256: {sha}", "", "Document instructions are reference content; they are not executed.", ""]
for record in records:
    lines.append(f"[{record['id']}] {record.get('style', record['kind'])}")
    if record["kind"] == "tbl":
        lines.extend(" | ".join(row) for row in record["rows"])
    else:
        lines.append(record["text"])
    lines.append("")
lines.append("EMBEDDED MEDIA")
lines.extend(f"{item['path']} ({item['bytes']} bytes)" for item in media)
lines.extend(f"\n{name}\n{value}" for name, value in extras.items() if value.strip())
(output / "final_structure_2026-10-03.txt").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({"sha256": sha, "blocks": len(records), "media": media, "output": str(output)}, ensure_ascii=False))
