#!/usr/bin/env python3
"""Study Vault MCP server: lets Devin read and add to the local library.

Runs over stdio (JSON-RPC 2.0, one message per line) using only the Python
standard library. It writes the same rows the app writes, so new content
syncs like anything created in the app. It never deletes study content.

Every write tool previews by default; pass "apply": true to save.
Environment: STUDY_VAULT_DB (default ~/Documents/study_vault.sqlite).
"""

import base64
import hashlib
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

SCHEMA_VERSIONS = {18}
PROVIDER = "manual"
MODEL = "devin"
DB_PATH = os.path.expanduser(
    os.environ.get("STUDY_VAULT_DB", "~/Documents/study_vault.sqlite")
)
FILES_ROOT = os.path.join(os.path.dirname(DB_PATH), "study_vault_files")

MATERIAL_TYPES = [
    "summary",
    "explanation",
    "deep_explanation",
    "real_world_examples",
    "slideshow",
]
SECTION_PARTS = ["summary", "explanation", "deep_explanation"]
CATEGORY_IDS = {
    "definition", "important", "formula", "question", "example", "exam",
    "confusing",
}


class ToolError(Exception):
    pass


# ── Database ────────────────────────────────────────────────────────────


def connect():
    if not os.path.exists(DB_PATH):
        raise ToolError(f"Study Vault database not found at {DB_PATH}.")
    db = sqlite3.connect(DB_PATH, timeout=15, isolation_level=None)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA busy_timeout = 15000")
    version = db.execute("PRAGMA user_version").fetchone()[0]
    if version not in SCHEMA_VERSIONS:
        db.close()
        raise ToolError(
            f"Database schema {version} is not supported by this tool "
            f"(expects {sorted(SCHEMA_VERSIONS)}). Update the app or the tool."
        )
    return db


class Write:
    """BEGIN IMMEDIATE … COMMIT with FK verification; rolls back on error."""

    def __init__(self, db):
        self.db = db

    def __enter__(self):
        self.db.execute("BEGIN IMMEDIATE")
        return self.db

    def __exit__(self, kind, value, tb):
        if kind is None:
            if self.db.execute("PRAGMA foreign_key_check").fetchall():
                self.db.execute("ROLLBACK")
                raise ToolError("Related records are missing; nothing saved.")
            self.db.execute("COMMIT")
        else:
            self.db.execute("ROLLBACK")
        return False


def now():
    return int(time.time())


def new_id():
    return str(uuid.uuid4())


def one(db, sql, *args):
    return db.execute(sql, args).fetchone()


def rows(db, sql, *args):
    return db.execute(sql, args).fetchall()


def require(row, what):
    if row is None:
        raise ToolError(f"{what} not found. Use library_overview for ids.")
    return row


def material_row(db, material_id):
    return require(
        one(
            db,
            "SELECT m.*, l.name AS lesson_name, l.subject_id, s.name AS "
            "subject_name FROM lesson_materials m JOIN lessons l ON "
            "l.id = m.lesson_id JOIN subjects s ON s.id = l.subject_id "
            "WHERE m.id = ?",
            material_id,
        ),
        f"Material {material_id}",
    )


def latest_version(db, table, where, *args):
    row = one(db, f"SELECT MAX(version) FROM {table} WHERE {where}", *args)
    return row[0] or 0


def app_running():
    try:
        return subprocess.run(
            ["pgrep", "-x", "study_vault"], capture_output=True, timeout=3,
        ).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def saved_message(summary):
    note = (
        " The open Study Vault window refreshes within a few seconds."
        if app_running()
        else ""
    )
    return f"Saved: {summary}.{note} Press Sync now on each device to share it."


# ── Markdown → Quill Delta (mirrors lib/.../markdown_to_quill.dart) ──────

_INLINE = re.compile(
    r"(`[^`\n]+`)"
    r"|(\*\*\*[^*\n]+?\*\*\*)"
    r"|(___[^_\n]+?___)"
    r"|(\*\*[^*\n]+?\*\*)"
    r"|(__[^_\n]+?__)"
    r"|(\*[^*\n]+?\*)"
    r"|(_[^_\n]+?_)"
    r"|(\[[^\]]+\]\([^)]+\))"
)


def _inline(ops, text):
    if not text:
        return
    start = 0
    for m in _INLINE.finditer(text):
        if m.start() > start:
            ops.append({"insert": text[start:m.start()]})
        token = m.group(0)
        if token.startswith("`"):
            ops.append({"insert": token[1:-1], "attributes": {"code": True}})
        elif token.startswith("***") or token.startswith("___"):
            ops.append(
                {"insert": token[3:-3], "attributes": {"bold": True, "italic": True}}
            )
        elif token.startswith("**") or token.startswith("__"):
            ops.append({"insert": token[2:-2], "attributes": {"bold": True}})
        elif token.startswith("*") or token.startswith("_"):
            ops.append({"insert": token[1:-1], "attributes": {"italic": True}})
        else:
            link = re.match(r"^\[([^\]]+)\]\(([^)]+)\)$", token)
            ops.append(
                {"insert": link.group(1), "attributes": {"link": link.group(2)}}
                if link
                else {"insert": token}
            )
        start = m.end()
    if start < len(text):
        ops.append({"insert": text[start:]})


def _is_table_row(line):
    t = line.strip()
    return len(t) >= 2 and t.startswith("|") and t.endswith("|")


def _is_table_sep(line):
    return re.match(
        r"^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$", line.strip()
    ) is not None


def _cells(line):
    t = line.strip()
    if t.startswith("|"):
        t = t[1:]
    if t.endswith("|"):
        t = t[:-1]
    return [c.strip() for c in t.split("|")]


