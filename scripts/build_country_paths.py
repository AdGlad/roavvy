#!/usr/bin/env python3
"""
M171 — Country & Continent Outline Clip path pipeline.

Usage:
    python3 scripts/build_country_paths.py

Inputs:
    /tmp/ne_data/ne_50m_admin_0_countries.shp  (Natural Earth 50m)

Outputs:
    apps/mobile_flutter/assets/country_paths/{iso2}.json   (195 countries)
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

SHAPEFILE = '/tmp/ne_data/ne_50m_admin_0_countries.shp'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
APP_ASSETS = os.path.join(ROOT, 'apps', 'mobile_flutter', 'assets')
COUNTRY_OUT = os.path.join(APP_ASSETS, 'country_paths')
CONTINENT_OUT = os.path.join(APP_ASSETS, 'continent_paths')

# Width of normalised coordinate space (always 1000 units wide).
NORM_WIDTH = 1000.0
# Minimum height to prevent sliver shapes (Chile, etc.)
MIN_HEIGHT = 400.0

# Default Douglas-Peucker tolerance in geographic degrees.
# ~0.15° ≈ ~17 km — appropriate for 50m dataset shirt-scale rendering.
DEFAULT_EPSILON = 0.15

# Countries that use the 80% rule bypass (always multi-polygon).
FORCE_MULTI = {'gb', 'jp', 'gr', 'id', 'ph', 'nz', 'fj', 'ca', 'no'}

# Countries that should only use mainland (filter to largest polygon).
FORCE_MAINLAND = {'ru'}

# Minimum polygon area as a fraction of the LARGEST polygon's area.
# Polygons below this fraction are dropped. 0.0 = keep all (default for most).
# This trims distant micro-islands that would otherwise push the bounding box
# outward, while the normalise() function still centres on the main landmass.
MIN_POLY_FRACTION: dict[str, float] = {
    'sc': 0.05,   # Seychelles: keep Mahé + Praslin (~24%) + La Digue (~6%)
    'id': 0.03,   # Indonesia: keep main islands, drop micro-islands
    'ph': 0.03,   # Philippines: keep main islands
    'fj': 0.05,   # Fiji: Viti Levu + Vanua Levu
}

# Countries with bbox filtering to remove overseas territories.
BBOX_FILTER = {
    # France: only keep polygons with centroid longitude < 10° (metropolitan France).
    'fr': {'lon_max': 10.0},
    # USA: only keep polygons with centroid longitude > -128° (continental US).
    # This excludes Alaska (centroid ≈ -153°) and Hawaii (centroid ≈ -157°).
    # In geographic degrees Alaska appears large due to high-latitude distortion,
    # so area-fraction filtering is insufficient — bbox is more reliable.
    'us': {'lon_min': -128.0},
}

# Per-country epsilon overrides in geographic degrees.
EPSILON_OVERRIDES = {
    # Very large / complex countries: coarser simplification.
    'ca': 0.5,   # Canada: many northern islands
    'ru': 0.4,   # Russia: vast, mainland only
    'id': 0.35,  # Indonesia: many islands
    'ph': 0.35,  # Philippines: archipelago
    'us': 0.3,   # USA: complex coastline
    'br': 0.3,   # Brazil
    'cl': 0.3,   # Chile: very long narrow
    'au': 0.25,  # Australia
    'cn': 0.25,  # China
    'in': 0.25,  # India
    'ar': 0.25,  # Argentina
    'gl': 0.5,   # Greenland: massive coastline
    'mm': 0.25,  # Myanmar
    # Fine-detail island chains: keep original DEFAULT.
    'jp': 0.10,  # Japan: recognisable islands
    'gr': 0.10,  # Greece: archipelago
    'gb': 0.10,  # Great Britain + NI
    'no': 0.15,  # Norway: fjords
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
    1. bbox filter (remove overseas territories, e.g. French Guiana).
    2. force_mainland → keep only the largest polygon.
    3. min_poly_fraction → keep only polygons whose area ≥ fraction × largest area.
    4. 80% rule (existing): if largest polygon ≥ 80% of total area, keep only it.
    5. Otherwise keep all (multi-polygon island chains, etc.).
    """
    polys = list(mp.geoms)
    if not polys:
        return mp

    # 1. Apply bbox filter (e.g. France: remove DOM/TOM).
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

    # 3. Area-fraction filter (per-country config).
    min_frac = MIN_POLY_FRACTION.get(iso2, 0.0)
    if min_frac > 0.0:
        largest = max(polys, key=lambda p: p.area)
        polys = [p for p in polys if p.area >= min_frac * largest.area]
        return MultiPolygon(polys) if polys else MultiPolygon([largest])

    # 4/5. 80% rule (for countries not in FORCE_MULTI).
    if not force_multi and iso2 not in FORCE_MULTI:
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

    The coordinate system is anchored to the LARGEST polygon's bounding box.
    This ensures the main landmass always fills the 1000-unit canvas. Smaller
    or distant polygons (e.g. Alaska, outer Seychelles islands) receive
    coordinates that may be negative or > 1000 — they will appear off-canvas
    at render time, which is the desired behaviour (main landmass is centred
    and fills the print area; distant features are naturally clipped).

    Returns (norm_width, norm_height, polys_as_coord_lists).
    """
    polys = list(mp.geoms)
    if not polys:
        return NORM_WIDTH, MIN_HEIGHT, []

    # Anchor the coordinate system to the largest polygon's bounds.
    main_poly = max(polys, key=lambda p: p.area)
    bounds = main_poly.bounds  # (minx, miny, maxx, maxy)
    if bounds[2] == bounds[0]:
        return NORM_WIDTH, MIN_HEIGHT, []

    geo_w = bounds[2] - bounds[0]
    geo_h = bounds[3] - bounds[1]
    scale = NORM_WIDTH / geo_w
    norm_h = max(MIN_HEIGHT, geo_h * scale)

    # Centre vertically if padded.
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

            # Simplify in geographic space (degrees), then normalise.
            geo_epsilon = EPSILON_OVERRIDES.get(iso2, DEFAULT_EPSILON)
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

        # For continents, use 0.5° simplification (~55 km) — continental scale.
        geo_epsilon = 0.5

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
