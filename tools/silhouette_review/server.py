#!/usr/bin/env python3
"""Silhouette Review Tool — local web server.

Usage:
    python tools/silhouette_review/server.py
    # Then open http://localhost:8765

Sources are switched at runtime via the UI or POST /api/source/{key}.
"""

from __future__ import annotations

import io
import json
import re
import sys
from pathlib import Path
from typing import Optional

import subprocess

import uvicorn
from fastapi import FastAPI, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response
from PIL import Image

INKSCAPE = "/Applications/Inkscape.app/Contents/MacOS/inkscape"

# ── Paths ─────────────────────────────────────────────────────────────────────

TOOL_DIR = Path(__file__).parent
REPO     = TOOL_DIR.parent.parent
HOME     = Path.home()

ANIMAL_SLUGS_JSON = REPO / "apps" / "mobile_flutter" / "assets" / "symbols" / "animal_slugs.json"
HTML_FILE = TOOL_DIR / "index.html"

# ── Source definitions ────────────────────────────────────────────────────────
# naming: "lower_flat" = {cc}_{slug}.ext   "upper_flat" = {CC}_{slug}.ext
#         "factory"    = {CC}/{cc}_{slug}.ext  (CC subdirs)

SOURCES: dict[str, dict] = {
    "silhouettes": {
        "label": "App silhouettes",
        "desc":  "apps/mobile_flutter/assets/silhouettes/ — bundled app SVGs",
        "svg_dir": REPO / "apps" / "mobile_flutter" / "assets" / "silhouettes",
        "png_dir": REPO / "apps" / "mobile_flutter" / "assets" / "silhouettes" / "png",
        "naming":  "lower_flat",
    },
    "symbols_animals": {
        "label": "~/symbols/animals",
        "desc":  "SVGs + exported PNGs, uppercase CC_slug naming",
        "svg_dir": HOME / "symbols" / "animals",
        "png_dir": HOME / "symbols" / "animals" / "png",
        "naming":  "upper_flat",
    },
    "symbols_plants": {
        "label": "~/symbols/plants",
        "desc":  "SVGs + exported PNGs, uppercase CC_slug naming",
        "svg_dir": HOME / "symbols" / "plants",
        "png_dir": HOME / "symbols" / "plants" / "png",
        "naming":  "upper_flat",
    },
    "symbols_landmarks": {
        "label": "~/symbols/landmarks",
        "desc":  "PNGs only, uppercase CC_slug naming",
        "svg_dir": None,
        "png_dir": HOME / "symbols" / "landmarks",
        "naming":  "upper_flat",
    },
    "factory": {
        "label": "Factory assets",
        "desc":  "tools/silhouette_factory/assets/ — CC subdirs",
        "svg_dir": REPO / "tools" / "silhouette_factory" / "assets" / "svg",
        "png_dir": REPO / "tools" / "silhouette_factory" / "assets" / "png",
        "naming":  "factory",
    },
}

# ── Vectorise (optional) ──────────────────────────────────────────────────────

_vectorise_fn = None
_vectorise_error: Optional[str] = None

try:
    sys.path.insert(0, str(REPO / "tools" / "silhouette_factory" / "scripts"))
    from vectorise import vectorise_path as _vectorise_fn  # type: ignore
except Exception as exc:
    _vectorise_error = str(exc)

# ── Country / display helpers ─────────────────────────────────────────────────

def _country_name(cc: str) -> str:
    try:
        import pycountry
        c = pycountry.countries.get(alpha_2=cc.upper())
        return c.name if c else cc.upper()
    except ImportError:
        return cc.upper()

def _display_name(slug: str) -> str:
    return slug.replace("_", " ").title()

# ── animal_slugs lookup ───────────────────────────────────────────────────────

_animal_slugs: dict[str, dict] = {}
if ANIMAL_SLUGS_JSON.exists():
    _animal_slugs = json.loads(ANIMAL_SLUGS_JSON.read_text())

_animal_slug_set = {f"{cc.lower()}_{v['slug']}"       for cc, v in _animal_slugs.items() if v.get("slug")}
_plant_slug_set  = {f"{cc.lower()}_{v['plant_slug']}" for cc, v in _animal_slugs.items() if v.get("plant_slug")}
_animal_name_map = {f"{cc.lower()}_{v['slug']}":       v.get("name", "")       for cc, v in _animal_slugs.items() if v.get("slug")}
_plant_name_map  = {f"{cc.lower()}_{v['plant_slug']}": v.get("plant_name", "") for cc, v in _animal_slugs.items() if v.get("plant_slug")}

