#!/usr/bin/env python3
"""
Roavvy admin1 geodata build script.

Converts a Natural Earth 1:10m admin1/states-provinces shapefile into the
compact binary format read by packages/region_lookup.

Usage:
    pip install pyshp
    python3 build_geodata.py \\
        --input  source/ne_10m_admin_1_states_provinces.shp \\
        --output ../assets/geodata/ne_admin1.bin

See GEODATA.md for full documentation and instructions to refresh the source data.
"""

import argparse
import struct
import sys


MAGIC = b"RLRG"
VERSION = 1
GRID_CELL_SIZE = 1   # 1 degree per grid cell
GRID_COLS = 360      # longitude: −180 to 179
GRID_ROWS = 180      # latitude:   −90 to  89

# Natural Earth field name for ISO 3166-2 codes.
_ISO_3166_2_FIELDS = ("iso_3166_2", "ISO_3166_2")


def read_shapefile(path: str) -> list[tuple[str, list[list[tuple[float, float]]]]]:
    """
    Returns a list of (iso_3166_2_code, rings) tuples.
    Each ring is a list of (lat, lng) tuples.

    Records without a valid iso_3166_2 value are skipped (open water,
    micro-states with no admin1 subdivisions, disputed territories).
    """
    try:
        import shapefile
    except ImportError:
        sys.exit("pyshp is required: pip install pyshp")

    sf = shapefile.Reader(path)

    # Locate the ISO 3166-2 field index.
    iso_field_index = None
    for i, field in enumerate(sf.fields[1:], start=0):  # fields[0] is DeletionFlag
        if field[0] in _ISO_3166_2_FIELDS:
            iso_field_index = i
            break

    if iso_field_index is None:
        sys.exit(
            f"Could not find ISO 3166-2 field in shapefile. "
            f"Available fields: {[f[0] for f in sf.fields[1:]]}"
        )

    results = []
    skipped = 0
    for sr in sf.shapeRecords():
        code = sr.record[iso_field_index]

        # Skip records without a valid ISO 3166-2 code.
        if not code or not isinstance(code, str):
            skipped += 1
            continue
        code = code.strip()
        if not code or code in ("-99", "None", "null"):
            skipped += 1
            continue
        # Normalise to uppercase.
        code = code.upper()

        shape = sr.shape
        if shape.shapeType not in (5, 15, 25):  # Polygon types
            skipped += 1
            continue

        # Split parts into rings.
        parts = list(shape.parts) + [len(shape.points)]
        rings = []
        for i in range(len(parts) - 1):
            ring_points = shape.points[parts[i]: parts[i + 1]]
            # Natural Earth stores (lng, lat); we need (lat, lng).
            rings.append([(pt[1], pt[0]) for pt in ring_points])

        if rings:
            results.append((code, rings))
        else:
            skipped += 1

    if skipped:
        print(f"  Skipped {skipped} records (no valid ISO 3166-2 code or empty geometry)")

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


def simplify_ring(
    vertices: list[tuple[float, float]],
    tolerance: float = 0.01,
) -> list[tuple[float, float]]:
    """
    Remove intermediate vertices closer than [tolerance] degrees to the
    previous kept vertex. Keeps first and last vertex unconditionally.

    This is a simple step-down filter (not Douglas-Peucker) — fast and
    sufficient for reducing 1:10m admin1 data to the 5 MB target.
    """
    if len(vertices) <= 3:
        return vertices

    kept = [vertices[0]]
    for v in vertices[1:-1]:
        prev = kept[-1]
        if abs(v[0] - prev[0]) >= tolerance or abs(v[1] - prev[1]) >= tolerance:
            kept.append(v)
    kept.append(vertices[-1])
    return kept if len(kept) >= 3 else vertices


def build_binary(
    polygons: list[tuple[str, list[tuple[float, float]]]],
) -> bytes:
    """
    polygons: list of (iso_3166_2_code, vertices) — one entry per ring.
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

    # Serialise polygon data (variable-length region codes).
    poly_data = bytearray()
    for code, vertices in polygons:
        code_bytes = code.encode("ascii")
        if len(code_bytes) > 255:
            raise ValueError(f"Region code too long (>255 bytes): {code!r}")
        poly_data += struct.pack("B", len(code_bytes))
        poly_data += code_bytes
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

    # Header (16 bytes).
    poly_refs_size = len(refs_data)
    header = MAGIC
    header += struct.pack("BB", VERSION, GRID_CELL_SIZE)
    header += struct.pack("<HH", GRID_COLS, GRID_ROWS)
    header += struct.pack("<H", len(polygons))
    header += struct.pack("<I", poly_refs_size)

    assert len(header) == 16, f"Header must be 16 bytes, got {len(header)}"

    return bytes(header) + bytes(grid_data) + bytes(refs_data) + bytes(poly_data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build ne_admin1.bin")
    parser.add_argument("--input", required=True, help="Path to .shp file")
    parser.add_argument("--output", required=True, help="Path for output .bin")
    args = parser.parse_args()

    print("Reading shapefile...")
    admin1_records = read_shapefile(args.input)

    # Flatten: one (code, ring) entry per ring; simplify vertices.
    polygons: list[tuple[str, list[tuple[float, float]]]] = []
    region_count = 0
    seen_codes: set[str] = set()
    for code, rings in admin1_records:
        for ring in rings:
            simplified = simplify_ring(ring, tolerance=0.05)
            if len(simplified) >= 3:
                polygons.append((code, simplified))
        seen_codes.add(code)
        region_count += 1

    print(f"  Loaded {len(polygons)} polygons across {region_count} regions")

    if len(polygons) > 65535:
        sys.exit(f"Too many polygons ({len(polygons)}); max is 65535 (uint16)")

    print(f"Building {GRID_CELL_SIZE}° grid index ({GRID_COLS}×{GRID_ROWS} cells)...")
    payload = build_binary(polygons)

    grid_size = GRID_COLS * GRID_ROWS * 6
    print(f"  Grid index: {grid_size:,} bytes")
    print(f"  Total size: {len(payload):,} bytes ({len(payload) / 1024 / 1024:.2f} MB)")

    if len(payload) > 5 * 1024 * 1024:
        print("WARNING: output exceeds 5 MB target — consider using a coarser dataset")

    print(f"Writing binary to {args.output}...")
    import os
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(payload)

    print(f"  Written: {len(payload):,} bytes")
    print("Done.")


if __name__ == "__main__":
    main()
