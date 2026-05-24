#!/usr/bin/env python3
"""
Preprocesses the UNESCO World Heritage Sites GeoJSON into a compact JSON asset
for bundling with the Roavvy app.

Usage:
    python3 tools/preprocess_whs/preprocess_whs.py [input.geojson] [output.json]

Defaults:
    input  → /tmp/whc001.geojson
    output → apps/mobile_flutter/assets/geodata/whs_sites.json

Source:
    https://data.unesco.org/api/explore/v2.1/catalog/datasets/whc001/exports/geojson?limit=-1

Output format per record:
    {
      "siteId": "211",
      "name": "Minaret and Archaeological Remains of Jam",
      "countryCode": "AF",
      "latitude": 34.396,
      "longitude": 64.516,
      "category": "cultural",
      "region": "Asia and the Pacific",
      "inscriptionYear": 2002
    }

Transboundary sites (spanning multiple countries) are emitted once per country
code so they are discoverable from any member country. The siteId is the same
across all emitted records for a given site.
"""

import json
import sys
import os

CATEGORY_MAP = {
    'Cultural': 'cultural',
    'Natural': 'natural',
    'Mixed': 'mixed',
}


def process(input_path: str, output_path: str) -> None:
    with open(input_path, encoding='utf-8') as f:
        data = json.load(f)

    features = data.get('features', [])
    print(f'Input: {len(features)} features')

    records = []
    skipped = 0

    for feat in features:
        props = feat.get('properties', {})
        geometry = feat.get('geometry', {})

        # Skip if no geometry or coordinates
        if not geometry:
            skipped += 1
            continue
        coords = geometry.get('coordinates')
        if not coords or len(coords) < 2:
            skipped += 1
            continue

        # GeoJSON coordinates are [longitude, latitude]
        longitude = round(coords[0], 6)
        latitude = round(coords[1], 6)

        # Skip zero-zero (invalid placeholder)
        if latitude == 0.0 and longitude == 0.0:
            skipped += 1
            continue

        iso_codes_raw = props.get('iso_codes')
        if not iso_codes_raw:
            skipped += 1
            continue

        site_id = str(props.get('id_no', ''))
        if not site_id:
            skipped += 1
            continue

        name = props.get('name_en', '').strip()
        if not name:
            skipped += 1
            continue

        category_raw = props.get('category', '')
        category = CATEGORY_MAP.get(category_raw, category_raw.lower())

        region = props.get('region', '')

        date_inscribed = props.get('date_inscribed')
        try:
            inscription_year = int(str(date_inscribed)[:4]) if date_inscribed else 0
        except (ValueError, TypeError):
            inscription_year = 0

        # Split comma-separated country codes; emit one record per country
        country_codes = [c.strip() for c in iso_codes_raw.split(',') if c.strip()]

        for country_code in country_codes:
            records.append({
                'siteId': site_id,
                'name': name,
                'countryCode': country_code,
                'latitude': latitude,
                'longitude': longitude,
                'category': category,
                'region': region,
                'inscriptionYear': inscription_year,
            })

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(records, f, ensure_ascii=False, separators=(',', ':'))

    print(f'Output: {len(records)} records ({len(features) - skipped} unique sites, '
          f'{skipped} skipped, {len(records) - (len(features) - skipped)} extra transboundary entries)')
    print(f'Written to: {output_path}')
    size_kb = os.path.getsize(output_path) / 1024
    print(f'File size: {size_kb:.1f} KB')


if __name__ == '__main__':
    input_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/whc001.geojson'
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(os.path.dirname(script_dir))
    default_output = os.path.join(
        repo_root, 'apps', 'mobile_flutter', 'assets', 'geodata', 'whs_sites.json'
    )
    output_path = sys.argv[2] if len(sys.argv) > 2 else default_output
    process(input_path, output_path)