def _indent(ws):
    return min(len(ws.replace("\t", "  ")) // 2, 3)


def markdown_to_delta(markdown):
    text = markdown.replace("\r\n", "\n").strip()
    fence = re.match(r"^```(?:markdown|md)?\s*\n([\s\S]*?)\n```$", text, re.I)
    if fence:
        text = fence.group(1).strip()
    ops = []
    lines = text.split("\n") if text else []
    in_code = False
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if (not in_code and _is_table_row(line) and i + 1 < len(lines)
                and _is_table_sep(lines[i + 1])):
            header = _cells(line)
            end = i + 2
            table = []
            while end < len(lines) and _is_table_row(lines[end]):
                table.append(_cells(lines[end]))
                end += 1
            if not table:
                _inline(ops, " · ".join(header))
                ops.append({"insert": "\n"})
            for row in table:
                first = row[0] if row else ""
                rest = []
                for c in range(1, len(row)):
                    if not row[c]:
                        continue
                    label = (
                        f"{header[c]}: " if c < len(header) and len(header) > 2
                        else ""
                    )
                    rest.append(f"{label}{row[c]}")
                if first:
                    ops.append(
                        {"insert": first.replace("**", ""),
                         "attributes": {"bold": True}}
                    )
                    if rest:
                        ops.append({"insert": " — "})
                _inline(ops, " · ".join(rest))
                ops.append({"insert": "\n", "attributes": {"list": "bullet"}})
            if table:
                ops.append({"insert": "\n"})
            i = end
            continue
        i += 1
        if stripped.startswith("```"):
            in_code = not in_code
            if not in_code and not (
                ops and isinstance(ops[-1]["insert"], str)
                and ops[-1]["insert"].endswith("\n")
            ):
                ops.append({"insert": "\n"})
            continue
        if in_code:
            ops.append({"insert": line})
            ops.append({"insert": "\n", "attributes": {"code-block": True}})
            continue
        if not line.strip():
            ops.append({"insert": "\n"})
            continue
        if re.match(r"^(?:-{2,}|_{3,}|\*{3,})\s*$", line.strip()):
            ops.append({"insert": {"divider": "hr"}})
            ops.append({"insert": "\n"})
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            _inline(ops, m.group(2).rstrip())
            ops.append({"insert": "\n", "attributes": {"header": len(m.group(1))}})
            continue
        m = re.match(r"^>\s?(.*)$", line)
        if m:
            _inline(ops, m.group(1))
            ops.append({"insert": "\n", "attributes": {"blockquote": True}})
            continue
        for pattern, kind in ((r"^(\s*)[-*+]\s+(.*)$", "bullet"),
                              (r"^(\s*)\d+\.\s+(.*)$", "ordered")):
            m = re.match(pattern, line)
            if m:
                _inline(ops, m.group(2))
                attrs = {"list": kind}
                if _indent(m.group(1)):
                    attrs["indent"] = _indent(m.group(1))
                ops.append({"insert": "\n", "attributes": attrs})
                break
        else:
            _inline(ops, line)
            ops.append({"insert": "\n"})
    if not ops or not (
        isinstance(ops[-1]["insert"], str) and ops[-1]["insert"].endswith("\n")
    ):
        ops.append({"insert": "\n"})
    return json.dumps(ops, ensure_ascii=False, separators=(",", ":"))


def delta_plain_text(delta_json):
    text = "".join(
        op["insert"] for op in json.loads(delta_json)
        if isinstance(op.get("insert"), str)
    )
    return " ".join(text.split())


# ── App-equivalent Course Review fingerprints ───────────────────────────


def _latest_ai(db, material_id, kind):
    return one(
        db,
        "SELECT id FROM pdf_ai_materials WHERE material_id = ? AND type = ? "
        "ORDER BY version DESC, generated_at DESC LIMIT 1",
        material_id, kind,
    )


def section_fingerprint(db, material):
    summary = _latest_ai(db, material["id"], "summary")
    explanation = _latest_ai(db, material["id"], "explanation")
    if summary or explanation:
        return (
            f"ai:{summary['id'] if summary else '-'}:"
            f"{explanation['id'] if explanation else '-'}"
        )
    return f"pdf:{material['id']}:{material['stored_file_name']}"


def overview_fingerprint(db, subject_id):
    excluded = {
        r[0] for r in rows(
            db,
            "SELECT material_id FROM course_review_exclusions WHERE subject_id = ?",
            subject_id,
        )
    }
    ids = []
    for m in rows(
        db,
        "SELECT m.id FROM lesson_materials m JOIN lessons l ON l.id = "
        "m.lesson_id WHERE l.subject_id = ? AND m.mime_type = 'application/pdf'",
        subject_id,
    ):
        if m["id"] in excluded:
            continue
        for part in SECTION_PARTS:
            row = one(
                db,
                "SELECT id FROM course_review_entries WHERE subject_id = ? AND "
                "material_id = ? AND part = ? ORDER BY version DESC, "
                "created_at DESC LIMIT 1",
                subject_id, m["id"], part,
            )
            if row:
                ids.append(row["id"])
    ids.sort()
    digest = hashlib.sha256(",".join(ids).encode()).hexdigest()[:24]
    return f"sections:{digest}"


# ── PDF text and book search ────────────────────────────────────────────


def pdf_pages(path, start, end):
    if not os.path.exists(path):
        raise ToolError("The PDF file is not on this computer (sync first).")
    try:
        out = subprocess.run(
            ["pdftotext", "-f", str(start), "-l", str(end), "-enc", "UTF-8",
             path, "-"],
            capture_output=True, text=True, timeout=120,
        )
    except FileNotFoundError as error:
        raise ToolError("pdftotext is not installed (poppler-utils).") from error
    if out.returncode != 0:
        raise ToolError(f"Could not read the PDF: {out.stderr.strip()[:200]}")
    parts = out.stdout.split("\f")
    return [
        (start + i, text.strip()) for i, text in enumerate(parts)
        if start + i <= end
    ]


_WORD = re.compile(r"\w+", re.UNICODE)
_STOP = set(
    "the and for are but not you all any can was one our out has his how its "
    "may who did this that with from they will what when which there their "
    "then than them these those into have been were also such each other some "
    "more most only very about would could should does between where why"
    .split()
)


def _stem(word):
    if len(word) <= 4:
        return word
    for suffix in ("ations", "ation", "ings", "ing"):
        if word.endswith(suffix) and len(word) - len(suffix) >= 3:
            return word[: -len(suffix)]
    for suffix in ("ies", "ied"):
        if word.endswith(suffix) and len(word) - len(suffix) >= 3:
            return word[: -len(suffix)] + "y"
    for suffix in ("es", "ed", "ly", "s"):
        if (word.endswith(suffix) and not word.endswith("ss")
                and len(word) - len(suffix) >= 3):
            return word[: -len(suffix)]
    return word


def _tokens(text):
    return [
        _stem(w) for w in _WORD.findall(text.lower())
        if len(w) >= 2 and w not in _STOP
    ]


def bm25(pages, query, limit):
    terms = set(_tokens(query))
    docs = [(page, _tokens(text)) for page, text in pages]
    if not terms or not docs:
        return []
    avg = sum(len(t) for _, t in docs) / len(docs) or 1
    df = {t: sum(1 for _, toks in docs if t in toks) for t in terms}
    scored = []
    for page, toks in docs:
        score = 0.0
        for term in terms:
            tf = toks.count(term)
            if not tf:
                continue
            idf = math.log(1 + (len(docs) - df[term] + 0.5) / (df[term] + 0.5))
            score += idf * tf * 2.2 / (tf + 1.2 * (0.25 + 0.75 * len(toks) / avg))
        if score > 0:
            scored.append((score, page))
    scored.sort(reverse=True)
    return [page for _, page in scored[:limit]]


# ── Read tools ──────────────────────────────────────────────────────────


def library_overview(db, _):
    result = []
    for cls in rows(db, "SELECT id, name FROM classes ORDER BY created_at, name"):
        subjects = []
        for s in rows(
            db,
            "SELECT id, name FROM subjects WHERE class_id = ? ORDER BY sort_order",
            cls["id"],
        ):
            lessons = []
            for lesson in rows(
                db,
                "SELECT id, name FROM lessons WHERE subject_id = ? "
                "ORDER BY sort_order, created_at",
                s["id"],
            ):
                materials = []
                for m in rows(
                    db,
                    "SELECT id, title, mime_type FROM lesson_materials WHERE "
                    "lesson_id = ? ORDER BY sort_order, created_at",
                    lesson["id"],
                ):
                    types = [
                        f"{r['type']} v{r['v']}" for r in rows(
                            db,
                            "SELECT type, MAX(version) AS v FROM pdf_ai_materials "
                            "WHERE material_id = ? GROUP BY type",
                            m["id"],
                        )
                    ]
                    materials.append({
                        "material_id": m["id"], "title": m["title"],
                        "kind": "pdf" if m["mime_type"] == "application/pdf"
                        else "image",
                        "ai_materials": types,
                    })
                counts = one(
                    db,
                    "SELECT (SELECT COUNT(*) FROM study_notes WHERE lesson_id = ?) "
                    "AS notes, (SELECT COUNT(*) FROM flashcards WHERE lesson_id = ?) "
                    "AS flashcards, (SELECT COUNT(*) FROM question_sets WHERE "
                    "lesson_id = ?) AS quizzes",
                    lesson["id"], lesson["id"], lesson["id"],
                )
                lessons.append({
                    "lesson_id": lesson["id"], "name": lesson["name"],
                    "notes": counts["notes"], "flashcards": counts["flashcards"],
                    "quizzes": counts["quizzes"], "materials": materials,
                })
            review = one(
                db,
                "SELECT COUNT(DISTINCT material_id) FROM course_review_entries "
                "WHERE subject_id = ? AND material_id IS NOT NULL",
                s["id"],
            )[0]
            subjects.append({
                "subject_id": s["id"], "name": s["name"],
                "course_review_sections": review, "lessons": lessons,
            })
        result.append({"class_id": cls["id"], "name": cls["name"],
                       "subjects": subjects})
    books = [
        {
            "book_id": b["id"], "title": b["title"], "pages": b["page_count"],
            "chapters": one(
                db, "SELECT COUNT(*) FROM reference_book_chapters WHERE book_id = ?",
                b["id"],
            )[0],
            "indexed_pages_on_this_computer": (one(
                db, "SELECT indexed_pages FROM local_book_state WHERE book_id = ?",
                b["id"],
            ) or [0])[0],
        }
        for b in rows(db, "SELECT * FROM reference_books ORDER BY title")
    ]
    return {"classes": result, "reference_books": books}


def get_lecture(db, args):
    m = material_row(db, args["material_id"])
    lesson_id = m["lesson_id"]
    return {
        "material": {"id": m["id"], "title": m["title"],
                     "lesson": m["lesson_name"], "lesson_id": lesson_id,
                     "subject": m["subject_name"], "subject_id": m["subject_id"]},
        "ai_materials": [
            {"type": r["type"], "latest_version": r["v"], "chars": r["chars"]}
            for r in rows(
                db,
                "SELECT type, MAX(version) AS v, LENGTH(content) AS chars FROM "
                "pdf_ai_materials WHERE material_id = ? GROUP BY type",
                m["id"],
            )
        ],
        "notes": [r[0] for r in rows(
            db, "SELECT title FROM study_notes WHERE lesson_id = ?", lesson_id)],
        "flashcard_fronts": [r[0] for r in rows(
            db, "SELECT front FROM flashcards WHERE lesson_id = ? LIMIT 200",
            lesson_id)],
        "quizzes": [
            f"{r['title']} ({r['question_count']} q)" for r in rows(
                db,
                "SELECT title, question_count FROM question_sets WHERE lesson_id = ?",
                lesson_id,
            )
        ],
        "course_review_parts": [
            f"{r['part']} v{r['v']}" for r in rows(
                db,
                "SELECT part, MAX(version) AS v FROM course_review_entries WHERE "
                "material_id = ? GROUP BY part",
                m["id"],
            )
        ],
        "book_links": [
            f"{r['title']} pp. {r['start_page']}-{r['end_page']} ({r['priority']})"
            for r in rows(
                db,
                "SELECT b.title, k.start_page, k.end_page, k.priority FROM "
                "reference_book_links k JOIN reference_books b ON b.id = "
                "k.book_id WHERE k.material_id = ? ORDER BY k.start_page",
                m["id"],
            )
        ],
    }


def read_study_material(db, args):
    material_row(db, args["material_id"])
    row = one(
        db,
        "SELECT version, content FROM pdf_ai_materials WHERE material_id = ? AND "
        "type = ? ORDER BY version DESC LIMIT 1",
        args["material_id"], args["type"],
    )
    if row is None:
        return f"No {args['type']} exists for this material yet."
    return f"[{args['type']} v{row['version']}]\n\n{row['content']}"


def read_pdf_text(db, args):
    start = max(1, int(args.get("start_page", 1)))
    end = int(args.get("end_page", start + 19))
    if end < start or end - start >= 120:
        raise ToolError("Read at most 120 pages at a time.")
    limit = int(args.get("max_chars", 120000))
    if args.get("book_id"):
        book = require(
            one(db, "SELECT * FROM reference_books WHERE id = ?", args["book_id"]),
            "Book",
        )
        pages = [
            (r["page"], r["text"]) for r in rows(
                db,
                "SELECT page, text FROM local_book_pages WHERE book_id = ? AND "
                "page BETWEEN ? AND ? ORDER BY page",
                book["id"], start, end,
            )
        ]
        if len(pages) < min(end, book["page_count"]) - start + 1:
            pages = pdf_pages(
                os.path.join(FILES_ROOT, "books", book["id"],
                             book["stored_file_name"]),
                start, min(end, book["page_count"]),
            )
    else:
        m = material_row(db, args["material_id"])
        if m["mime_type"] != "application/pdf":
            raise ToolError("That material is an image, not a PDF.")
        pages = pdf_pages(
            os.path.join(FILES_ROOT, "lessons", m["lesson_id"],
                         m["stored_file_name"]),
            start, end,
        )
    out = []
    used = 0
    for page, text in pages:
        block = f"--- Page {page} ---\n{text or '(no extractable text)'}\n"
        if used + len(block) > limit:
            if not out:
                out.append(block[:limit] + "\n[page shortened: max_chars reached]")
            else:
                out.append(f"[stopped after page {page - 1}: max_chars reached]")
            break
        out.append(block)
        used += len(block)
    return "\n".join(out) if out else "No pages in that range."


def get_course_review(db, args):
    subject = require(
        one(db, "SELECT * FROM subjects WHERE id = ?", args["subject_id"]),
        "Subject",
    )
    full = bool(args.get("include_content", False))
    current_overview = overview_fingerprint(db, subject["id"])
    sections = []
    for m in rows(
        db,
        "SELECT m.*, l.name AS lesson_name FROM lesson_materials m JOIN lessons "
        "l ON l.id = m.lesson_id WHERE l.subject_id = ? AND m.mime_type = "
        "'application/pdf' ORDER BY l.sort_order, l.created_at, m.sort_order",
        subject["id"],
    ):
        fingerprint = section_fingerprint(db, m)
        parts = {}
        for part in SECTION_PARTS:
            row = one(
                db,
                "SELECT version, content, source_fingerprint FROM "
                "course_review_entries WHERE material_id = ? AND part = ? "
                "ORDER BY version DESC, created_at DESC LIMIT 1",
                m["id"], part,
            )
            if row:
                parts[part] = (
                    row["content"] if full else
                    f"v{row['version']}"
                    + ("" if row["source_fingerprint"] == fingerprint
                       else " (outdated)")
                )
        excluded = one(
            db, "SELECT 1 FROM course_review_exclusions WHERE material_id = ?",
            m["id"],
        ) is not None
        sections.append({"material_id": m["id"], "lesson": m["lesson_name"],
                         "pdf": m["title"], "excluded": excluded,
                         "parts": parts})
    overview = {}
    for part in ("big_picture", "examples"):
        row = one(
            db,
            "SELECT version, content, source_fingerprint FROM course_review_entries "
            "WHERE subject_id = ? AND material_id IS NULL AND part = ? "
            "ORDER BY version DESC, created_at DESC LIMIT 1",
            subject["id"], part,
        )
        if row:
            overview[part] = (
                row["content"] if full else
                f"v{row['version']}"
                + ("" if row["source_fingerprint"] == current_overview
                   else " (outdated)")
            )
    return {"subject": subject["name"], "sections": sections,
            "overview": overview}


def get_book(db, args):
    book = require(
        one(db, "SELECT * FROM reference_books WHERE id = ?", args["book_id"]),
        "Book",
    )
    items = {}
    for r in rows(
        db,
        "SELECT kind, scope_key, MAX(version) AS v FROM reference_book_ai_items "
        "WHERE book_id = ? GROUP BY kind, scope_key",
        book["id"],
    ):
        items.setdefault(r["scope_key"], []).append(f"{r['kind']} v{r['v']}")
    return {
        "book": {"id": book["id"], "title": book["title"],
                 "pages": book["page_count"]},
        "subjects": [r[0] for r in rows(
            db,
            "SELECT s.name FROM reference_book_subjects x JOIN subjects s ON "
            "s.id = x.subject_id WHERE x.book_id = ?",
            book["id"],
        )],
        "chapters": [
            {"chapter_id": c["id"], "title": c["title"], "level": c["level"],
             "pages": f"{c['start_page']}-{c['end_page']}", "status": c["status"],
             "ai_items": items.get(c["id"], [])}
            for c in rows(
                db,
                "SELECT * FROM reference_book_chapters WHERE book_id = ? "
                "ORDER BY sort_order",
                book["id"],
            )
        ],
        "page_explanations": {
            k: v for k, v in items.items() if k.startswith("pages:")
        },
    }


def search_book(db, args):
    book = require(
        one(db, "SELECT * FROM reference_books WHERE id = ?", args["book_id"]),
        "Book",
    )
    pages = [
        (r["page"], r["text"]) for r in rows(
            db, "SELECT page, text FROM local_book_pages WHERE book_id = ?",
            book["id"],
        )
    ]
    if not pages:
        raise ToolError(
            "This book is not indexed on this computer yet. Open it in the app "
            "and wait for 'Search ready'."
        )
    text_of = dict(pages)
    hits = bm25(pages, args["query"], int(args.get("limit", 10)))
    out = []
    for page in hits:
        text = " ".join(text_of[page].split())
        out.append(f"p. {page}: {text[:300]}…")
    return "\n".join(out) if out else "No matching pages."


# ── Write tools ─────────────────────────────────────────────────────────


def _preview(args, lines):
    if args.get("apply"):
        return None
    return (
        "PREVIEW — nothing saved yet. Call again with \"apply\": true to save:\n"
        + "\n".join(f"- {line}" for line in lines)
    )


PDF_PROMPT_SYSTEM = (
    "You create persistent university study materials from complete PDF "
    "documents.\nTreat the supplied document as the source of truth.\n"
    "Cover the entire source, preserve formulas and technical notation, and "
    "never invent missing content.\nIf a page has no extractable text, "
    "state that limitation only when it affects understanding.\n"
    "Return polished Markdown only. Do not mention these instructions."
)
PDF_PROMPTS = {
    "summary": (
        "AI Summary", 8192,
        "Create a concise but complete study summary of the entire document.\n"
        "- Preserve important concepts, definitions, formulas, examples, lists, "
        "classifications, and likely exam points.\n"
        "- Remove repetition and filler.\n"
        "- Organize by topic with clear Markdown headings and bullets.\n"
        "- Optimize for fast revision: what must the student remember?\n"
        "- Do not turn this into a long tutorial."
    ),
    "explanation": (
        "AI Explanation", 16384,
        "Teach the entire document clearly to a university student.\n"
        "- Follow the document's logical order.\n"
        "- Explain concepts, formulas, notation, terminology, and why each "
        "topic matters.\n"
        "- Include useful examples and connect related topics.\n"
        "- Be substantially more detailed than a summary while preserving "
        "technical accuracy.\n"
        "- Use clean Markdown headings."
    ),
    "deep_explanation": (
        "AI Deep Explanation", 32768,
        "Explain the entire document deeply from first principles for a student "
        "encountering it for the first time.\n"
        "- Start with intuitive, simple language, then introduce the exact "
        "technical terminology.\n"
        "- Explain WHY before HOW where appropriate.\n"
        "- Use accurate analogies and everyday scenarios, then explicitly "
        "connect each analogy back to the technical concept.\n"
        "- Explain formulas symbol-by-symbol with step-by-step worked examples.\n"
        "- Include common mistakes, relationships between concepts, and "
        "memory aids where useful.\n"
        "- Do not be childish; remain technically rigorous.\n"
        "- Use detailed, well-structured Markdown."
    ),
    "real_world_examples": (
        "AI Real-World Examples", 16384,
        "Show how the document's topics appear in the real world. Focus ONLY "
        "on concrete scenarios, case studies, and worked examples; do not "
        "re-teach the theory.\n"
        "- Start with \"## Topic map\": a Markdown table with columns "
        "\"Topic\" (as named in the document, with page numbers) and "
        "\"Real-world examples\" (the example titles for that topic).\n"
        "- Then, for every major topic in source order, write a section "
        "\"## <Topic name> (p. N)\" containing 1–3 examples, each under a "
        "\"### Example: <short title>\" heading with:\n"
        "  - **Scenario** – a specific, realistic situation (industry, "
        "everyday life, research, engineering, business, medicine, etc.).\n"
        "  - **How the concept applies** – walk through the scenario using "
        "the document's exact terms, formulas, and notation; include "
        "realistic numbers and the calculation when the topic is quantitative.\n"
        "  - **Mapping to the theory** – bullet list pairing each element "
        "of the scenario with the corresponding concept/term/formula from "
        "the document.\n"
        "  - **Try it yourself** – one short variation of the scenario for "
        "the student to reason about (no answer needed).\n"
        "- Prefer well-known, verifiable examples; when inventing a "
        "scenario, keep it plausible and clearly hypothetical.\n"
        "- Cover every topic in the document; do not skip minor topics—"
        "give them at least one brief example.\n"
        "- Do not add introductions, summaries, or theory recaps outside "
        "the structure above."
    ),
    "slideshow": (
        "AI Slideshow", 16384,
        "Create a presentation for studying the entire document, in source order.\n"
        "- Use one focused idea per slide, with a short descriptive title, "
        "concise bullet points, and a formula or example when useful.\n"
        "- Cover all important concepts, definitions, relationships, and "
        "likely exam points without inventing content.\n"
        "- Aim for 8–20 slides, but use more if needed to cover a long PDF.\n"
        "- Start every slide with a Markdown heading such as "
        "\"# Slide 1: Introduction\".\n"
        "- Put exactly <!-- slide --> on its own line between slides. "
        "Do not put this marker elsewhere or add text outside the slides.\n"
        "- Keep each slide readable on a phone; avoid long paragraphs."
    ),
}


def draft_pdf_study_material(db, args):
    m = material_row(db, args["material_id"])
    if m["mime_type"] != "application/pdf":
        raise ToolError("Only PDF lesson materials can be drafted.")
    kind = args["type"]
    if kind not in PDF_PROMPTS:
        raise ToolError(f"type must be one of {MATERIAL_TYPES}.")
    model = args.get("model", "gemini-3.8-flash")
    if model not in {"gemini-3.8-flash", "gemini-3.5-flash", "gemini-2.5-flash"}:
        raise ToolError("Choose a supported Gemini study model.")
    stored = m["stored_file_name"]
    if not stored or os.path.basename(stored) != stored:
        raise ToolError("Invalid stored PDF filename.")
    path = os.path.join(FILES_ROOT, "lessons", m["lesson_id"], stored)
    if not os.path.isfile(path):
        raise ToolError("The PDF is missing on this device. Sync the file first.")
    size = os.path.getsize(path)
    if size > 50_000_000:
        raise ToolError("PDF exceeds Gemini's 50 MB inline PDF limit.")
    title, output_tokens, instruction = PDF_PROMPTS[kind]
    request = f"GENERATION REQUEST: {title}\n\n{instruction}"
    if not args.get("apply", False):
        return (
            "PREVIEW — nothing sent or saved yet. Call with apply=true only "
            "after approval to send this original PDF to Google Gemini:\n"
            f"- {m['subject_name']} › {m['lesson_name']} › {m['title']} "
            f"({size / 1048576:.1f} MiB)\n"
            f"- {title}, model {model}, output limit {output_tokens} tokens\n"
            "- Uses the app's PDF study system and type instructions; PDF "
            "attached as application/pdf (not extracted text).\n"
            "- Returns an unsaved draft; review it and preview "
            "add_study_material separately before saving."
        )
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ToolError("Set GEMINI_API_KEY for the MCP server before sending PDFs.")
    with open(path, "rb") as pdf:
        data = pdf.read()
    if not data.startswith(b"%PDF-"):
        raise ToolError("The stored file is not a valid PDF header.")
    body = {
        "contents": [{"role": "user", "parts": [
            {"text": PDF_PROMPT_SYSTEM},
            {"text": f"DOCUMENT: {m['title']}"},
            {"inlineData": {"mimeType": "application/pdf",
                            "data": base64.b64encode(data).decode("ascii")}},
            {"text": request},
        ]}],
        "generationConfig": {"maxOutputTokens": output_tokens,
                             "thinkingConfig": {"thinkingBudget": 0}},
    }
    url = ("https://generativelanguage.googleapis.com/v1beta/models/"
           f"{model}:generateContent")
    http_request = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
        method="POST",
    )
    try:
        with urllib.request.urlopen(http_request, timeout=300) as response:
            raw = response.read(2 * 1024 * 1024 + 1)
    except urllib.error.HTTPError as error:
        raise ToolError(f"Gemini rejected the PDF request (HTTP {error.code}).") from None
    except urllib.error.URLError:
        raise ToolError("Gemini could not be reached; no material was saved.") from None
    if len(raw) > 2 * 1024 * 1024:
        raise ToolError("Gemini's response exceeded the draft size limit.")
    try:
        result = json.loads(raw)
        parts = result["candidates"][0]["content"]["parts"]
        markdown = "\n".join(part["text"] for part in parts if "text" in part).strip()
    except (ValueError, KeyError, IndexError, TypeError):
        raise ToolError("Gemini returned an unreadable result; nothing saved.") from None
    if not markdown:
        raise ToolError("Gemini returned no study material; nothing saved.")
    return f"UNSAVED {title} draft for {m['title']} ({model}):\n\n{markdown}"


