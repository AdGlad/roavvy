# country_lookup — Geodata Build Pipeline

This document describes how to regenerate `apps/mobile_flutter/assets/geodata/ne_countries.bin` from the Natural Earth source data.

The binary asset is checked into the repository. Re-generate it only when:
- Natural Earth publishes a new release
- A country's borders change and an app update is warranted
- The binary format version is incremented

---

## Source data

**Natural Earth 1:50m Admin-0 Countries**
- URL: https://www.naturalearthdata.com/downloads/50m-cultural-vectors/
- File: `ne_50m_admin_0_countries.zip`
- Licence: Public Domain

Download and unzip to `packages/country_lookup/tool/source/`. The `source/` directory is gitignored — do not commit the shapefile.

## Prerequisites

macOS system Python is externally managed; use a virtual environment:

```bash
cd packages/country_lookup/tool
python3 -m venv .venv
.venv/bin/pip install pyshp
```

The `.venv/` directory is gitignored.

## Running the build script

```bash
cd packages/country_lookup/tool
.venv/bin/python3 build_geodata.py \
  --input  source/ne_50m_admin_0_countries.shp \
  --output ../../../apps/mobile_flutter/assets/geodata/ne_countries.bin
```

Expected output:
```
Reading shapefile...
  Loaded NNN polygons across NNN countries
Building 1° grid index (360×180 cells)...
  Grid index: 388,800 bytes
Writing binary to .../ne_countries.bin...
  Output: NNN bytes (NNN KB)
Done.
```

## Binary format reference

See `packages/country_lookup/lib/src/binary_format.dart` for the canonical format specification.

Summary:

| Section | Size |
|---|---|
| Header | 16 bytes |
| Grid index | 360 × 180 × 6 = 388 800 bytes |
| Polygon refs | variable (uint16 per ref) |
| Polygon data | variable (2-byte ISO + uint16 vertex count + int32 pairs) |

Coordinates are stored as `int32` micro-degrees (`degrees × 1 000 000`) in little-endian byte order.

## Field mapping

The build script reads the `ISO_A2` field from the Natural Earth shapefile for country codes. Records where `ISO_A2` is `-99` (disputed territories or unassigned areas) are skipped.

## Accuracy notes

At 1:50m precision, borders are accurate to roughly 1–2 km. Combined with 0.5° coordinate bucketing (~55 km) in the scan pipeline (ADR-005), this precision is more than sufficient for Roavvy's country-level detection.

Island nations and multi-polygon countries (e.g. Japan, Indonesia, Philippines) are handled correctly: each polygon ring is stored as a separate entry in the binary, all with the same ISO code. The lookup returns the first matching polygon's code.
