#!/usr/bin/env python3
"""
M171 — Country & Continent Outline Clip path pipeline.

Usage:
    python3 scripts/build_country_paths.py

Inputs:
    /tmp/ne_data/ne_10m_admin_0_countries.shp  (Natural Earth 10m)

Outputs:
    apps/mobile_flutter/assets/country_paths/{iso2}.json   (~240 countries)
    apps/mobile_flutter/assets/continent_paths/{key}.json  (6 continents)
    apps/mobile_flutter/assets/country_paths/_meta.json
"""

import json
import math
import os
import sys
from collections import defaultdict
from datetime import date

import fiona
from shapely.geometry import shape, MultiPolygon, Polygon
from shapely.ops import unary_union

# ── Config ─────────────────────────────────────────────────────────────────────

SHAPEFILE = '/tmp/ne_data/ne_10m_admin_0_countries.shp'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
APP_ASSETS = os.path.join(ROOT, 'apps', 'mobile_flutter', 'assets')
COUNTRY_OUT = os.path.join(APP_ASSETS, 'country_paths')
CONTINENT_OUT = os.path.join(APP_ASSETS, 'continent_paths')

# Width of normalised coordinate space (always 1000 units wide).
NORM_WIDTH = 1000.0
# Minimum height to prevent sliver shapes (Chile, etc.)
MIN_HEIGHT = 400.0

# ── Generic pipeline parameters ────────────────────────────────────────────────

# Auto-epsilon: epsilon = max(MIN, min(MAX, main_geo_w / SCALE)).
# Micro-islands (Mahé, 0.2°) → 0.005°; large countries (Canada, 87°) → 1.09°.
# This replaces almost all per-country epsilon overrides.
AUTO_EPSILON_SCALE = 80.0
AUTO_EPSILON_MIN   = 0.005   # ~500 m — floor for micro-island detail
AUTO_EPSILON_MAX   = 1.5     # ~165 km — ceiling for very wide countries

# Generic overseas-territory / distant-island filter.
# After finding the main (largest) polygon, any polygon whose centroid lies
# more than FACTOR × main-polygon-extent from the main centre is removed.
# Handles French DOM/TOM, Seychelles outer islands, etc. without per-country rules.
MAX_CANVAS_DIST_FACTOR = 3.0

# Area-fraction floor applied after the distance filter.
# Polygons below this fraction of the largest remaining polygon are dropped.
# Prevents micro-islands from generating hundreds of 3-point triangles.
DEFAULT_MIN_FRAC = 0.01

# ── Minimal per-country overrides ─────────────────────────────────────────────
# Only truly exceptional cases that the generic rules cannot handle.

# Countries that should only use mainland (filter to largest polygon).
FORCE_MAINLAND = {'ru'}

# Countries that always keep all polygons, bypassing the 80 % rule.
# Only needed when the dominant landmass is > 80 % by area but additional
# polygons are essential for recognition (Great Britain 92 %, Greek mainland 91 %).
FORCE_MULTI = {'gb', 'gr'}

# Countries with explicit bbox filtering that the generic distance filter
# cannot handle — Alaska / Hawaii are only ~57 ° from the continental US centre
# but that still falls inside 3 × 57 ° = 171 ° threshold.
BBOX_FILTER = {
    'us': {'lon_min': -128.0},
}

# Countries that need an explicit epsilon (auto formula is insufficient).
# All other countries use AUTO_EPSILON_SCALE.
EPSILON_OVERRIDES = {
    'ca': 1.5,   # Canada: Arctic archipelago; auto gives ~1.09 ° but still too many points
    'id': 0.35,  # Indonesia: many islands; auto (~0.10 °) gives too many points
    'ph': 0.35,  # Philippines: same reason as Indonesia
}

# Countries to skip (disputed territories, micro-states with no meaningful outline).
SKIP_CODES = {'-99', ''}

# Continent key mapping.
CONTINENT_KEYS = {
    'Africa': 'africa',
    'Asia': 'asia',
    'Europe': 'europe',
    'North America': 'north_america',
    'Oceania': 'oceania',
    'South America': 'south_america',
}

