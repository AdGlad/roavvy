# M164 — High-Resolution Country Polygons (1:10m) — Task List

## Status: In Progress

## Tasks

- [ ] T1: Download NE 1:10m shapefile, set up Python venv
- [ ] T2: Run build script — verify polygon count < 65535, check binary size
- [ ] T3: Run country_lookup dart tests — all must pass
- [ ] T4: Benchmark resolveCountry() — must be < 5ms average
- [ ] T5: Spot-check overseas territory overrides (GF, RE, MQ, BQ, SJ, CX, CC)
- [ ] T6: Update GEODATA.md — new source URL, expected output stats
- [ ] T7: Update build_geodata.py docstring to reference 1:10m
- [ ] T8: Update ADR-017 to document rendering motivation for 1:10m upgrade
- [ ] T9: Commit new binary + updated docs

## Key facts
- Source: https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_0_countries.zip
- Build script: packages/country_lookup/tool/build_geodata.py (no code changes needed)
- Current binary: apps/mobile_flutter/assets/geodata/ne_countries.bin (1.28 MB from 1:50m)
- Binary format unchanged — no Dart code changes
- ADR-017 chose 1:50m; upgrade is for rendering quality (seams), not lookup accuracy
- ADR-049 precedent: region_lookup already uses 1:10m data
- Polygon count limit: uint16 = 65535 max rings
- venv path: packages/country_lookup/tool/.venv (gitignored)
