#!/usr/bin/env python3
"""
Roavvy geodata build script.

Converts a Natural Earth 1:50m admin-0 shapefile into the compact binary
format read by packages/country_lookup.

Usage:
    pip install pyshp
    python3 build_geodata.py \\
        --input  source/ne_50m_admin_0_countries.shp \\
        --output ../../../apps/mobile_flutter/assets/geodata/ne_countries.bin

See GEODATA.md for full documentation.
"""

import argparse
import math
import struct
import sys


MAGIC = b"RLKP"
VERSION = 1
GRID_CELL_SIZE = 1   # 1 degree per grid cell
GRID_COLS = 360      # longitude: −180 to 179
GRID_ROWS = 180      # latitude:   −90 to  89


def read_shapefile(path: str) -> list[tuple[str, list[list[tuple[float, float]]]]]:
    """
    Returns a list of (iso_code, rings) tuples.
    Each ring is a list of (lat, lng) tuples.
    Records with ISO_A2 == '-99' are skipped.
    """
    try:
        import shapefile
    except ImportError:
        sys.exit("pyshp is required: pip install pyshp")

    sf = shapefile.Reader(path)
    iso_field_index = None
    for i, field in enumerate(sf.fields[1:], start=0):  # fields[0] is DeletionFlag
        if field[0] in ("ISO_A2", "iso_a2"):
            iso_field_index = i
            break

    if iso_field_index is None:
        sys.exit("Could not find ISO_A2 field in shapefile")

    results = []
    for sr in sf.shapeRecords():
        iso = sr.record[iso_field_index]
        if iso == "-99" or not iso or len(iso) != 2:
            continue

        shape = sr.shape
        if shape.shapeType not in (5, 15, 25):  # Polygon types
            continue

        # Split parts into rings. Each part boundary marks a new ring.
        parts = list(shape.parts) + [len(shape.points)]
        rings = []
        for i in range(len(parts) - 1):
            ring_points = shape.points[parts[i]: parts[i + 1]]
            # Natural Earth stores (lng, lat); we need (lat, lng).
            rings.append([(pt[1], pt[0]) for pt in ring_points])

        if rings:
            results.append((iso.upper(), rings))

    return results


def latlon_to_cell(lat: float, lng: float) -> tuple[int, int]:
    col = int((lng + 180) / GRID_CELL_SIZE)
    row = int((lat + 90) / GRID_CELL_SIZE)
    col = max(0, min(GRID_COLS - 1, col))
    row = max(0, min(GRID_ROWS - 1, row))
    return col, row


def bbox_cells(vertices: list[tuple[float, float]]) -> list[tuple[int, int]]:
    """Returns all grid cells overlapped by the bounding box of vertices."""
    lats = [v[0] for v in vertices]
    lngs = [v[1] for v in vertices]
    lat_min, lat_max = min(lats), max(lats)
    lng_min, lng_max = min(lngs), max(lngs)

    col_min, row_min = latlon_to_cell(lat_min, lng_min)
    col_max, row_max = latlon_to_cell(lat_max, lng_max)

    cells = []
    for row in range(row_min, row_max + 1):
        for col in range(col_min, col_max + 1):
            cells.append((col, row))
    return cells


def to_micro_degrees(deg: float) -> int:
    return round(deg * 1_000_000)


def build_binary(
    polygons: list[tuple[str, list[tuple[float, float]]]],
) -> bytes:
    """
    polygons: list of (iso_code, vertices) — one entry per ring.
    Builds the full binary payload.
    """
    cell_count = GRID_COLS * GRID_ROWS

    # Map each grid cell to the polygon indices that overlap it.
    cell_poly_indices: list[list[int]] = [[] for _ in range(cell_count)]
    for pi, (_, vertices) in enumerate(polygons):
        for col, row in bbox_cells(vertices):
            cell_poly_indices[row * GRID_COLS + col].append(pi)

    # Build flat polygon-refs list.
    grid_ref_start = []
    grid_ref_count = []
    poly_refs = []
    for cell in cell_poly_indices:
        grid_ref_start.append(len(poly_refs))
        grid_ref_count.append(len(cell))
        poly_refs.extend(cell)

    # Serialise polygon data.
    poly_data = bytearray()
    for iso, vertices in polygons:
        iso_bytes = iso.encode("ascii")[:2]
        poly_data += iso_bytes
        poly_data += struct.pack("<H", len(vertices))
        for lat, lng in vertices:
            poly_data += struct.pack("<i", to_micro_degrees(lat))
            poly_data += struct.pack("<i", to_micro_degrees(lng))

    # Serialise grid index.
    grid_data = bytearray()
    for i in range(cell_count):
        grid_data += struct.pack("<I", grid_ref_start[i])
        grid_data += struct.pack("<H", grid_ref_count[i])

    # Serialise polygon refs.
    refs_data = bytearray()
    for ref in poly_refs:
        refs_data += struct.pack("<H", ref)

    # Header.
    poly_refs_size = len(refs_data)
    header = MAGIC
    header += struct.pack("BB", VERSION, GRID_CELL_SIZE)
    header += struct.pack("<HH", GRID_COLS, GRID_ROWS)
    header += struct.pack("<H", len(polygons))
    header += struct.pack("<I", poly_refs_size)

    assert len(header) == 16, f"Header must be 16 bytes, got {len(header)}"

    return bytes(header) + bytes(grid_data) + bytes(refs_data) + bytes(poly_data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build ne_countries.bin")
    parser.add_argument("--input", required=True, help="Path to .shp file")
    parser.add_argument("--output", required=True, help="Path for output .bin")
    args = parser.parse_args()

    print("Reading shapefile...")
    country_rings = read_shapefile(args.input)

    # Flatten: one (iso, ring) entry per ring (handles multi-polygon countries).
    polygons: list[tuple[str, list[tuple[float, float]]]] = []
    country_count = 0
    seen_isos: set[str] = set()
    for iso, rings in country_rings:
        for ring in rings:
            polygons.append((iso, ring))
        seen_isos.add(iso)
        country_count += 1

    print(f"  Loaded {len(polygons)} polygons across {country_count} countries")

    if len(polygons) > 65535:
        sys.exit(f"Too many polygons ({len(polygons)}); max is 65535 (uint16)")

    print(f"Building {GRID_CELL_SIZE}° grid index ({GRID_COLS}×{GRID_ROWS} cells)...")
    payload = build_binary(polygons)

    grid_size = GRID_COLS * GRID_ROWS * 6
    print(f"  Grid index: {grid_size:,} bytes")

    print(f"Writing binary to {args.output}...")
    import os
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(payload)

    print(f"  Output: {len(payload):,} bytes ({len(payload) / 1024:.1f} KB)")
    print("Done.")


if __name__ == "__main__":
    main()