# ── Geometry helpers ───────────────────────────────────────────────────────────

def to_multipolygon(geom_shape) -> MultiPolygon:
    """Ensure geometry is a MultiPolygon."""
    if isinstance(geom_shape, Polygon):
        return MultiPolygon([geom_shape])
    elif isinstance(geom_shape, MultiPolygon):
        return geom_shape
    else:
        # Try to coerce
        try:
            from shapely.geometry import GeometryCollection
            polys = [g for g in geom_shape.geoms if isinstance(g, Polygon)]
            return MultiPolygon(polys)
        except Exception:
            return MultiPolygon()


def select_polygons(mp: MultiPolygon, iso2: str, force_mainland: bool, force_multi: bool, bbox_filter: dict) -> MultiPolygon:
    """Apply polygon selection rules.

    Selection order:
    1. bbox filter  — US only: remove Alaska/Hawaii (too close for distance filter).
    2. force_mainland → keep only the largest polygon (Russia).
    3. Generic canvas-distance filter — remove polygons whose centroid is more
       than MAX_CANVAS_DIST_FACTOR × main-polygon extent from the main centre.
       Auto-handles French DOM/TOM, Seychelles outer islands, etc.
    4. Generic area-fraction filter — drop polygons < DEFAULT_MIN_FRAC of largest.
       Auto-handles micro-atoll nations (Maldives, Kiribati, …).
    5. 80 % rule — if largest polygon ≥ 80 % of total area, keep only it
       (unless FORCE_MULTI bypasses this, e.g. GB, GR).
    """
    polys = list(mp.geoms)
    if not polys:
        return mp

    # 1. Explicit bbox filter (US only).
    if bbox_filter:
        lon_max = bbox_filter.get('lon_max')
        if lon_max is not None:
            polys = [p for p in polys if p.centroid.x < lon_max]
        lon_min = bbox_filter.get('lon_min')
        if lon_min is not None:
            polys = [p for p in polys if p.centroid.x > lon_min]
        if not polys:
            polys = list(mp.geoms)  # fallback if filter too aggressive

    # 2. Force mainland → largest polygon only.
    if force_mainland:
        largest = max(polys, key=lambda p: p.area)
        return MultiPolygon([largest])

    # 3. Generic canvas-distance filter.
    largest = max(polys, key=lambda p: p.area)
    b = largest.bounds
    geo_w = max(b[2] - b[0], 0.001)
    geo_h = max(b[3] - b[1], 0.001)
    cx = (b[0] + b[2]) / 2
    cy = (b[1] + b[3]) / 2
    max_dx = MAX_CANVAS_DIST_FACTOR * geo_w
    max_dy = MAX_CANVAS_DIST_FACTOR * geo_h
    near = [p for p in polys
            if abs(p.centroid.x - cx) <= max_dx and abs(p.centroid.y - cy) <= max_dy]
    if near:
        polys = near

    # 4. Generic area-fraction filter.
    largest = max(polys, key=lambda p: p.area)
    polys = [p for p in polys if p.area >= DEFAULT_MIN_FRAC * largest.area]
    if not polys:
        polys = [largest]

    # 5. 80 % rule (bypassed for FORCE_MULTI countries).
    if not force_multi:
        total_area = sum(p.area for p in polys)
        if total_area > 0:
            largest = max(polys, key=lambda p: p.area)
            if largest.area / total_area >= 0.80:
                return MultiPolygon([largest])

    return MultiPolygon(polys)


def simplify_polygons(mp: MultiPolygon, epsilon: float) -> MultiPolygon:
    """Simplify each polygon in the MultiPolygon."""
    result = []
    for poly in mp.geoms:
        simplified = poly.simplify(epsilon, preserve_topology=True)
        if isinstance(simplified, Polygon) and not simplified.is_empty and simplified.area > 0:
            result.append(simplified)
        elif hasattr(simplified, 'geoms'):
            for g in simplified.geoms:
                if isinstance(g, Polygon) and not g.is_empty:
                    result.append(g)
    return MultiPolygon(result) if result else mp


