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
#         "storage_cc" = {CC}/{slug}.ext  (CC subdirs, no cc_ filename prefix —
#                        matches the Firebase Storage layout exactly)

# Local read-only mirror of gs://roavvy-prod.firebasestorage.app/symbols/,
# i.e. exactly what AnimalSilhouetteService fetches at runtime. Synced via
# `gcloud storage cp -r gs://roavvy-prod.firebasestorage.app/symbols/<type> \
#   tools/silhouette_review/.storage_cache/`. Re-run that to refresh; this
# tool never writes back to Storage.
STORAGE_CACHE = REPO / "tools" / "silhouette_review" / ".storage_cache"

# Firebase Storage never stores the source PNG a silhouette SVG was traced
# from -- only the SVG itself. For display, the "live" sources below pull
# their PNG from the local factory staging dir, which is the actual trace
# input (see tools/silhouette_factory/scripts/vectorise.py). svg_dir and
# png_dir use different naming/layout, so png_naming overrides naming for
# the PNG half of record-building.
FACTORY_ASSETS = REPO / "tools" / "silhouette_factory" / "assets"

SOURCES: dict[str, dict] = {
    "live_animals": {
        "label": "Live app — Animals",
        "desc":  "Firebase Storage symbols/animals/ (SVG) + factory source PNG the SVG was traced from",
        "svg_dir": STORAGE_CACHE / "animals",
        "png_dir": FACTORY_ASSETS / "png",
        "naming":  "storage_cc",
        "png_naming": "factory",
    },
    "live_plants": {
        "label": "Live app — Plants",
        "desc":  "Firebase Storage symbols/plants/ (SVG) + factory source PNG the SVG was traced from",
        "svg_dir": STORAGE_CACHE / "plants",
        "png_dir": FACTORY_ASSETS / "png_plants",
        "naming":  "storage_cc",
        "png_naming": "factory",
    },
    "live_landmarks": {
        "label": "Live app — Landmarks",
        "desc":  "Firebase Storage symbols/landmarks/ (SVG) + factory source PNG the SVG was traced from",
        "svg_dir": STORAGE_CACHE / "landmarks",
        "png_dir": FACTORY_ASSETS / "png_landmarks",
        "naming":  "storage_cc",
        "png_naming": "factory",
    },
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

# ── Photo → silhouette (optional, needs rembg + onnxruntime) ──────────────────

_photo_to_silhouette_fn = None
_photo_to_silhouette_error: Optional[str] = None

try:
    import rembg  # noqa: F401  -- presence check; actual use is lazy per-call
    from photo_to_mask import photo_to_silhouette_bytes as _photo_to_silhouette_fn  # type: ignore
except Exception as exc:
    _photo_to_silhouette_error = str(exc)

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
#
# Schema: {CC: {category: [{"name": ..., "slug": ...}, ...]}} — a country can
# have multiple options per category (e.g. two candidate animals); the app
# lets the user pick among them (FlagShapeCustomiseScreen). Category is an
# open set of fixed strings ("animal", "plant", "landmark", ...); adding a
# new one needs no schema change here, only new data.

# Fallback only for a from-scratch/empty animal_slugs.json; otherwise the
# real category list is whatever keys are actually present in the data —
# adding a new category is a data change, not a code change.
_DEFAULT_CATEGORIES = ("animal", "plant", "landmark")

_animal_slugs: dict[str, dict] = {}
_categories: tuple[str, ...] = _DEFAULT_CATEGORIES
_slug_sets: dict[str, set[str]] = {}
_name_maps: dict[str, dict[str, str]] = {}


def _reload_slug_maps() -> None:
    """(Re)builds _categories/_slug_sets/_name_maps from _animal_slugs. Call
    after loading or mutating animal_slugs.json."""
    global _categories, _slug_sets, _name_maps
    found = {cat for entry in _animal_slugs.values() for cat in entry.keys()}
    _categories = tuple(sorted(found)) or _DEFAULT_CATEGORIES
    _slug_sets = {cat: set() for cat in _categories}
    _name_maps = {cat: {} for cat in _categories}
    for cc, entry in _animal_slugs.items():
        for cat in _categories:
            for opt in entry.get(cat, []):
                slug = opt.get("slug")
                if not slug:
                    continue
                id_ = f"{cc.lower()}_{slug}"
                _slug_sets[cat].add(id_)
                _name_maps[cat][id_] = opt.get("name", "")


if ANIMAL_SLUGS_JSON.exists():
    _animal_slugs = json.loads(ANIMAL_SLUGS_JSON.read_text())
_reload_slug_maps()

# ── Record builder ────────────────────────────────────────────────────────────

def _parse_stem(stem: str, naming: str, parent_dir: str = "") -> tuple[str, str] | None:
    """Returns (cc_upper, slug) or None."""
    if naming == "storage_cc":
        # CC comes from the parent directory (Firebase Storage layout);
        # the filename itself is the bare slug, no cc_ prefix.
        if len(parent_dir) == 2 and parent_dir.isalpha():
            return parent_dir.upper(), stem
        return None
    if naming == "lower_flat":
        m = re.match(r'^([a-z]{2})_(.+)$', stem)
        if m:
            return m.group(1).upper(), m.group(2)
    else:  # upper_flat or factory (factory stems are inside CC subdirs)
        m = re.match(r'^([A-Za-z]{2})_(.+)$', stem)
        if m:
            return m.group(1).upper(), m.group(2)
    return None

# Source keys whose content is the actual Firebase Storage mirror —
# i.e. genuinely what AnimalSilhouetteService fetches at runtime.
_LIVE_SOURCE_KEYS = {"live_animals", "live_plants", "live_landmarks"}

def _categorize(cc: str, slug: str, source_key: str) -> tuple[str, str, bool]:
    """Returns (category, display_name, in_app) — in_app means "is this what
    the running app actually fetches for this country", not merely bundled."""
    in_app = source_key in _LIVE_SOURCE_KEYS
    id_ = f"{cc.lower()}_{slug}"
    for cat in _categories:
        if id_ in _slug_sets[cat]:
            return cat, _name_maps[cat].get(id_) or _display_name(slug), in_app
    # Partial match by country: slug is a substring of one of this country's
    # known slugs in some category (covers minor naming drift between a
    # factory/Storage filename and the canonical slug in animal_slugs.json).
    entry = _animal_slugs.get(cc.upper(), {})
    for cat in _categories:
        for opt in entry.get(cat, []):
            known_slug = opt.get("slug", "")
            if known_slug and slug in known_slug:
                return cat, opt.get("name") or _display_name(slug), in_app
    # Heuristic: if source is landmarks, classify as landmark
    if "landmark" in source_key:
        return "landmark", _display_name(slug), False
    return "animal", _display_name(slug), in_app


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
    png_naming = src.get("png_naming", naming)

    for kind, dir_key, dir_naming in [("svg", "svg_dir", naming), ("png", "png_dir", png_naming)]:
        ext = f".{kind}"
        d   = src.get(dir_key)
        if not d or not Path(d).exists():
            continue
        pattern = f"*/*{ext}" if dir_naming in ("factory", "storage_cc") else f"*{ext}"

        for f in sorted(Path(d).glob(pattern)):
            parsed = _parse_stem(f.stem, dir_naming, parent_dir=f.parent.name)
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
    png_naming = src.get("png_naming", naming)
    for kind, dir_key, dir_naming in [("svg", "svg_dir", naming), ("png", "png_dir", png_naming)]:
        d = src.get(dir_key)
        if not d or not Path(d).exists():
            continue
        pattern = "*/*." + kind if dir_naming in ("factory", "storage_cc") else "*." + kind
        result[f"{kind}_count"] += len(list(Path(d).glob(pattern)))
    return result


# ── Global state ──────────────────────────────────────────────────────────────

_current_source: str = "live_animals"
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
        "photo_to_silhouette_available": _photo_to_silhouette_fn is not None,
        "photo_to_silhouette_error":     _photo_to_silhouette_error,
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


@app.get("/api/factory_file/{kind}/{id_}")
def serve_factory_file(kind: str, id_: str):
    """Serves the factory PNG/SVG for id_ directly, resolved from its own
    category -- independent of whichever source is currently selected in the
    sidebar. See _build_single_record for why this exists.
    """
    if kind not in ("png", "svg"):
        raise HTTPException(415, "Only png and svg supported")
    path = _factory_png(id_) if kind == "png" else _factory_svg(id_)
    if not path.exists():
        raise HTTPException(404, "File not found")
    mt = "image/png" if kind == "png" else "image/svg+xml"
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
    m = _by_id.get(id_) or _build_single_record(id_)
    if not m:
        raise HTTPException(404, "Not found")
    return JSONResponse(m)


# ── Actions ───────────────────────────────────────────────────────────────────

# category -> (factory png dir, factory svg dir, Firebase Storage type plural)
_CATEGORY_DIRS = {
    "animal":   ("png",           "svg",           "animals"),
    "plant":    ("png_plants",    "svg_plants",    "plants"),
    "landmark": ("png_landmarks", "svg_landmarks", "landmarks"),
}


def _split_id(id_: str) -> tuple[str, str]:
    """id_ is always built as f'{cc_lower}_{slug_lower}' (see upsert())."""
    m = re.match(r'^([a-z]{2})_(.+)$', id_)
    if not m:
        raise HTTPException(422, "Cannot parse id")
    return m.group(1).upper(), m.group(2)


def _category_for_id(id_: str) -> str | None:
    """Resolves category for id_, whether or not a file exists for it yet --
    checks the built records first, then falls back to animal_slugs.json
    directly (covers an option just added via /api/add_option, before its
    first PNG/SVG exists)."""
    record = _by_id.get(id_)
    if record:
        return record.get("category")
    try:
        cc, slug = _split_id(id_)
    except HTTPException:
        return None
    entry = _animal_slugs.get(cc, {})
    for cat, options in entry.items():
        if any(o.get("slug") == slug for o in options):
            return cat
    return None


def _id_is_known(id_: str) -> bool:
    """True if id_ is either a file-backed record or a registered-but-not-
    yet-uploaded option in animal_slugs.json."""
    return id_ in _by_id or _category_for_id(id_) is not None


def _build_single_record(id_: str) -> dict | None:
    """Resolves a full record for id_ directly from its own category and
    factory files -- independent of _current_source. _by_id only reflects
    whichever source is currently selected in the sidebar, so acting on an
    item whose category that source doesn't cover (e.g. adding a landmark
    while browsing "Live app — Animals") would otherwise 404 here even
    though the upload/regenerate itself succeeded. Returns None if id_ isn't
    a registered option at all.
    """
    category = _category_for_id(id_)
    if category is None:
        return None
    cc, slug = _split_id(id_)
    name = _name_maps.get(category, {}).get(id_) or _display_name(slug)
    png = _factory_png(id_)
    svg = _factory_svg(id_)
    has_png = png.exists()
    has_svg = svg.exists()
    return {
        "id": id_,
        "display_name": name,
        "country": _country_name(cc),
        "iso_code": cc,
        "category": category,
        "in_app": True,
        "has_svg": has_svg,
        "has_png": has_png,
        "svg_url": f"/api/factory_file/svg/{id_}" if has_svg else None,
        "png_url": f"/api/factory_file/png/{id_}" if has_png else None,
    }


def _category_dirs(id_: str) -> tuple[str, str, str]:
    category = _category_for_id(id_) or "animal"
    if category in _CATEGORY_DIRS:
        return _CATEGORY_DIRS[category]
    # A category beyond the original three (added via /api/add_option) --
    # same naming convention, just not one of the legacy no-suffix names.
    return f"png_{category}", f"svg_{category}", f"{category}s"


def _factory_png(id_: str) -> Path:
    """Returns path in the category-correct factory PNG dir (may not exist)."""
    cc, _ = _split_id(id_)
    png_dir, _, _ = _category_dirs(id_)
    return FACTORY_ASSETS / png_dir / cc / f"{id_}.png"


def _factory_svg(id_: str) -> Path:
    """Returns path in the category-correct factory SVG dir (may not exist)."""
    cc, _ = _split_id(id_)
    _, svg_dir, _ = _category_dirs(id_)
    return FACTORY_ASSETS / svg_dir / cc / f"{id_}.svg"


def _refresh_local_cache(id_: str, svg: Path) -> None:
    """Copies the factory SVG into the local .storage_cache mirror so the
    "Live app" source's preview reflects it immediately -- this is purely
    local (never touches Firebase Storage; see publish() for that).
    """
    cc, slug = _split_id(id_)
    _, _, storage_type = _category_dirs(id_)
    cache_dest = STORAGE_CACHE / storage_type / cc / f"{slug}.svg"
    cache_dest.parent.mkdir(parents=True, exist_ok=True)
    cache_dest.write_bytes(svg.read_bytes())


_SLUG_RE = re.compile(r'^[a-z0-9_]+$')


@app.post("/api/add_option")
def add_option(
    cc: str = Form(...),
    category: str = Form(...),
    name: str = Form(...),
    slug: str = Form(...),
):
    """Registers a brand-new option (e.g. a second candidate animal) for a
    country/category in animal_slugs.json -- no PNG/SVG exists yet; the
    returned id is immediately valid for /api/upload_png, /api/upload_photo,
    /api/regenerate, and /api/publish, same as any existing entry. category
    can be a new value entirely (e.g. "food") -- nothing here is hardcoded
    to the original three.
    """
    cc = cc.strip().upper()
    category = category.strip().lower()
    name = name.strip()
    slug = slug.strip().lower()

    if not re.match(r'^[A-Z]{2}$', cc):
        raise HTTPException(422, "Country code must be exactly 2 letters")
    if not category:
        raise HTTPException(422, "Category is required")
    if not name:
        raise HTTPException(422, "Name is required")
    if not _SLUG_RE.match(slug):
        raise HTTPException(422, "Slug must be lowercase letters, numbers, and underscores only")

    entry = _animal_slugs.setdefault(cc, {})
    options = entry.setdefault(category, [])
    if any(o.get("slug") == slug for o in options):
        raise HTTPException(409, f"{cc} already has a {category!r} option with slug {slug!r}")

    options.append({"name": name, "slug": slug})
    ANIMAL_SLUGS_JSON.write_text(
        json.dumps(_animal_slugs, indent=2, ensure_ascii=False) + "\n"
    )
    _reload_slug_maps()
    _rebuild()

    id_ = f"{cc.lower()}_{slug}"
    record = _by_id.get(id_) or _build_single_record(id_) or {}
    return JSONResponse({"ok": True, **record})


@app.post("/api/regenerate/{id_}")
def regenerate(
    id_: str,
    blur: float = Form(3.0),
    simplify: float = Form(0.5),
    preserve_detail: bool = Form(False),
):
    if _vectorise_fn is None:
        raise HTTPException(503, f"Vectorise not available: {_vectorise_error}")
    if not _id_is_known(id_):
        raise HTTPException(404, "Not found")
    png = _factory_png(id_)
    svg = _factory_svg(id_)
    if not png.exists():
        raise HTTPException(422, "No source PNG in factory png/ dir")
    try:
        _vectorise_fn(png, svg, blur_radius=blur, simplify=simplify,
                      preserve_detail=preserve_detail)
    except Exception as exc:
        raise HTTPException(500, f"Vectorisation failed: {exc}")
    _refresh_local_cache(id_, svg)
    _rebuild()
    return JSONResponse({"ok": True, **(_by_id.get(id_) or _build_single_record(id_) or {})})


@app.post("/api/upload_png/{id_}")
async def upload_png(id_: str, file: UploadFile):
    if not _id_is_known(id_):
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
    return JSONResponse({"ok": True, **(_by_id.get(id_) or _build_single_record(id_) or {})})


@app.post("/api/upload_photo/{id_}")
async def upload_photo(id_: str, file: UploadFile):
    """Takes an arbitrary photo, removes the background (rembg/U2-Net),
    flattens the subject to solid black, and writes it as the factory PNG
    mask for `id_` -- same destination as /api/upload_png, so Regenerate SVG
    and Publish work on it unchanged. First call loads a ~176MB model into
    memory (one-time per server process) and may take several seconds.
    """
    if _photo_to_silhouette_fn is None:
        raise HTTPException(503, f"Photo-to-silhouette not available: {_photo_to_silhouette_error}")
    if not _id_is_known(id_):
        raise HTTPException(404, "Not found")
    data = await file.read()
    try:
        mask_png_bytes = _photo_to_silhouette_fn(data)
    except Exception as exc:
        raise HTTPException(500, f"Background removal failed: {exc}")

    png = _factory_png(id_)
    png.parent.mkdir(parents=True, exist_ok=True)
    png.write_bytes(mask_png_bytes)
    _rebuild()
    return JSONResponse({"ok": True, **(_by_id.get(id_) or _build_single_record(id_) or {})})


@app.post("/api/publish/{id_}")
def publish(id_: str):
    """Uploads the factory SVG for `id_` to Firebase Storage (roavvy-prod) —
    the exact path AnimalSilhouetteService fetches at runtime — and refreshes
    the local .storage_cache mirror so the "Live app" view reflects it
    immediately. Requires the factory SVG to already exist (regenerate first).
    Never touches the source PNG.
    """
    if not _id_is_known(id_):
        raise HTTPException(404, "Not found")
    cc, slug = _split_id(id_)
    _, _, storage_type = _category_dirs(id_)
    svg = _factory_svg(id_)
    if not svg.exists():
        raise HTTPException(422, "No factory SVG to publish — regenerate first")

    bucket_path = f"symbols/{storage_type}/{cc}/{slug}.svg"
    gcs_uri = f"gs://roavvy-prod.firebasestorage.app/{bucket_path}"
    result = subprocess.run(
        ["gcloud", "storage", "cp", str(svg), gcs_uri],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise HTTPException(500, f"Upload failed: {result.stderr.strip()[:400]}")

    _refresh_local_cache(id_, svg)

    _rebuild()
    record = _by_id.get(id_) or _build_single_record(id_) or {}
    return JSONResponse({"ok": True, "bucket_path": bucket_path, **record})


@app.post("/api/rotate/{id_}")
def rotate(id_: str, degrees: int = Query(90)):
    if not _id_is_known(id_):
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