def add_study_material(db, args):
    m = material_row(db, args["material_id"])
    kind = args["type"]
    if kind not in MATERIAL_TYPES:
        raise ToolError(f"type must be one of {MATERIAL_TYPES}.")
    content = args["markdown"].strip()
    if not content:
        raise ToolError("markdown is empty.")
    version = latest_version(
        db, "pdf_ai_materials", "material_id = ? AND type = ?", m["id"], kind
    ) + 1
    preview = _preview(args, [
        f"{kind} v{version} ({len(content):,} chars) on \"{m['title']}\" "
        f"({m['subject_name']} › {m['lesson_name']})"
    ])
    if preview:
        return preview
    with Write(db):
        db.execute(
            "INSERT INTO pdf_ai_materials (id, material_id, type, content, "
            "version, generated_at, provider, model, source_fingerprint) VALUES "
            "(?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (new_id(), m["id"], kind, content, version, now(), PROVIDER, MODEL,
             hashlib.sha256(content.encode()).hexdigest()),
        )
    return saved_message(f"{kind} v{version} on {m['title']}")


def _lesson(db, lesson_id):
    return require(
        one(
            db,
            "SELECT l.*, s.name AS subject_name FROM lessons l JOIN subjects s "
            "ON s.id = l.subject_id WHERE l.id = ?",
            lesson_id,
        ),
        f"Lesson {lesson_id}",
    )