def normalise(mp: MultiPolygon) -> tuple[float, float, list]:
    """
    Fit the MultiPolygon into a 1000×N coordinate space.

    Bounding-box selection:
    - If the second-largest polygon is ≥ 35 % of the largest by area, use the
      combined bounding box of ALL polygons. This puts all major islands of an
      archipelago nation (NZ, Fiji, Japan, …) on-canvas together.
    - Otherwise anchor to the largest polygon only. This keeps the main
      landmass filling the full canvas for countries where one island
      dominates (Seychelles: Praslin ≈ 26 % of Mahé → Mahé fills the canvas).

    Polygons that fall outside the chosen bounding box receive off-canvas
    coordinates and are naturally clipped at render time.

    Returns (norm_width, norm_height, polys_as_coord_lists).
    """
    polys = list(mp.geoms)
    if not polys:
        return NORM_WIDTH, MIN_HEIGHT, []

    polys_sorted = sorted(polys, key=lambda p: p.area, reverse=True)
    main_poly = polys_sorted[0]

    # Choose bounding box: combined if two roughly equal major islands exist.
    if (len(polys_sorted) >= 2 and
            polys_sorted[1].area / main_poly.area >= 0.35):
        bounds = unary_union(polys).bounds  # envelope of all polygons
    else:
        bounds = main_poly.bounds

    if bounds[2] == bounds[0]:
        return NORM_WIDTH, MIN_HEIGHT, []

    geo_w = bounds[2] - bounds[0]
    geo_h = bounds[3] - bounds[1]
    scale = NORM_WIDTH / geo_w
    norm_h = max(MIN_HEIGHT, geo_h * scale)

    # Centre vertically if padded to MIN_HEIGHT.
    y_offset = (norm_h - geo_h * scale) / 2.0

    polys_out = []
    for poly in polys:
        coords = []
        for x, y in poly.exterior.coords:
            nx = (x - bounds[0]) * scale
            # Flip Y (GeoJSON is lat-up, canvas is y-down).
            ny = norm_h - ((y - bounds[1]) * scale + y_offset)
            coords.append([round(nx, 1), round(ny, 1)])
        if len(coords) >= 3:
            polys_out.append(coords)

    return NORM_WIDTH, round(norm_h, 1), polys_out


def count_points(polys_out: list) -> int:
    return sum(len(p) for p in polys_out)


# ── Country pipeline ───────────────────────────────────────────────────────────