# ── Record builder ────────────────────────────────────────────────────────────

def _parse_stem(stem: str, naming: str) -> tuple[str, str] | None:
    """Returns (cc_upper, slug) or None."""
    if naming == "lower_flat":
        m = re.match(r'^([a-z]{2})_(.+)$', stem)
        if m:
            return m.group(1).upper(), m.group(2)
    else:  # upper_flat or factory (factory stems are inside CC subdirs)
        m = re.match(r'^([A-Za-z]{2})_(.+)$', stem)
        if m:
            return m.group(1).upper(), m.group(2)
    return None

def _categorize(cc: str, slug: str, source_key: str) -> tuple[str, str, bool]:
    """Returns (category, display_name, in_app)."""
    id_ = f"{cc.lower()}_{slug}"
    if id_ in _animal_slug_set:
        return "animal", _animal_name_map.get(id_) or _display_name(slug), source_key == "silhouettes"
    if id_ in _plant_slug_set:
        return "plant",  _plant_name_map.get(id_)  or _display_name(slug), source_key == "silhouettes"
    # Partial match by country
    cd = _animal_slugs.get(cc.upper(), {})
    if cd.get("slug") and slug in cd["slug"]:
        return "animal", cd.get("name") or _display_name(slug), source_key == "silhouettes"
    if cd.get("plant_slug") and slug in cd["plant_slug"]:
        return "plant",  cd.get("plant_name") or _display_name(slug), source_key == "silhouettes"
    # Heuristic: if source is landmarks, classify as landmark
    if "landmark" in source_key:
        return "landmark", _display_name(slug), False
    return "animal", _display_name(slug), source_key == "silhouettes"


def _build_records(source_key: str) -> list[dict]:
    src = SOURCES[source_key]
    records: dict[str, dict] = {}

    def upsert(cc: str, slug: str, rel_path: str, kind: str):
        id_ = f"{cc.lower()}_{slug.lower()}"
        url  = f"/api/file/{source_key}/{rel_path}"
        if id_ not in records:
            cat, name, in_app = _categorize(cc, slug, source_key)
            records[id_] = {
                "id": id_,
                "display_name": name,
                "country":  _country_name(cc),
                "iso_code": cc.upper(),
                "category": cat,
                "in_app":   in_app,
                "has_svg":  kind == "svg",
                "has_png":  kind == "png",
                "svg_url":  url if kind == "svg" else None,
                "png_url":  url if kind == "png" else None,
            }
        else:
            if kind == "svg":
                records[id_]["has_svg"] = True
                records[id_]["svg_url"] = url
            else:
                records[id_]["has_png"] = True
                records[id_]["png_url"] = url

    naming = src["naming"]

    for kind, dir_key, dir_naming in [("svg", "svg_dir", naming), ("png", "png_dir", naming)]:
        ext = f".{kind}"
        d   = src.get(dir_key)
        if not d or not Path(d).exists():
            continue
        pattern = f"*/*{ext}" if dir_naming == "factory" else f"*{ext}"

        for f in sorted(Path(d).glob(pattern)):
            parsed = _parse_stem(f.stem, dir_naming)
            if not parsed:
                continue
            cc, slug = parsed
            rel = str(f.relative_to(Path(d)))
            upsert(cc, slug, rel, kind)

    return sorted(records.values(), key=lambda r: (r["country"], r["display_name"]))


def _source_counts(source_key: str) -> dict[str, int]:
    src = SOURCES[source_key]
    result = {"svg_count": 0, "png_count": 0}
    naming = src["naming"]
    for kind, dir_key in [("svg", "svg_dir"), ("png", "png_dir")]:
        d = src.get(dir_key)
        if not d or not Path(d).exists():
            continue
        pattern = "*/*." + kind if naming == "factory" else "*." + kind
        result[f"{kind}_count"] += len(list(Path(d).glob(pattern)))
    return result


# ── Global state ──────────────────────────────────────────────────────────────

_current_source: str = "silhouettes"
_all: list[dict] = []
_by_id: dict[str, dict] = {}

def _rebuild():
    global _all, _by_id
    _all   = _build_records(_current_source)
    _by_id = {r["id"]: r for r in _all}

_rebuild()

# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(title="Silhouette Review Tool", docs_url=None, redoc_url=None)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/", response_class=HTMLResponse)
def index():
    return HTML_FILE.read_text(encoding="utf-8")