def add_flashcards(db, args):
    lesson = _lesson(db, args["lesson_id"])
    existing = {
        r[0].strip().lower() for r in rows(
            db, "SELECT front FROM flashcards WHERE lesson_id = ?", lesson["id"])
    }
    cards, skipped = [], 0
    for card in args["cards"]:
        front = str(card.get("front", "")).strip()
        back = str(card.get("back", "")).strip()
        if not front or not back:
            raise ToolError("Every card needs a front and a back.")
        if front.lower() in existing and not args.get("allow_duplicates"):
            skipped += 1
            continue
        existing.add(front.lower())
        cards.append((front, back))
    preview = _preview(args, [
        f"{len(cards)} flashcard(s) on lesson \"{lesson['name']}\""
        + (f"; {skipped} skipped (same front exists)" if skipped else "")
    ])
    if preview:
        return preview
    if not cards:
        return "Nothing to add (all fronts already exist)."
    t = now()
    with Write(db):
        for front, back in cards:
            delta = markdown_to_delta(back)
            plain = delta_plain_text(delta)
            db.execute(
                "INSERT INTO flashcards (id, subject_id, lesson_id, front, back, "
                "back_plain_text, created_at, updated_at) VALUES "
                "(?, ?, ?, ?, ?, ?, ?, ?)",
                (new_id(), lesson["subject_id"], lesson["id"], front[:2000],
                 delta, plain or None, t, t),
            )
    return saved_message(f"{len(cards)} flashcard(s) on {lesson['name']}")


