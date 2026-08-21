#!/usr/bin/env python3
"""Extract review-relevant DOCX structure without changing the source file.

The extractor preserves paragraph order and records direct run formatting
(font color, highlight, bold, italic, underline), tracked-change context, and
comment anchor IDs.  It writes both JSON for auditing and Markdown for quick
human review.
"""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W = f"{{{W_NS}}}"
NS = {"w": W_NS}


def qn(local: str) -> str:
    return f"{W}{local}"


def direct_text(element: ET.Element) -> str:
    pieces: list[str] = []
    for node in element.iter():
        if node.tag in {qn("t"), qn("delText"), qn("instrText")}:
            pieces.append(node.text or "")
        elif node.tag == qn("tab"):
            pieces.append("\t")
        elif node.tag in {qn("br"), qn("cr")}:
            pieces.append("\n")
    return "".join(pieces)


def bool_prop(rpr: ET.Element | None, name: str) -> bool:
    if rpr is None:
        return False
    item = rpr.find(f"w:{name}", NS)
    if item is None:
        return False
    value = item.get(qn("val"), "1").lower()
    return value not in {"0", "false", "off", "none"}


def run_format(run: ET.Element, parent_map: dict[ET.Element, ET.Element]) -> dict[str, object]:
    rpr = run.find("w:rPr", NS)
    color = None
    highlight = None
    style = None
    if rpr is not None:
        color_node = rpr.find("w:color", NS)
        highlight_node = rpr.find("w:highlight", NS)
        style_node = rpr.find("w:rStyle", NS)
        if color_node is not None:
            color = color_node.get(qn("val")) or color_node.get(qn("themeColor"))
        if highlight_node is not None:
            highlight = highlight_node.get(qn("val"))
        if style_node is not None:
            style = style_node.get(qn("val"))

    change = "normal"
    current = parent_map.get(run)
    while current is not None:
        if current.tag == qn("ins"):
            change = "inserted"
            break
        if current.tag == qn("del"):
            change = "deleted"
            break
        current = parent_map.get(current)

    return {
        "text": direct_text(run),
        "color": color,
        "highlight": highlight,
        "bold": bool_prop(rpr, "b"),
        "italic": bool_prop(rpr, "i"),
        "underline": bool_prop(rpr, "u"),
        "style": style,
        "change": change,
    }


def paragraph_style(paragraph: ET.Element) -> str | None:
    style = paragraph.find("w:pPr/w:pStyle", NS)
    return style.get(qn("val")) if style is not None else None


def enclosing_table_cell(
    paragraph: ET.Element, parent_map: dict[ET.Element, ET.Element]
) -> tuple[int | None, int | None]:
    current = parent_map.get(paragraph)
    cell = None
    row = None
    table = None
    while current is not None:
        if current.tag == qn("tc") and cell is None:
            cell = current
        elif current.tag == qn("tr") and row is None:
            row = current
        elif current.tag == qn("tbl"):
            table = current
            break
        current = parent_map.get(current)
    if table is None or row is None or cell is None:
        return None, None
    rows = [child for child in table if child.tag == qn("tr")]
    cells = [child for child in row if child.tag == qn("tc")]
    return rows.index(row) + 1, cells.index(cell) + 1


def load_comments(archive: zipfile.ZipFile) -> dict[str, dict[str, str | None]]:
    try:
        root = ET.fromstring(archive.read("word/comments.xml"))
    except KeyError:
        return {}
    comments: dict[str, dict[str, str | None]] = {}
    for comment in root.findall("w:comment", NS):
        cid = comment.get(qn("id"), "")
        comments[cid] = {
            "id": cid,
            "author": comment.get(qn("author")),
            "date": comment.get(qn("date")),
            "initials": comment.get(qn("initials")),
            "text": direct_text(comment).strip(),
        }
    return comments


def extract_docx(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as archive:
        document = ET.fromstring(archive.read("word/document.xml"))
        comments = load_comments(archive)

    parent_map = {child: parent for parent in document.iter() for child in parent}
    paragraphs: list[dict[str, object]] = []
    for index, paragraph in enumerate(document.iter(qn("p")), start=1):
        runs = [run_format(run, parent_map) for run in paragraph.iter(qn("r"))]
        text = "".join(str(run["text"]) for run in runs)
        comment_ids: list[str] = []
        for node in paragraph.iter():
            if node.tag in {qn("commentRangeStart"), qn("commentRangeEnd"), qn("commentReference")}:
                cid = node.get(qn("id"))
                if cid is not None and cid not in comment_ids:
                    comment_ids.append(cid)
        row, column = enclosing_table_cell(paragraph, parent_map)
        paragraphs.append(
            {
                "id": f"P{index:04d}",
                "style": paragraph_style(paragraph),
                "table_row": row,
                "table_column": column,
                "text": text,
                "comment_ids": comment_ids,
                "runs": runs,
            }
        )

    return {
        "source": str(path),
        "paragraph_count": len(paragraphs),
        "comment_count": len(comments),
        "comments": list(comments.values()),
        "paragraphs": paragraphs,
    }


def compact_run_label(run: dict[str, object]) -> str:
    properties: list[str] = []
    for name in ("color", "highlight", "style", "change"):
        value = run.get(name)
        if value and value != "normal":
            properties.append(f"{name}={value}")
    for name in ("bold", "italic", "underline"):
        if run.get(name):
            properties.append(name)
    text = re.sub(r"\s+", " ", str(run.get("text", ""))).strip()
    return f"`{text}` ({', '.join(properties)})"


def write_markdown(data: dict[str, object], path: Path) -> None:
    lines = [
        "# DOCX structural extraction",
        "",
        f"- Source: `{data['source']}`",
        f"- Paragraphs: {data['paragraph_count']}",
        f"- Comments: {data['comment_count']}",
        "",
        "## Comments",
        "",
    ]
    comments = data["comments"]
    if comments:
        for comment in comments:
            lines.extend(
                [
                    f"### Comment {comment['id']}",
                    "",
                    f"- Author: {comment.get('author') or ''}",
                    f"- Date: {comment.get('date') or ''}",
                    f"- Text: {comment.get('text') or ''}",
                    "",
                ]
            )
    else:
        lines.extend(["No comments.", ""])

    lines.extend(["## Paragraphs", ""])
    for paragraph in data["paragraphs"]:
        location = ""
        if paragraph["table_row"] is not None:
            location = f" table=R{paragraph['table_row']}C{paragraph['table_column']}"
        lines.extend(
            [
                f"### {paragraph['id']} style={paragraph['style'] or ''}{location}",
                "",
                paragraph["text"] or "*(empty)*",
                "",
            ]
        )
        if paragraph["comment_ids"]:
            lines.append(f"- Comment anchors: {', '.join(paragraph['comment_ids'])}")
        marked = [
            run
            for run in paragraph["runs"]
            if run.get("color")
            or run.get("highlight")
            or run.get("bold")
            or run.get("italic")
            or run.get("underline")
            or run.get("style")
            or run.get("change") != "normal"
        ]
        if marked:
            lines.append("- Marked runs: " + "; ".join(compact_run_label(run) for run in marked))
        if paragraph["comment_ids"] or marked:
            lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    args = parser.parse_args()

    data = extract_docx(args.input.resolve())
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.markdown.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    write_markdown(data, args.markdown)


if __name__ == "__main__":
    main()
