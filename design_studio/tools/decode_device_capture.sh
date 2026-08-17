#!/usr/bin/env bash
# C-00 Lane A2 — decode the on-device capture report.json into PNGs + a contact
# sheet + a recipe manifest, so the Design Critic / Reference Analyst can review
# real on-device pixels (fonts, SVGs, shaders all rendered for real).
#
# Usage: design_studio/tools/decode_device_capture.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$SCRIPT_DIR/.." && pwd)/generated_batches/rendered_device"
REPORT="$DIR/report.json"
[ -f "$REPORT" ] || { echo "No $REPORT — run flutter drive first (see C-00 doc)."; exit 1; }

python3 - "$REPORT" "$DIR" <<'PY'
import json, sys, os, base64
report, outdir = sys.argv[1], sys.argv[2]
d = json.load(open(report))
img = os.path.join(outdir, 'img'); os.makedirs(img, exist_ok=True)
manifest, rows = [], []
for x in d.get('designs', []):
    stem = x['stem']
    png = base64.b64decode(x.pop('pngBase64'))
    open(os.path.join(img, stem + '.png'), 'wb').write(png)
    manifest.append(x)
    rows.append(
        '<figure><img src="img/%s.png"/><figcaption>%s<br><small>%s · q %.2f</small></figcaption></figure>'
        % (stem, x['family'], x['context'], x['quality']))
json.dump({'source': 'on-device (Lane A2)', 'engineVersion': d.get('engineVersion'),
           'count': len(manifest), 'designs': manifest},
          open(os.path.join(outdir, 'manifest.json'), 'w'), indent=2)
html = '''<!doctype html><meta charset=utf-8><title>On-device capture</title>
<style>body{font:13px -apple-system,sans-serif;margin:24px;background:#141414;color:#eee}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}
figure{margin:0;background:#1e1e1e;border-radius:8px;padding:10px;text-align:center}
img{max-width:100%%;background:linear-gradient(45deg,#333 25%%,transparent 25%%,transparent 75%%,#333 75%%),
linear-gradient(45deg,#333 25%%,#222 25%%,#222 75%%,#333 75%%);background-size:16px 16px;background-position:0 0,8px 8px;border-radius:4px}
figcaption{color:#bbb;font-size:12px;margin-top:6px}</style>
<h1>On-device rendered capture — %d designs (real fonts/SVGs/shaders)</h1>
<div class=grid>%s</div>''' % (len(manifest), '\n'.join(rows))
open(os.path.join(outdir, 'index.html'), 'w').write(html)
print('[decode] wrote %d PNGs + manifest.json + index.html to %s' % (len(manifest), outdir))
PY