def add_note(db, args):
    lesson_id, subject_id = args.get("lesson_id"), args.get("subject_id")
    if bool(lesson_id) == bool(subject_id):
        raise ToolError("Give exactly one of lesson_id or subject_id.")
    if lesson_id:
        owner = _lesson(db, lesson_id)["name"]
        where, value = "lesson_id = ?", lesson_id
    else:
        owner = require(
            one(db, "SELECT name FROM subjects WHERE id = ?", subject_id),
            "Subject",
        )["name"]
        where, value = "subject_id = ?", subject_id
    title = args["title"].strip()[:200]
    if not title or not args["markdown"].strip():
        raise ToolError("title and markdown are required.")
    preview = _preview(args, [f"Note \"{title}\" on \"{owner}\""])
    if preview:
        return preview
    delta = markdown_to_delta(args["markdown"])
    plain = delta_plain_text(delta)
    t = now()
    with Write(db):
        order = (one(db, f"SELECT MAX(sort_order) FROM study_notes WHERE {where}",
                     value)[0])
        db.execute(
            "INSERT INTO study_notes (id, subject_id, lesson_id, title, content, "
            "plain_text_content, sort_order, created_at, updated_at) VALUES "
            "(?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (new_id(), subject_id, lesson_id, title, delta, plain or None,
             (order if order is not None else -1) + 1, t, t),
        )
    return saved_message(f"note \"{title}\"")


_TYPES = {
    "mcq": "mcq", "multiple_choice": "mcq", "true_false": "true_false",
    "boolean": "true_false", "short_answer": "short_answer",
    "fill_blank": "fill_blank", "fill_in_the_blank": "fill_blank",
}
_DIFFICULTIES = {"easy", "medium", "hard", "mixed"}


