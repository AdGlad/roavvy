#!/usr/bin/env python3
"""C-00 automated visual-QA for a rendered batch (Design Studio).

Scans design_studio/generated_batches/<dir>/img/*.png, computes objective render
metrics per design (opaque coverage %, centroid offset, bounding-box fill), joins
with the recipe manifest, flags likely defects, and aggregates by family/context —
so systematic render bugs surface WITHOUT manual eyeballing. Extends the autonomous
testing loop to large samples.

Usage: python3 design_studio/tools/render_qa.py [batch_dir ...]
       (default: all generated_batches/rendered_* dirs)
Pure stdlib (no PIL). Dev-only.
"""
import struct, zlib, os, sys, glob, json, statistics, collections

def _decode(path):
    d = open(path, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n': return None
    pos = 8; W = H = ct = 0; idat = b''
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]; typ = d[pos+4:pos+8]
        chunk = d[pos+8:pos+8+ln]; pos += 12 + ln
        if typ == b'IHDR': W, H, _bd, ct = struct.unpack('>IIBB', chunk[:10])
        elif typ == b'IDAT': idat += chunk
        elif typ == b'IEND': break
    raw = zlib.decompress(idat); ch = 4 if ct == 6 else 3; stride = W*ch
    out = bytearray(); prev = bytearray(stride); p = 0
    def pae(a, b, c):
        pp = a+b-c; pa = abs(pp-a); pb = abs(pp-b); pc = abs(pp-c)
        return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
    for _y in range(H):
        f = raw[p]; p += 1; line = bytearray(raw[p:p+stride]); p += stride
        for i in range(stride):
            a = line[i-ch] if i >= ch else 0; b = prev[i]; c = prev[i-ch] if i >= ch else 0
            if f == 1: line[i] = (line[i]+a) & 255
            elif f == 2: line[i] = (line[i]+b) & 255
            elif f == 3: line[i] = (line[i]+((a+b) >> 1)) & 255
            elif f == 4: line[i] = (line[i]+pae(a, b, c)) & 255
        out += line; prev = line
    return W, H, ch, bytes(out)

def metrics(path):
    r = _decode(path)
    if not r: return None
    W, H, ch, px = r
    if ch < 4: return {'coverage': 100.0, 'note': 'no-alpha'}
    op = 0; sx = sy = 0; minx = W; maxx = 0; miny = H; maxy = 0
    for idx in range(W*H):
        if px[idx*ch+3] > 40:
            op += 1; x = idx % W; y = idx // W; sx += x; sy += y
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y
    if op == 0:
        return {'coverage': 0.0, 'centroid': None, 'bboxFill': 0.0, 'blank': True}
    cov = 100*op/(W*H)
    cx = sx/op/W; cy = sy/op/H
    bbox_area = max(1, (maxx-minx+1)*(maxy-miny+1))
    return {'coverage': round(cov, 1), 'centroid': [round(cx, 3), round(cy, 3)],
            'centerOffset': round(((cx-0.5)**2+(cy-0.5)**2)**0.5, 3),
            'bboxFill': round(100*op/bbox_area, 1), 'blank': cov < 1.0}

# Defect thresholds (tunable). Coverage is the strongest "tiny/blank" signal.
COV_TINY = 12.0     # < this % opaque → likely tiny/near-blank on the garment
OFF_CENTER = 0.16   # centroid distance from centre → off-center placement

def classify(m):
    flags = []
    if m.get('blank'): flags.append('BLANK')
    elif m.get('coverage', 100) < COV_TINY: flags.append(f"TINY({m['coverage']}%)")
    if m.get('centerOffset', 0) > OFF_CENTER: flags.append(f"OFF-CENTER({m['centerOffset']})")
    return flags

def run(batch_dir):
    manp = os.path.join(batch_dir, 'manifest.json')
    recby = {}
    if os.path.exists(manp):
        for d in json.load(open(manp)).get('designs', []):
            recby[d['stem']] = d
    rows = []
    for f in sorted(glob.glob(os.path.join(batch_dir, 'img', '*.png'))):
        stem = os.path.splitext(os.path.basename(f))[0]
        m = metrics(f)
        if not m: continue
        rec = recby.get(stem, {})
        rows.append({'stem': stem, 'context': rec.get('context', '?'),
                     'family': rec.get('family', stem.split('_')[-2] if '_' in stem else '?'),
                     'quality': rec.get('quality'), **m, 'flags': classify(m)})
    return rows

def main():
    dirs = sys.argv[1:] or sorted(glob.glob(os.path.join(
        os.path.dirname(__file__), '..', 'generated_batches', 'rendered_*')))
    allrows = []
    for bd in dirs:
        if os.path.isdir(bd): allrows += run(bd)
    if not allrows:
        print('no rendered PNGs found'); return
    # per-family aggregation
    byfam = collections.defaultdict(list)
    for r in allrows: byfam[r['family']].append(r)
    print(f"=== render QA: {len(allrows)} samples across {len(byfam)} families ===")
    print(f"{'family':22}{'n':>4}{'meanCov%':>10}{'defect%':>9}  flaggedExamples")
    defects = []
    for fam in sorted(byfam, key=lambda k: statistics.mean([x['coverage'] for x in byfam[k]])):
        xs = byfam[fam]; covs = [x['coverage'] for x in xs]
        flagged = [x for x in xs if x['flags']]
        defects += flagged
        ex = ','.join(sorted({x['context'] for x in flagged}))[:40]
        print(f"{fam:22}{len(xs):>4}{statistics.mean(covs):>10.1f}{100*len(flagged)/len(xs):>8.0f}%  {ex}")
    print(f"\n=== {len(defects)} flagged designs (systematic render defects) ===")
    for d in sorted(defects, key=lambda x: x['coverage'])[:30]:
        print(f"  {d['stem']:46} cov={d['coverage']}% {' '.join(d['flags'])}")
    out = {'samples': len(allrows), 'defects': len(defects), 'rows': allrows}
    outp = os.path.join(dirs[0] if len(dirs) == 1 else os.path.dirname(__file__),
                        'render_qa.json') if len(dirs) == 1 else '/tmp/render_qa.json'
    json.dump(out, open(outp, 'w'), indent=2)
    print(f"\nwrote {outp}")

if __name__ == '__main__':
    main()
