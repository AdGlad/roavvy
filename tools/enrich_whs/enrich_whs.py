#!/usr/bin/env python3
"""
Enriches whs_sites.json with shortDescription and imageUrl from Wikipedia.

For each unique siteId:
  1. Tries to GET https://en.wikipedia.org/api/rest_v1/page/summary/{site_name}
  2. Falls back to Wikipedia opensearch if the direct lookup returns 404
  3. Caches the result per siteId so the run can be safely interrupted and resumed

Usage:
    cd /path/to/roavvy
    python3 tools/enrich_whs/enrich_whs.py

Options:
    --input   PATH   Source JSON  (default: apps/mobile_flutter/assets/geodata/whs_sites.json)
    --output  PATH   Output JSON  (default: same as input — overwrites in place)
    --cache   DIR    Cache dir    (default: /tmp/whs_enrich_cache)
    --limit   N      Stop after N unique sites (useful for testing)

Rate: ~0.25 s per unique site → ~1 351 sites → ~6 min total (cached runs are instant)
"""

import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

# ── Defaults ──────────────────────────────────────────────────────────────────

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT   = os.path.dirname(os.path.dirname(_SCRIPT_DIR))
_DEFAULT_JSON = os.path.join(
    _REPO_ROOT, 'apps', 'mobile_flutter', 'assets', 'geodata', 'whs_sites.json'
)
_DEFAULT_CACHE = '/tmp/whs_enrich_cache'
_USER_AGENT = 'Roavvy-WHSEnricher/1.0 (travel app; contact via github.com/roavvy)'

# ── HTTP helpers ──────────────────────────────────────────────────────────────

def _get_json(url: str, timeout: int = 10) -> dict | None:
    req = urllib.request.Request(url, headers={'User-Agent': _USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError,
            TimeoutError, OSError):
        return None


def _wikipedia_summary(title: str) -> dict | None:
    """GET /api/rest_v1/page/summary/{title}  — returns None on 404 / error."""
    encoded = urllib.parse.quote(title.replace(' ', '_'), safe='')
    url = f'https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}'
    data = _get_json(url)
    if data and data.get('type') != 'https://mediawiki.org/wiki/HyperSwitch/errors/not_found':
        return data
    return None


def _wikipedia_search(query: str) -> str | None:
    """Opensearch — returns the title of the first result, or None."""
    encoded = urllib.parse.quote(query)
    url = (
        'https://en.wikipedia.org/w/api.php'
        f'?action=opensearch&search={encoded}&limit=3&format=json&redirects=resolve'
    )
    data = _get_json(url)
    if data and len(data) > 1 and data[1]:
        return data[1][0]
    return None

# ── Per-site enrichment ───────────────────────────────────────────────────────

def _trim_description(text: str, max_chars: int = 400) -> str:
    """Trim to ~max_chars at a sentence boundary."""
    if len(text) <= max_chars:
        return text
    cut = text[:max_chars].rfind('. ')
    if cut > max_chars // 2:
        return text[:cut + 1]
    return text[:max_chars].rstrip() + '…'


def _enrich_site(site_id: str, name: str, cache_dir: str) -> dict:
    """
    Returns {'shortDescription': str, 'imageUrl': str} for name.
    Values are empty strings when not found. Result is cached by siteId.
    """
    cache_file = os.path.join(cache_dir, f'{site_id}.json')
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            return json.load(f)

    result: dict = {}

    # 1. Try exact title.
    summary = _wikipedia_summary(name)
    time.sleep(0.1)

    # 2. Fall back to opensearch.
    if summary is None:
        title = _wikipedia_search(name)
        time.sleep(0.1)
        if title:
            summary = _wikipedia_summary(title)
            time.sleep(0.1)

    if summary:
        extract = summary.get('extract', '').strip()
        if extract:
            result['shortDescription'] = _trim_description(extract)

        # Prefer full-resolution original; fall back to thumbnail.
        for key in ('originalimage', 'thumbnail'):
            img = summary.get(key)
            if img and img.get('source'):
                result['imageUrl'] = img['source']
                break

    # Cache even empty results so we don't retry failed lookups.
    with open(cache_file, 'w') as f:
        json.dump(result, f)

    return result

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--input',  default=_DEFAULT_JSON,  help='Source JSON path')
    parser.add_argument('--output', default=None,           help='Output JSON path (default: overwrite input)')
    parser.add_argument('--cache',  default=_DEFAULT_CACHE, help='Cache directory')
    parser.add_argument('--limit',  type=int, default=0,    help='Max unique sites to process (0 = all)')
    args = parser.parse_args()

    output_path = args.output or args.input
    os.makedirs(args.cache, exist_ok=True)

    with open(args.input, encoding='utf-8') as f:
        sites: list[dict] = json.load(f)

    # Collect unique siteIds (transboundary sites share one siteId).
    seen: dict[str, str] = {}   # siteId → name
    for s in sites:
        sid = s['siteId']
        if sid not in seen:
            seen[sid] = s['name']

    unique = list(seen.items())
    if args.limit > 0:
        unique = unique[:args.limit]

    print(f'Loaded {len(sites)} records, {len(unique)} unique site(s) to enrich')
    print(f'Cache: {args.cache}\n')

    enrichments: dict[str, dict] = {}
    with_desc = 0
    with_img  = 0

    for i, (sid, name) in enumerate(unique, 1):
        cached = os.path.exists(os.path.join(args.cache, f'{sid}.json'))
        tag = '(cached)' if cached else ''
        print(f'  [{i:4d}/{len(unique)}] {name[:60]:<60} {tag}', flush=True)
        data = _enrich_site(sid, name, args.cache)
        enrichments[sid] = data
        if data.get('shortDescription'):
            with_desc += 1
        if data.get('imageUrl'):
            with_img += 1

    print(f'\nResults: {with_desc}/{len(unique)} descriptions, {with_img}/{len(unique)} images')

    # Apply enrichments to every record (transboundary sites get the same data).
    for site in sites:
        data = enrichments.get(site['siteId'], {})
        if data.get('shortDescription'):
            site['shortDescription'] = data['shortDescription']
        if data.get('imageUrl'):
            site['imageUrl'] = data['imageUrl']

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(sites, f, ensure_ascii=False, separators=(',', ':'))

    size_kb = os.path.getsize(output_path) / 1024
    print(f'Written to {output_path} ({size_kb:.0f} KB)')


if __name__ == '__main__':
    main()