def _question(q, n):
    label = f"Question {n}"
    text = str(q.get("question", "")).strip()
    kind = _TYPES.get(str(q.get("type", "short_answer")).lower())
    if not text or not kind:
        raise ToolError(f"{label}: needs question text and a valid type.")
    correct = q.get("correct", q.get("answer"))
    options = []
    if kind == "mcq":
        options = [str(o).strip() for o in q.get("options") or []]
        if len(options) != 4 or not all(options):
            raise ToolError(f"{label}: MCQ needs exactly 4 options.")
        if isinstance(correct, str) and correct.strip().upper() in "ABCD" \
                and len(correct.strip()) == 1:
            correct = "ABCD".index(correct.strip().upper())
        if not isinstance(correct, int) or not 0 <= correct <= 3:
            raise ToolError(f"{label}: correct must be 0-3 or A-D.")
        stored = str(correct)
    elif kind == "true_false":
        if isinstance(correct, str):
            correct = {"true": True, "false": False}.get(correct.strip().lower())
        if not isinstance(correct, bool):
            raise ToolError(f"{label}: correct must be true or false.")
        stored = "true" if correct else "false"
    else:
        stored = str(correct or "").strip()
        if not stored:
            raise ToolError(f"{label}: needs an answer.")
    difficulty = str(q.get("difficulty", "medium")).lower()
    return {
        "type": kind, "question": text, "correct": stored, "options": options,
        "is_true": correct if kind == "true_false" else None,
        "explanation": str(q.get("explanation", "")).strip() or None,
        "difficulty": difficulty if difficulty in _DIFFICULTIES else "medium",
        "page": q.get("page") if isinstance(q.get("page"), int) else None,
    }


def add_quiz(db, args):
    lesson = _lesson(db, args["lesson_id"])
    material_id = args.get("material_id")
    if material_id:
        m = material_row(db, material_id)
        if m["lesson_id"] != lesson["id"]:
            raise ToolError("That material belongs to a different lesson.")
    questions = [_question(q, i + 1) for i, q in enumerate(args["questions"])]
    if not questions:
        raise ToolError("Add at least one question.")
    title = (args.get("title") or "Quiz").strip()[:200]
    types = {q["type"] for q in questions}
    difficulty = str(args.get("difficulty", "mixed")).lower()
    preview = _preview(args, [
        f"Quiz \"{title}\" with {len(questions)} question(s) "
        f"({', '.join(sorted(types))}) on lesson \"{lesson['name']}\""
    ])
    if preview:
        return preview
    t = now()
    set_id = new_id()
    with Write(db):
        db.execute(
            "INSERT INTO question_sets (id, material_id, lesson_id, subject_id, "
            "title, source_type, question_count, question_type, difficulty, "
            "ai_provider, ai_model, created_at, updated_at) VALUES "
            "(?, ?, ?, ?, ?, 'manual_entry', ?, ?, ?, ?, ?, ?, ?)",
            (set_id, material_id, lesson["id"], lesson["subject_id"], title,
             len(questions), types.pop() if len(types) == 1 else "mixed",
             difficulty if difficulty in _DIFFICULTIES else "mixed",
             PROVIDER, MODEL, t, t),
        )
        for position, q in enumerate(questions):
            qid = new_id()
            db.execute(
                "INSERT INTO quiz_questions (id, question_set_id, type, question, "
                "correct_answer, explanation, difficulty, source_page, position, "
                "created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (qid, set_id, q["type"], q["question"], q["correct"],
                 q["explanation"], q["difficulty"], q["page"], position, t, t),
            )
            labels = q["options"] if q["type"] == "mcq" else (
                ["True", "False"] if q["type"] == "true_false" else []
            )
            for i, label in enumerate(labels):
                correct = (
                    i == int(q["correct"]) if q["type"] == "mcq"
                    else (i == 0) == q["is_true"]
                )
                db.execute(
                    "INSERT INTO quiz_question_options (id, question_id, "
                    "option_text, is_correct, position) VALUES (?, ?, ?, ?, ?)",
                    (new_id(), qid, label, 1 if correct else 0, i),
                )
    return saved_message(f"quiz \"{title}\" ({len(questions)} questions)")


def _insert_review(db, subject_id, material_id, part, content, fingerprint):
    where = "subject_id = ? AND part = ? AND " + (
        "material_id IS NULL" if material_id is None else "material_id = ?"
    )
    params = [subject_id, part] + ([] if material_id is None else [material_id])
    version = latest_version(db, "course_review_entries", where, *params) + 1
    db.execute(
        "INSERT INTO course_review_entries (id, subject_id, material_id, part, "
        "content, version, source_fingerprint, provider, model, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (new_id(), subject_id, material_id, part, content.strip(), version,
         fingerprint, PROVIDER, MODEL, now()),
    )
    return version


def set_course_review_section(db, args):
    m = material_row(db, args["material_id"])
    if m["mime_type"] != "application/pdf":
        raise ToolError("Course Review sections belong to PDFs.")
    parts = {p: args[p].strip() for p in SECTION_PARTS
             if isinstance(args.get(p), str) and args[p].strip()}
    if not parts:
        raise ToolError("Give at least one of summary, explanation, "
                        "deep_explanation.")
    preview = _preview(args, [
        f"Course Review section for \"{m['title']}\" "
        f"({m['subject_name']} › {m['lesson_name']}): {', '.join(parts)} "
        "as new versions"
    ])
    if preview:
        return preview
    fingerprint = section_fingerprint(db, m)
    with Write(db):
        versions = [
            f"{p} v{_insert_review(db, m['subject_id'], m['id'], p, c, fingerprint)}"
            for p, c in parts.items()
        ]
    return saved_message(f"{', '.join(versions)} for {m['title']}")


def set_course_overview(db, args):
    subject = require(
        one(db, "SELECT * FROM subjects WHERE id = ?", args["subject_id"]),
        "Subject",
    )
    parts = {p: args[p].strip() for p in ("big_picture", "examples")
             if isinstance(args.get(p), str) and args[p].strip()}
    if not parts:
        raise ToolError("Give big_picture and/or examples.")
    preview = _preview(args, [
        f"Course Review {', '.join(parts)} for \"{subject['name']}\" "
        "as new versions"
    ])
    if preview:
        return preview
    fingerprint = overview_fingerprint(db, subject["id"])
    with Write(db):
        versions = [
            f"{p} v{_insert_review(db, subject['id'], None, p, c, fingerprint)}"
            for p, c in parts.items()
        ]
    return saved_message(f"{', '.join(versions)} for {subject['name']}")


def add_book_item(db, args):
    book = require(
        one(db, "SELECT * FROM reference_books WHERE id = ?", args["book_id"]),
        "Book",
    )
    kind = args["kind"]
    if kind not in ("brief", "summary", "explanation"):
        raise ToolError("kind must be brief, summary or explanation.")
    chapter = None
    if args.get("chapter_id"):
        chapter = require(
            one(db, "SELECT * FROM reference_book_chapters WHERE id = ? AND "
                "book_id = ?", args["chapter_id"], book["id"]),
            "Chapter",
        )
        scope, start, end = chapter["id"], chapter["start_page"], chapter["end_page"]
    else:
        start, end = int(args.get("start_page", 0)), int(args.get("end_page", 0))
        if not 1 <= start <= end <= book["page_count"]:
            raise ToolError("Give chapter_id, or a valid start_page/end_page.")
        scope = f"pages:{start}-{end}"
    content = args["markdown"].strip()
    if not content:
        raise ToolError("markdown is empty.")
    version = latest_version(
        db, "reference_book_ai_items", "book_id = ? AND kind = ? AND scope_key = ?",
        book["id"], kind, scope,
    ) + 1
    target = chapter["title"] if chapter else f"pages {start}-{end}"
    preview = _preview(args, [f"{kind} v{version} for {target} in \"{book['title']}\""])
    if preview:
        return preview
    with Write(db):
        db.execute(
            "INSERT INTO reference_book_ai_items (id, book_id, chapter_id, kind, "
            "scope_key, start_page, end_page, content, version, provider, model, "
            "created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (new_id(), book["id"], chapter["id"] if chapter else None, kind, scope,
             start, end, content, version, PROVIDER, MODEL, now()),
        )
    return saved_message(f"{kind} v{version} for {target}")