@app.get("/api/status")
def status():
    return JSONResponse({
        "vectorise_available": _vectorise_fn is not None,
        "vectorise_error":     _vectorise_error,
        "current_source":      _current_source,
        "total":    len(_all),
        "with_svg": sum(1 for m in _all if m["has_svg"]),
        "with_png": sum(1 for m in _all if m["has_png"]),
    })


# ── Source management ─────────────────────────────────────────────────────────

@app.get("/api/sources")
def list_sources():
    out = []
    for key, src in SOURCES.items():
        counts = _source_counts(key)
        out.append({
            "key":   key,
            "label": src["label"],
            "desc":  src["desc"],
            "active": key == _current_source,
            **counts,
        })
    return JSONResponse(out)


@app.get("/api/source")
def get_source():
    src = SOURCES[_current_source]
    return JSONResponse({"key": _current_source, "label": src["label"], "desc": src["desc"]})


@app.post("/api/source/{key}")
def set_source(key: str):
    global _current_source
    if key not in SOURCES:
        raise HTTPException(404, f"Unknown source '{key}'")
    _current_source = key
    _rebuild()
    return JSONResponse({
        "key":     _current_source,
        "label":   SOURCES[key]["label"],
        "total":   len(_all),
        "with_svg": sum(1 for m in _all if m["has_svg"]),
        "with_png": sum(1 for m in _all if m["has_png"]),
    })


# ── File serving ──────────────────────────────────────────────────────────────

@app.get("/api/file/{source_key}/{filepath:path}")
def serve_file(source_key: str, filepath: str):
    if source_key not in SOURCES:
        raise HTTPException(404, "Unknown source")
    src = SOURCES[source_key]
    ext = Path(filepath).suffix.lower()
    if ext == ".svg":
        d = src.get("svg_dir")
    elif ext == ".png":
        d = src.get("png_dir")
    else:
        raise HTTPException(415, "Only SVG and PNG supported")
    if not d:
        raise HTTPException(404, "Source has no directory for this file type")
    path = Path(d) / filepath
    if not path.exists():
        raise HTTPException(404, "File not found")
    mt = "image/svg+xml" if ext == ".svg" else "image/png"
    return Response(path.read_bytes(), media_type=mt)


# ── List / filter ─────────────────────────────────────────────────────────────

@app.get("/api/silhouettes")
def list_silhouettes(
    q: str = "",
    category: str = "",
    country: str = "",
    has_files: Optional[bool] = Query(None),
    in_app:    Optional[bool] = Query(None),
):
    results = _all
    if has_files is True:
        results = [m for m in results if m["has_svg"] or m["has_png"]]
    elif has_files is False:
        results = [m for m in results if not m["has_svg"] and not m["has_png"]]
    if in_app is True:
        results = [m for m in results if m["in_app"]]
    if category:
        results = [m for m in results if m["category"] == category]
    if country:
        lc = country.lower().strip()
        if len(lc) == 2:
            results = [m for m in results if m["iso_code"].lower() == lc]
        else:
            results = [m for m in results if lc in m["country"].lower()]
    if q:
        lq = q.lower()
        results = [
            m for m in results
            if lq in m["display_name"].lower()
            or lq in m["country"].lower()
            or lq in m["iso_code"].lower()
            or lq in (m.get("category") or "").lower()
        ]
    return JSONResponse(list(results))


@app.get("/api/categories")
def list_categories():
    return JSONResponse(sorted({m["category"] for m in _all if m["category"]}))


@app.get("/api/countries")
def list_countries():
    seen: dict[str, str] = {}
    for m in _all:
        seen.setdefault(m["iso_code"], m["country"])
    return JSONResponse([
        {"iso": k, "name": v}
        for k, v in sorted(seen.items(), key=lambda x: x[1])
    ])


@app.get("/api/silhouette/{id_}")
def get_silhouette(id_: str):
    m = _by_id.get(id_)
    if not m:
        raise HTTPException(404, "Not found")
    return JSONResponse(m)


# ── Actions ───────────────────────────────────────────────────────────────────

def _factory_png(id_: str) -> Path:
    """Returns path in factory PNG dir for the given id (may not exist)."""
    m = re.match(r'^([a-z]{2})_(.+)$', id_)
    if not m:
        raise HTTPException(422, "Cannot parse id")
    cc = m.group(1).upper()
    factory_dir = SOURCES["factory"]["png_dir"]
    return Path(factory_dir) / cc / f"{id_}.png"