def process_countries():
    os.makedirs(COUNTRY_OUT, exist_ok=True)

    written = 0
    flagged = []  # polygons with > 600 points post-simplification
    seen_iso2 = set()
    continent_geoms = defaultdict(list)  # continent key → list of shapely geoms

    with fiona.open(SHAPEFILE) as src:
        for feature in src:
            props = feature['properties']
            # ISO_A2 is '-99' for some features in NE data (e.g. France) — use EH fallback.
            iso2_raw = (props.get('ISO_A2') or '').strip()
            if iso2_raw in ('-99', '', 'X1'):
                iso2_raw = (props.get('ISO_A2_EH') or '').strip()
            iso2 = iso2_raw.lower()

            if iso2 in SKIP_CODES or iso2 in seen_iso2:
                continue

            # Skip Antarctica and micro-territories (area filter applied later).
            continent_name = props.get('CONTINENT', '')
            if continent_name == 'Antarctica':
                continue

            geom = shape(feature['geometry'])
            mp = to_multipolygon(geom)
            if mp.is_empty:
                continue

            # Store for continent dissolution.
            if continent_name in CONTINENT_KEYS:
                continent_geoms[continent_name].append(geom)

            # Skip very tiny features (< 1 km²) that are likely noise.
            # Natural Earth 50m is in geographic degrees; rough filter.
            total_area = mp.area
            if total_area < 0.0001 and iso2 not in {'va', 'sm', 'mc', 'li'}:
                continue

            seen_iso2.add(iso2)

            force_mainland = iso2 in FORCE_MAINLAND
            force_multi = iso2 in FORCE_MULTI
            bbox_filter = BBOX_FILTER.get(iso2, {})

            selected = select_polygons(mp, iso2, force_mainland, force_multi, bbox_filter)

            # Compute epsilon: explicit override or auto-derived from main polygon width.
            if iso2 in EPSILON_OVERRIDES:
                geo_epsilon = EPSILON_OVERRIDES[iso2]
            else:
                main_poly = max(selected.geoms, key=lambda p: p.area)
                geo_w_main = main_poly.bounds[2] - main_poly.bounds[0]
                geo_epsilon = max(AUTO_EPSILON_MIN, min(AUTO_EPSILON_MAX, geo_w_main / AUTO_EPSILON_SCALE))
            simplified = simplify_polygons(selected, geo_epsilon)
            w, h, polys_out = normalise(simplified)

            if not polys_out:
                print(f"  WARNING: {iso2} — no polygons after processing, skipping")
                continue

            pt_count = count_points(polys_out)
            if pt_count > 600:
                flagged.append((iso2, pt_count))

            data = {"w": NORM_WIDTH, "h": h, "polys": polys_out}
            out_path = os.path.join(COUNTRY_OUT, f"{iso2}.json")
            with open(out_path, 'w') as f:
                json.dump(data, f, separators=(',', ':'))
            written += 1

    print(f"  Countries: {written} files written to assets/country_paths/")
    if flagged:
        print(f"  FLAGGED (> 600 pts, review manually):")
        for code, n in sorted(flagged, key=lambda x: -x[1]):
            print(f"    {code}: {n} points")

    return continent_geoms


# ── Continent pipeline ─────────────────────────────────────────────────────────

def process_continents(continent_geoms: dict):
    os.makedirs(CONTINENT_OUT, exist_ok=True)

    for continent_name, key in CONTINENT_KEYS.items():
        geoms = continent_geoms.get(continent_name, [])
        if not geoms:
            print(f"  WARNING: no features for {continent_name}")
            continue

        # Dissolve all country geometries into one.
        dissolved = unary_union(geoms)
        mp = to_multipolygon(dissolved)

        # For continents, use 1.0° simplification (~110 km) — continental scale.
        # 10m source data needs coarser epsilon to keep continent path sizes reasonable.
        geo_epsilon = 1.0

        simplified = simplify_polygons(mp, geo_epsilon)
        w, h, polys_out = normalise(simplified)

        if not polys_out:
            print(f"  WARNING: {continent_name} — empty after processing")
            continue

        pt_count = count_points(polys_out)
        data = {"w": NORM_WIDTH, "h": h, "polys": polys_out}
        out_path = os.path.join(CONTINENT_OUT, f"{key}.json")
        with open(out_path, 'w') as f:
            json.dump(data, f, separators=(',', ':'))
        print(f"  {continent_name}: {pt_count} pts → {key}.json ({os.path.getsize(out_path)} bytes)")


# ── Meta ───────────────────────────────────────────────────────────────────────

def write_meta(country_count: int):
    meta = {
        "source": "ne_50m_admin_0_countries",
        "built": str(date.today()),
        "count": country_count,
        "disclaimer": "Country outlines are for decorative purposes only and do not represent authoritative political boundaries.",
    }
    out_path = os.path.join(COUNTRY_OUT, '_meta.json')
    with open(out_path, 'w') as f:
        json.dump(meta, f, indent=2)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    if not os.path.exists(SHAPEFILE):
        print(f"ERROR: {SHAPEFILE} not found.")
        print("Download from: https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip")
        sys.exit(1)

    print("Building country paths...")
    continent_geoms = process_countries()

    country_count = len([f for f in os.listdir(COUNTRY_OUT) if f.endswith('.json') and not f.startswith('_')])
    write_meta(country_count)

    print("\nBuilding continent paths...")
    process_continents(continent_geoms)

    print(f"\nDone. {country_count} country paths, 6 continent paths.")


if __name__ == '__main__':
    main()