def set_lecture_book_links(db, args):
    book = require(
        one(db, "SELECT * FROM reference_books WHERE id = ?", args["book_id"]),
        "Book",
    )
    m = material_row(db, args["material_id"])
    ranges = []
    for r in args["ranges"]:
        start, end = int(r["start"]), int(r.get("end", r["start"]))
        priority = r.get("priority", "skim")
        if priority not in ("must", "skim", "optional"):
            raise ToolError("priority must be must, skim or optional.")
        if not 1 <= start <= end <= book["page_count"]:
            raise ToolError(f"Range {start}-{end} is outside the book.")
        ranges.append((start, end, priority, r.get("reason")))
    preview = _preview(args, [
        f"Replace the book pages for \"{m['title']}\" in \"{book['title']}\" with: "
        + (", ".join(f"pp. {s}-{e} ({p})" for s, e, p, _ in ranges) or "none")
    ])
    if preview:
        return preview
    with Write(db):
        db.execute(
            "DELETE FROM reference_book_links WHERE book_id = ? AND material_id = ?",
            (book["id"], m["id"]),
        )
        for start, end, priority, reason in ranges:
            db.execute(
                "INSERT INTO reference_book_links (id, book_id, material_id, "
                "start_page, end_page, priority, reason, done, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)",
                (new_id(), book["id"], m["id"], start, end, priority, reason, now()),
            )
    return saved_message(f"{len(ranges)} page range(s) for {m['title']}")


def set_chapter_status(db, args):
    chapter = require(
        one(db, "SELECT * FROM reference_book_chapters WHERE id = ?",
            args["chapter_id"]),
        "Chapter",
    )
    status = args["status"]
    if status not in ("notStarted", "reading", "done"):
        raise ToolError("status must be notStarted, reading or done.")
    preview = _preview(args, [f"Mark \"{chapter['title']}\" as {status}"])
    if preview:
        return preview
    with Write(db):
        db.execute(
            "UPDATE reference_book_chapters SET status = ?, updated_at = ? "
            "WHERE id = ?",
            (status, now(), chapter["id"]),
        )
    return saved_message(f"\"{chapter['title']}\" is {status}")


def add_lesson(db, args):
    subject = require(
        one(db, "SELECT * FROM subjects WHERE id = ?", args["subject_id"]),
        "Subject",
    )
    name = args["name"].strip()[:200]
    if not name:
        raise ToolError("name is required.")
    order = one(
        db, "SELECT MAX(sort_order) FROM lessons WHERE subject_id = ?",
        subject["id"],
    )[0]
    order = (order if order is not None else -1) + 1
    lines = [
        f"Lesson \"{name}\" in \"{subject['name']}\" (sort order {order})"]
    if one(db, "SELECT id FROM lessons WHERE subject_id = ? AND name = ?",
           subject["id"], name):
        lines.append(f"warning: a lesson named \"{name}\" already exists")
    preview = _preview(args, lines)
    if preview:
        return preview
    lesson_id = new_id()
    t = now()
    with Write(db):
        db.execute(
            "INSERT INTO lessons (id, subject_id, name, sort_order, "
            "progress_status, created_at, updated_at) VALUES "
            "(?, ?, ?, ?, 'notStarted', ?, ?)",
            (lesson_id, subject["id"], name, order, t, t),
        )
    return saved_message(
        f"lesson \"{name}\"") + f" lesson_id: {lesson_id}"


ATTACH_MIME = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
}


def attach_file(db, args):
    lesson = _lesson(db, args["lesson_id"])
    path = os.path.expanduser(args["path"])
    if not os.path.isfile(path):
        raise ToolError(f"No such file: {path}")
    ext = os.path.splitext(path)[1].lower()
    mime = ATTACH_MIME.get(ext)
    if mime is None:
        raise ToolError(
            "Only PDF and image files can be attached; convert it first.")
    title = (args.get("title") or os.path.basename(path)).strip()[:300]
    if not title:
        raise ToolError("title is empty.")
    size = os.path.getsize(path)
    lines = [
        f"\"{title}\" ({size / 1048576:.1f} MiB, {mime}) → "
        f"{lesson['subject_name']} › {lesson['name']}"
    ]
    if one(db, "SELECT id FROM lesson_materials WHERE lesson_id = ? AND "
               "title = ?", lesson["id"], title):
        lines.append(f"warning: \"{title}\" is already attached here")
    if size > 256 * 1048576:
        lines.append("warning: over the 256 MiB sync file limit")
    preview = _preview(args, lines)
    if preview:
        return preview
    stored = new_id() + ext
    target_dir = os.path.join(FILES_ROOT, "lessons", lesson["id"])
    os.makedirs(target_dir, exist_ok=True)
    target = os.path.join(target_dir, stored)
    order = one(
        db,
        "SELECT MAX(sort_order) FROM lesson_materials WHERE lesson_id = ?",
        lesson["id"],
    )[0]
    order = (order if order is not None else -1) + 1
    material_id = new_id()
    t = now()
    try:
        shutil.copy2(path, target)
        with Write(db):
            db.execute(
                "INSERT INTO lesson_materials (id, lesson_id, title, "
                "original_file_name, stored_file_name, mime_type, sort_order, "
                "created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (material_id, lesson["id"], title, os.path.basename(path),
                 stored, mime, order, t, t),
            )
    except BaseException:
        try:
            os.remove(target)
        except OSError:
            pass
        raise
    return saved_message(
        f"\"{title}\" on {lesson['name']}") + f" material_id: {material_id}"


# ── Tool registry ───────────────────────────────────────────────────────

APPLY = {"type": "boolean",
         "description": "false (default) previews; true saves."}


def _schema(props, required):
    return {"type": "object", "properties": props, "required": required,
            "additionalProperties": False}


S = {"type": "string"}
I = {"type": "integer"}
MD = {"type": "string", "description": "Markdown"}

