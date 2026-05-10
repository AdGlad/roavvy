#!/usr/bin/env python3
"""
index_docs.py — Re-indexes local markdown docs into Firestore dev_memory_chunks.

Usage:
  python3 scripts/index_docs.py              # index all target docs
  python3 scripts/index_docs.py path/to/doc  # index specific file(s)

Chunks each file by paragraph (blank-line separated). Existing chunks for a
file are deleted before re-writing so stale content is never returned.

Schema (matches retrieve_context.py expectations):
  source_path   str  — relative path from repo root
  source_kind   str  — 'repo_markdown'
  type          str  — derived from path (architecture | project_doc | etc.)
  chunk_index   int  — paragraph index within file (0-based)
  content       str  — paragraph text
  updated_at    str  — ISO timestamp
  embedding     None — reserved for future vector search
"""

import hashlib
import sys
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import firestore

# ── Target docs to index by default ──────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent

TARGET_DOCS = [
    "docs/dev/current_state.md",
    "docs/dev/backlog_active.md",
    "docs/dev/backlog.md",
    "docs/architecture/decisions/adr-recent.md",
    "docs/architecture/decisions/adr-archive.md",
    "docs/architecture/decisions/_index.md",
    "docs/product/roadmap.md",
    "docs/product/vision.md",
]


def _doc_type(path: str) -> str:
    if "architecture/decisions" in path:
        return "architecture"
    if "architecture" in path:
        return "architecture"
    if "product/" in path:
        return "product"
    return "project_doc"


def _chunk_id(source_path: str, chunk_index: int) -> str:
    raw = f"{source_path}|{chunk_index}"
    return hashlib.md5(raw.encode()).hexdigest()


def index_file(db: firestore.Client, rel_path: str) -> int:
    abs_path = REPO_ROOT / rel_path
    if not abs_path.exists():
        print(f"  SKIP (not found): {rel_path}")
        return 0

    text = abs_path.read_text(encoding="utf-8")
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]

    # Delete existing chunks for this file.
    existing = db.collection("dev_memory_chunks").where(
        "source_path", "==", rel_path
    ).stream()
    deleted = 0
    for doc in existing:
        doc.reference.delete()
        deleted += 1

    now = datetime.now(timezone.utc).isoformat()
    doc_type = _doc_type(rel_path)

    batch = db.batch()
    written = 0
    for i, para in enumerate(paragraphs):
        if len(para) < 10:  # skip trivially short fragments
            continue
        doc_id = _chunk_id(rel_path, i)
        ref = db.collection("dev_memory_chunks").document(doc_id)
        batch.set(ref, {
            "source_path": rel_path,
            "source_kind": "repo_markdown",
            "type": doc_type,
            "chunk_index": i,
            "content": para,
            "updated_at": now,
            "embedding": None,
        })
        written += 1
        # Firestore batch limit is 500 writes.
        if written % 400 == 0:
            batch.commit()
            batch = db.batch()

    batch.commit()
    print(f"  {rel_path}: deleted {deleted} old, wrote {written} chunks")
    return written


def main():
    db = firestore.Client()

    if len(sys.argv) > 1:
        targets = sys.argv[1:]
    else:
        targets = TARGET_DOCS

    total = 0
    for path in targets:
        total += index_file(db, path)

    print(f"\nDone. {total} chunks written to dev_memory_chunks.")


if __name__ == "__main__":
    main()