@app.post("/api/regenerate/{id_}")
def regenerate(
    id_: str,
    blur: float = Form(3.0),
    simplify: float = Form(0.5),
    preserve_detail: bool = Form(False),
):
    if _vectorise_fn is None:
        raise HTTPException(503, f"Vectorise not available: {_vectorise_error}")
    if id_ not in _by_id:
        raise HTTPException(404, "Not found")
    png = _factory_png(id_)
    src = SOURCES[_current_source]
    svg_dir = src.get("svg_dir")
    if not svg_dir:
        raise HTTPException(422, "Current source has no SVG dir")
    svg = Path(svg_dir) / f"{id_}.svg"
    if not png.exists():
        raise HTTPException(422, "No source PNG in factory png/ dir")
    try:
        _vectorise_fn(png, svg, blur_radius=blur, simplify=simplify,
                      preserve_detail=preserve_detail)
    except Exception as exc:
        raise HTTPException(500, f"Vectorisation failed: {exc}")
    _rebuild()
    return JSONResponse({"ok": True, **_by_id.get(id_, {})})


@app.post("/api/upload_png/{id_}")
async def upload_png(id_: str, file: UploadFile):
    if id_ not in _by_id:
        raise HTTPException(404, "Not found")
    png = _factory_png(id_)
    png.parent.mkdir(parents=True, exist_ok=True)
    data = await file.read()
    try:
        img = Image.open(io.BytesIO(data)); img.verify()
    except Exception:
        raise HTTPException(422, "Not a valid image file")
    png.write_bytes(data)
    _rebuild()
    return JSONResponse({"ok": True, **_by_id.get(id_, {})})


@app.post("/api/rotate/{id_}")
def rotate(id_: str, degrees: int = Query(90)):
    if id_ not in _by_id:
        raise HTTPException(404, "Not found")
    if degrees % 90 != 0:
        raise HTTPException(422, "degrees must be a multiple of 90")
    png = _factory_png(id_)
    if not png.exists():
        raise HTTPException(422, "No PNG in factory dir to rotate")
    img = Image.open(png)
    img.rotate(-degrees, expand=True).save(png)
    return JSONResponse({"ok": True})


@app.post("/api/export_png/{id_}")
def export_png(id_: str, width: int = Query(512)):
    """Render SVG → PNG using Inkscape and save to factory png/ dir."""
    if id_ not in _by_id:
        raise HTTPException(404, "Not found")
    item = _by_id[id_]
    if not item.get("has_svg") or not item.get("svg_url"):
        raise HTTPException(422, "No SVG available for this item")

    # Resolve SVG path from current source
    src = SOURCES[_current_source]
    svg_dir = src.get("svg_dir")
    if not svg_dir:
        raise HTTPException(422, "Current source has no SVG directory")

    # Find the SVG file — handle both flat and subdir naming
    svg_file: Path | None = None
    for ext_pattern in [f"{id_}.svg", f"{id_.upper()[:2]}_{id_[3:]}.svg"]:
        candidate = Path(svg_dir) / ext_pattern
        if candidate.exists():
            svg_file = candidate
            break
    # Also try subdir layout (factory)
    if svg_file is None:
        m = re.match(r'^([a-z]{2})_(.+)$', id_)
        if m:
            cc = m.group(1).upper()
            candidate = Path(svg_dir) / cc / f"{id_}.svg"
            if candidate.exists():
                svg_file = candidate

    if svg_file is None:
        raise HTTPException(404, "SVG file not found on disk")

    # Output to current source's png/ subdir
    png_dir = src.get("png_dir")
    if not png_dir:
        raise HTTPException(422, "Current source has no PNG directory configured")
    png = Path(png_dir) / f"{svg_file.stem}.png"
    png.parent.mkdir(parents=True, exist_ok=True)

    if not Path(INKSCAPE).exists():
        raise HTTPException(503, "Inkscape not found at " + INKSCAPE)

    result = subprocess.run(
        [INKSCAPE, "--export-type=png", f"--export-width={width}", "-o", str(png), str(svg_file)],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise HTTPException(500, f"Inkscape failed: {result.stderr[:400]}")

    _rebuild()
    return JSONResponse({"ok": True, "png_path": str(png), **_by_id.get(id_, {})})


if __name__ == "__main__":
    print("Silhouette Review Tool")
    for key, src in SOURCES.items():
        counts = _source_counts(key)
        active = " ← active" if key == _current_source else ""
        print(f"  [{key}] {src['label']} — {counts.get('svg_count',0)} SVG, {counts.get('png_count',0)} PNG{active}")
    print()
    print("Open: http://localhost:8765")
    uvicorn.run(app, host="0.0.0.0", port=8765, reload=False)