TOOLS = {
    "library_overview": (
        library_overview,
        "List classes → subjects → lessons → materials (with ids and existing "
        "AI materials) and reference books. Start here to find ids.",
        _schema({}, []),
    ),
    "get_lecture": (
        get_lecture,
        "Everything about one lecture PDF/material: lesson, subject, AI "
        "material versions, notes, flashcard fronts, quizzes, Course Review "
        "parts and matched book pages.",
        _schema({"material_id": S}, ["material_id"]),
    ),
    "read_study_material": (
        read_study_material,
        "Read the latest AI study material of a type for a material.",
        _schema({"material_id": S, "type": {"type": "string", "enum": MATERIAL_TYPES}},
                ["material_id", "type"]),
    ),
    "read_pdf_text": (
        read_pdf_text,
        "Read page text of a lecture PDF (material_id) or reference book "
        "(book_id), at most 120 pages per call.",
        _schema({"material_id": S, "book_id": S, "start_page": I, "end_page": I,
                 "max_chars": I}, []),
    ),
    "get_course_review": (
        get_course_review,
        "A subject's Course Review: every PDF's section status (outdated if "
        "its source changed), plus big picture/examples.",
        _schema({"subject_id": S, "include_content": {"type": "boolean"}},
                ["subject_id"]),
    ),
    "get_book": (
        get_book,
        "A reference book's chapters (ids, pages, status), AI items and "
        "linked subjects.",
        _schema({"book_id": S}, ["book_id"]),
    ),
    "search_book": (
        search_book,
        "Keyword-search a reference book's pages on this computer.",
        _schema({"book_id": S, "query": S, "limit": I}, ["book_id", "query"]),
    ),
    "add_lesson": (
        add_lesson,
        "Create a lesson in a subject (returns lesson_id for attach_file).",
        _schema({"subject_id": S, "name": S, "apply": APPLY},
                ["subject_id", "name"]),
    ),
    "attach_file": (
        attach_file,
        "Copy a PDF or image into the vault and attach it to a lesson "
        "(returns material_id).",
        _schema({"lesson_id": S, "path": S, "title": S, "apply": APPLY},
                ["lesson_id", "path"]),
    ),
    "draft_pdf_study_material": (
        draft_pdf_study_material,
        "Preview an original PDF upload to Gemini; apply=true sends the file "
        "as application/pdf and returns unsaved study Markdown. Never saves "
        "the draft; review and use add_study_material to save it.",
        _schema({"material_id": S, "type": {"type": "string", "enum": MATERIAL_TYPES},
                 "model": {"type": "string", "enum": ["gemini-3.8-flash",
                                                    "gemini-3.5-flash",
                                                    "gemini-2.5-flash"]},
                 "apply": {"type": "boolean", "description":
                           "false previews locally; true sends the PDF to Gemini "
                           "but never writes to the library."}},
                ["material_id", "type"]),
    ),
    "add_study_material": (
        add_study_material,
        "Add an AI study material to a lecture PDF as a new version (never "
        "replaces). Types: summary, explanation, deep_explanation, "
        "real_world_examples, slideshow (slides separated by <!-- slide -->).",
        _schema({"material_id": S, "type": {"type": "string", "enum": MATERIAL_TYPES},
                 "markdown": MD, "apply": APPLY},
                ["material_id", "type", "markdown"]),
    ),
    "add_flashcards": (
        add_flashcards,
        "Add flashcards to a lesson; fronts that already exist are skipped.",
        _schema({
            "lesson_id": S,
            "cards": {"type": "array", "items": _schema(
                {"front": S, "back": MD}, ["front", "back"])},
            "allow_duplicates": {"type": "boolean"}, "apply": APPLY,
        }, ["lesson_id", "cards"]),
    ),
    "add_note": (
        add_note,
        "Add a rich-text note (from Markdown) to a lesson or a subject.",
        _schema({"lesson_id": S, "subject_id": S, "title": S, "markdown": MD,
                 "apply": APPLY}, ["title", "markdown"]),
    ),
    "add_quiz": (
        add_quiz,
        "Add a quiz to a lesson. Question types: mcq (4 options, correct 0-3 "
        "or A-D), true_false (correct true/false), short_answer and "
        "fill_blank (answer text). Optional explanation, difficulty, page.",
        _schema({
            "lesson_id": S, "material_id": S, "title": S,
            "difficulty": {"type": "string", "enum": sorted(_DIFFICULTIES)},
            "questions": {"type": "array", "items": {"type": "object"}},
            "apply": APPLY,
        }, ["lesson_id", "questions"]),
    ),
    "set_course_review_section": (
        set_course_review_section,
        "Write a lecture PDF's condensed Course Review section (new versions). "
        "Depth: summary ≤250 words bullets; explanation ≤400 words reminders; "
        "deep_explanation ≤450 words core reasoning + common mistakes. "
        "Headings start at ###.",
        _schema({"material_id": S, "summary": MD, "explanation": MD,
                 "deep_explanation": MD, "apply": APPLY}, ["material_id"]),
    ),
    "set_course_overview": (
        set_course_overview,
        "Write a subject's Course Review big picture (150-300 words) and/or "
        "about 10 short course-wide examples. Write sections first so these "
        "are current.",
        _schema({"subject_id": S, "big_picture": MD, "examples": MD,
                 "apply": APPLY}, ["subject_id"]),
    ),
    "add_book_item": (
        add_book_item,
        "Add a chapter brief/summary (chapter_id) or a page-range explanation "
        "(start_page/end_page) to a reference book, as a new version. Cite "
        "pages as [p. N].",
        _schema({"book_id": S, "kind": {"type": "string",
                                         "enum": ["brief", "summary", "explanation"]},
                 "chapter_id": S, "start_page": I, "end_page": I, "markdown": MD,
                 "apply": APPLY}, ["book_id", "kind", "markdown"]),
    ),
    "set_lecture_book_links": (
        set_lecture_book_links,
        "Set which book page ranges cover a lecture PDF (replaces that "
        "lecture's ranges for this book). priority: must, skim, optional.",
        _schema({
            "book_id": S, "material_id": S,
            "ranges": {"type": "array", "items": _schema(
                {"start": I, "end": I,
                 "priority": {"type": "string", "enum": ["must", "skim", "optional"]},
                 "reason": S}, ["start"])},
            "apply": APPLY,
        }, ["book_id", "material_id", "ranges"]),
    ),
    "set_chapter_status": (
        set_chapter_status,
        "Mark a book chapter notStarted, reading or done.",
        _schema({"chapter_id": S, "status": {"type": "string",
                                               "enum": ["notStarted", "reading", "done"]},
                 "apply": APPLY}, ["chapter_id", "status"]),
    ),
}


def call_tool(name, args):
    if name not in TOOLS:
        raise ToolError(f"Unknown tool {name}.")
    db = connect()
    try:
        result = TOOLS[name][0](db, args or {})
    finally:
        db.close()
    return result if isinstance(result, str) else json.dumps(
        result, ensure_ascii=False, indent=1)


# ── MCP stdio loop ──────────────────────────────────────────────────────


def handle(message):
    method = message.get("method")
    params = message.get("params") or {}
    if method == "initialize":
        return {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "study-vault", "version": "1.0.0"},
            "instructions": (
                "Study Vault library on this computer. Find ids with "
                "library_overview. Write tools preview first; show the preview "
                "to the user and call again with apply=true only after they "
                "agree."
            ),
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [
            {"name": name, "description": desc, "inputSchema": schema}
            for name, (_, desc, schema) in TOOLS.items()
        ]}
    if method == "tools/call":
        try:
            text = call_tool(params.get("name"), params.get("arguments"))
            return {"content": [{"type": "text", "text": text}]}
        except (ToolError, KeyError, ValueError, TypeError) as error:
            detail = (f"Missing argument: {error}" if isinstance(error, KeyError)
                      else str(error))
            return {"content": [{"type": "text", "text": detail}],
                    "isError": True}
        except sqlite3.OperationalError as error:
            return {"content": [{"type": "text", "text":
                                 f"Database busy or unavailable: {error}"}],
                    "isError": True}
    raise LookupError(method)


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" not in message:
            continue  # notification
        try:
            response = {"jsonrpc": "2.0", "id": message["id"],
                        "result": handle(message)}
        except LookupError:
            response = {"jsonrpc": "2.0", "id": message["id"],
                        "error": {"code": -32601, "message": "Method not found"}}
        sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
