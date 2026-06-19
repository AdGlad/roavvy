# M164 — High-Resolution Country Polygons (1:10m)

**Status: Not Started**

## Problem

Country polygons are sourced from Natural Earth 1:50m data. At this resolution, adjacent country polygons do not share vertices exactly — sub-pixel gaps appear between borders, especially visible in the World Leap game where countries are colour-coded. The app looks low-quality.

Raster tile layers are not an option: Roavvy is offline-first (CLAUDE.md Hard Rule 4) and must render the full world map without any network access.

---

## Goal

Replace the bundled `ne_countries.bin` binary with one built from Natural Earth 1:10m data. Borders will fit together accurately at all zoom levels the app uses (1.0–8.0). No API, no tiles, no new packages — pure offline polygon data.

---

## Prerequisites

- `packages/country_lookup` build pipeline (`tool/build_geodata.py`) — **complete**
- Python 3 + `pyshp` virtualenv (documented in `GEODATA.md`)
- Natural Earth 1:10m Admin-0 Countries shapefile (downloaded at build time, not committed)
- No Flutter or Dart changes required

---

## What Changes

| File | Change |
|---|---|
| `apps/mobile_flutter/assets/geodata/ne_countries.bin` | Replace with 1:10m build (~3–5 MB, up from 1.28 MB) |
| `packages/country_lookup/GEODATA.md` | Update source URL and expected output stats |
| `packages/country_lookup/tool/build_geodata.py` | Update docstring/comments to reference 1:10m |

No Dart code changes. The binary format is unchanged. The `loadPolygons()` and `resolveCountry()` APIs are unchanged.

---

## Implementation Steps

### 1. Download source data

```bash
cd packages/country_lookup/tool/source
curl -L https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_0_countries.zip \
  -o ne_10m_admin_0_countries.zip
unzip ne_10m_admin_0_countries.zip
```

The `source/` directory is gitignored. Do not commit the shapefile.

### 2. Run the build script

```bash
cd packages/country_lookup/tool
python3 -m venv .venv
.venv/bin/pip install pyshp

.venv/bin/python3 build_geodata.py \
  --input  source/ne_10m_admin_0_countries.shp \
  --output ../../../apps/mobile_flutter/assets/geodata/ne_countries.bin
```

Expected output:
```
Reading shapefile...
  Loaded ~5 000–8 000 polygons across ~250 countries
Building 1° grid index (360×180 cells)...
  Grid index: 388,800 bytes
Writing binary to .../ne_countries.bin...
  Output: ~3 000 000–5 000 000 bytes (~3–5 MB)
Done.
```

If the script exits with "Too many polygons (>65535)" the binary format's uint16 polygon-index limit has been hit. Resolution: see Risk 1 below.

### 3. Verify lookup correctness

Run the existing country_lookup test suite — no test changes expected:

```bash
cd packages/country_lookup
dart test
```

All existing tests must pass. The only change is more accurate polygon coverage.

### 4. Benchmark lookup performance

The `resolveCountry()` SLA is < 5 ms on a mid-range device (iPhone XR equivalent). With 1:10m data, more polygons overlap each 1° grid cell, so the point-in-polygon scan is longer.

Run the benchmark test:

```bash
cd packages/country_lookup
dart test test/country_lookup_test.dart --name benchmark
```

If average lookup time exceeds 5 ms, reduce the grid cell size from 1° to 0.5° in `build_geodata.py` (`GRID_CELL_SIZE = 0.5`, `GRID_COLS = 720`, `GRID_ROWS = 360`). This quadruples index size but halves average polygon candidates per cell.

### 5. Benchmark render performance

Open the World Leap game on a physical device and verify the map renders at ≥ 60 fps during polygon layer rebuild (country colour changes on launch). 1:10m data has ~10× more vertices than 1:50m.

If frame rate drops below 60 fps:
- `PolygonLayer(polygonCulling: true, ...)` is already set — confirm it is active
- Consider vertex decimation in the build script: skip every Nth vertex when vertex count per ring exceeds a threshold (e.g. > 500 vertices → keep every 2nd). Add a `--simplify` flag to `build_geodata.py` using the Ramer-Douglas-Peucker algorithm (`shapely` package) at epsilon = 0.0005°.

### 6. Update documentation

Update `packages/country_lookup/GEODATA.md`:
- Change source URL to 1:10m
- Update `--input` flag example
- Update expected output stats

Update the build script docstring to reference 1:10m.

### 7. Commit the new binary

```bash
git add apps/mobile_flutter/assets/geodata/ne_countries.bin
git add packages/country_lookup/GEODATA.md
git add packages/country_lookup/tool/build_geodata.py
git commit -m "feat(geodata): upgrade country polygons to Natural Earth 1:10m"
```

---

## Risks

### Risk 1 — uint16 polygon index limit

The binary format stores polygon indices as uint16, capping the total polygon count at 65,535. Natural Earth 1:10m admin-0 has approximately 5,000–8,000 rings (well within the cap). Verify by checking the script output. If it ever exceeds the cap (unlikely), the format's polygon-data section must be widened to uint32 — a breaking binary format change requiring a version bump in `binary_format.dart` and `build_geodata.py`.

### Risk 2 — render performance

The `PolygonLayer` in `flutter_map` rebuilds all polygon geometry each frame that country colours change. With ~10× more vertices, this rebuild takes longer. The culling flag (`polygonCulling: true`) eliminates off-screen polygons, but the in-view rebuild is still heavier. If 60 fps cannot be maintained, add vertex decimation to the build script (see Step 5). Do not add decimation speculatively — measure first.

### Risk 3 — binary size

At ~3–5 MB, `ne_countries.bin` is a meaningful increase from 1.28 MB. This is bundled into the app binary (not downloaded). Acceptable for the quality improvement, but confirm with app size budget. iOS App Store thin-slices assets per device, so the real user impact is smaller than the raw delta.

### Risk 4 — overseas territory ring overrides

The build script has hardcoded bounding-box overrides for French overseas departments, Netherlands Caribbean, Norway arctic, and Australian Indian Ocean territories (lines 64–82 of `build_geodata.py`). The 1:10m shapefile may bundle these territories differently than 1:50m. Run the existing test cases for `GF`, `RE`, `MQ`, `GP`, `YT`, `PM`, `BQ`, `SJ`, `CX`, `CC` after the build and fix any overrides that no longer match.

---

## Acceptance Criteria

- [ ] `ne_countries.bin` built from 1:10m source
- [ ] All `country_lookup` tests pass
- [ ] `resolveCountry()` benchmark < 5 ms average on iPhone XR equivalent
- [ ] World Leap map renders at ≥ 60 fps during colour changes
- [ ] Visible polygon seams eliminated at zoom levels 1.0–8.0 on device
- [ ] `GEODATA.md` updated to reference 1:10m
- [ ] Overseas territory spot-checks pass (GF, RE, MQ, BQ, SJ, CX)
