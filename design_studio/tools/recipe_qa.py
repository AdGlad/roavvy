#!/usr/bin/env python3
"""Automated recipe-QA over a procedural batch (Design Studio).

The host renderer is too flaky to rasterise large samples, so this scales the
testing loop the reliable way: it scans a recipe batch (hundreds of deterministic
designs from batch_generate) and flags DESIGN PATTERNS the pixel evidence proved
render badly — validating fixes and surfacing new defects across every family ×
context × seed, without rendering.

Rules encode the confirmed render findings:
  E-005  single country + no clip + rowCount>1      → flag "TILE-REPEAT"  (fixed)
  E-006  negativeSpaceCutout + montage layout        → flag "CUTOUT-UNDERFILL" (mitigated)
  F1     statementCount family                        → informational (hero path applies)
  frag   dominantAccent + small + montage + circle    → flag "FRAGMENT-RISK"
  qlow   quality < 0.50                               → flag "LOW-QUALITY"

Usage: python3 design_studio/tools/recipe_qa.py [batch.json]
Pure stdlib. Dev-only.
"""
import json, sys, os, glob, statistics, collections

def field(r, *names, default=None):
    for n in names:
        if n in r and r[n] is not None: return r[n]
    return default

# Colour treatments that tame/unify a multi-flag palette (KB R-FLAG-01/R-COL-04).
MUTING = {'muted', 'duotone', 'monoInk', 'vintageWarm'}

def flags_for(d):
    r = d.get('recipe', d)
    fam = field(r, 'family', default='?')
    mask = field(r, 'mask', default='none')
    layout = field(r, 'layoutMode', default='packedRow')
    rows = field(r, 'rowCount', default=1) or 1
    n = len(field(r, 'countryCodes', default=[]) or [])
    size = field(r, 'imageSize', default='medium')
    density = field(r, 'density', default='balanced')
    flagT = field(r, 'flagTreatment', default='fullColour')
    colT = field(r, 'colourTreatment', default='none')
    q = d.get('quality')
    out = []
    # ── render-defect patterns (confirmed on pixels) ──────────────────────────
    if n == 1 and mask == 'none' and rows and rows > 1:
        out.append('TILE-REPEAT')                       # E-005
    if fam == 'negativeSpaceCutout' and layout == 'montage':
        out.append('CUTOUT-UNDERFILL')                  # E-006
    if fam == 'dominantAccent' and size == 'small' and layout == 'montage' and mask == 'circle':
        out.append('FRAGMENT-RISK')                     # E-007
    # ── comprehensive KB design-rule checks ───────────────────────────────────
    if n >= 4 and flagT == 'fullColour' and colT not in MUTING:
        out.append('FLAG-CLASH')                        # R-FLAG-01 / R-COL-01
    if n <= 3 and density == 'dense':
        out.append('CRAMPED')                           # R-NEG-01
    if (n >= 16 and density == 'sparse') or (n <= 2 and density == 'dense'):
        out.append('DENSITY-MISMATCH')                  # R-MERCH-02
    if q is not None and q < 0.50:
        out.append('LOW-QUALITY')
    return fam, out

def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    if arg:
        paths = [arg]
    else:
        base = os.path.join(os.path.dirname(__file__), '..', 'generated_batches')
        paths = sorted(glob.glob(os.path.join(base, 'batch_v*', 'batch.json')))
        paths = [p for p in paths if '_' not in os.path.basename(os.path.dirname(p)).replace('batch_v', '')] or paths
    if not paths:
        print('no batch.json found — run batch_generate first'); return
    designs = []
    for p in paths:
        b = json.load(open(p))
        designs += b.get('designs', [])
    if not designs:
        print('no designs'); return
    byfam = collections.defaultdict(list)
    flagcount = collections.Counter()
    flagged = []
    for d in designs:
        fam, fl = flags_for(d)
        byfam[fam].append((d, fl))
        for f in fl: flagcount[f] += 1
        if fl: flagged.append((d, fam, fl))
    print(f"=== recipe QA: {len(designs)} designs across {len(byfam)} families "
          f"(source: {', '.join(os.path.basename(os.path.dirname(p)) for p in paths)}) ===")
    print(f"{'family':22}{'n':>5}{'meanQ':>8}{'defect%':>9}  defectTypes")
    for fam in sorted(byfam, key=lambda k: statistics.mean(
            [x[0].get('quality', 0) for x in byfam[k]])):
        xs = byfam[fam]
        qs = [x[0].get('quality', 0) for x in xs]
        fl = [x for x in xs if x[1]]
        types = collections.Counter(t for x in fl for t in x[1])
        ts = ','.join(f'{k}:{v}' for k, v in types.items())
        print(f"{fam:22}{len(xs):>5}{statistics.mean(qs):>8.3f}{100*len(fl)/len(xs):>8.0f}%  {ts}")
    print(f"\n=== defect totals: {dict(flagcount)} ({len(flagged)}/{len(designs)} designs flagged) ===")
    # show a few examples per defect type
    for ftype in flagcount:
        exs = [d for d, fam, fl in flagged if ftype in fl][:3]
        for d in exs:
            r = d.get('recipe', {})
            print(f"  [{ftype}] {d.get('context','?')} {r.get('family')}/{r.get('template')}/"
                  f"{r.get('mask')}/{r.get('layoutMode')} rows={r.get('rowCount')} "
                  f"n={len(r.get('countryCodes',[]))} q={d.get('quality')}")
    out = {'designs': len(designs), 'flagged': len(flagged), 'flagCounts': dict(flagcount)}
    json.dump(out, open('/tmp/recipe_qa.json', 'w'), indent=2)
    print("\nwrote /tmp/recipe_qa.json")

if __name__ == '__main__':
    main()
