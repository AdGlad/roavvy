import json, math, re, os

ROOT = '/Users/adglad/git/roavvy'
GEO = f'{ROOT}/apps/web_nextjs/public/data/countries.geojson'
CMAP = f'{ROOT}/packages/shared_models/lib/src/continent_map.dart'
OUT = f'{ROOT}/apps/mobile_flutter/assets/continent_paths'

CONT_KEY = {
    'Africa': 'africa', 'Asia': 'asia', 'Europe': 'europe',
    'North America': 'north_america', 'Oceania': 'oceania',
    'South America': 'south_america',
}
# Recognizable lon/lat window per continent (excludes trans-continental sprawl
# e.g. Siberia from Europe). Oceania is in UNWRAPPED lon (antimeridian shifted).
WINDOW = {
    'africa':        (-20, 52,  -38, 39),
    'asia':          (25, 150,  -11, 78),
    'europe':        (-32, 52,  34, 72),
    'north_america': (-172, -52, 7, 75),
    'oceania':       (110, 200, -48, 3),
    'south_america': (-82, -34, -56, 14),
}

iso2cont = {}
for m in re.finditer(r"'([A-Z]{2})'\s*:\s*'([^']+)'", open(CMAP).read()):
    iso2cont[m.group(1)] = m.group(2)

feats = json.load(open(GEO))['features']

def merc(lon, lat):
    lat = max(-85.0, min(85.0, lat))
    return lon, -math.degrees(math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)))

def ring_area(r):
    a = 0.0
    for i in range(len(r)):
        x1, y1 = r[i]; x2, y2 = r[(i + 1) % len(r)]
        a += x1 * y2 - x2 * y1
    return abs(a) / 2

# Sutherland–Hodgman polygon clip against a rectangle.
def clip(poly, xmin, ymin, xmax, ymax):
    def clip_edge(pts, inside, inter):
        out = []
        for i in range(len(pts)):
            a = pts[i]; b = pts[(i + 1) % len(pts)]
            ina, inb = inside(a), inside(b)
            if ina:
                out.append(a)
                if not inb: out.append(inter(a, b))
            elif inb:
                out.append(inter(a, b))
        return out
    def ix(a, b, x):  # x-crossing
        t = (x - a[0]) / (b[0] - a[0]); return [x, a[1] + t * (b[1] - a[1])]
    def iy(a, b, y):
        t = (y - a[1]) / (b[1] - a[1]); return [a[0] + t * (b[0] - a[0]), y]
    p = poly
    p = clip_edge(p, lambda q: q[0] >= xmin, lambda a, b: ix(a, b, xmin))
    if not p: return []
    p = clip_edge(p, lambda q: q[0] <= xmax, lambda a, b: ix(a, b, xmax))
    if not p: return []
    p = clip_edge(p, lambda q: q[1] >= ymin, lambda a, b: iy(a, b, ymin))
    if not p: return []
    p = clip_edge(p, lambda q: q[1] <= ymax, lambda a, b: iy(a, b, ymax))
    return p

def dp(points, eps):
    if len(points) < 3: return points
    dmax, idx = 0.0, 0
    ax, ay = points[0]; bx, by = points[-1]
    dx, dy = bx - ax, by - ay
    seglen = math.hypot(dx, dy) or 1e-9
    for i in range(1, len(points) - 1):
        px, py = points[i]
        d = abs((px - ax) * dy - (py - ay) * dx) / seglen
        if d > dmax: dmax, idx = d, i
    if dmax > eps:
        return dp(points[:idx + 1], eps)[:-1] + dp(points[idx:], eps)
    return [points[0], points[-1]]

for cont_name, key in CONT_KEY.items():
    members = {iso for iso, c in iso2cont.items() if c == cont_name}
    xmin, xmax, ymin, ymax = WINDOW[key]
    rings_ll = []
    for f in feats:
        if f['properties'].get('ISO_A2') not in members: continue
        g = f['geometry']
        polys = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]
        for poly in polys:
            ring = [[lon, lat] for lon, lat in poly[0]]
            if key == 'oceania':
                ring = [[lon + 360 if lon < -25 else lon, lat] for lon, lat in ring]
            ring = clip(ring, xmin, ymin, xmax, ymax)
            if len(ring) >= 3:
                rings_ll.append(ring)

    rings = [[merc(lon, lat) for lon, lat in r] for r in rings_ll]
    areas = [ring_area(r) for r in rings]
    total = sum(areas) or 1
    rings = [r for r, a in zip(rings, areas) if a >= 0.0003 * total]

    xs = [p[0] for r in rings for p in r]; ys = [p[1] for r in rings for p in r]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    w, h = maxx - minx, maxy - miny
    scale = 1000.0 / w
    normH = round(h * scale, 1)
    eps = 1.3 / scale

    polys = []
    for r in rings:
        if r[0] == r[-1]: r = r[:-1]         # drop closing dup (DP needs distinct ends)
        simp = dp(r, eps)
        if len(simp) < 3: continue
        polys.append([[round((x - minx) * scale, 1), round((y - miny) * scale, 1)]
                      for x, y in simp])

    json.dump({'w': 1000.0, 'h': normH, 'polys': polys},
              open(f'{OUT}/{key}.json', 'w'), separators=(',', ':'))
    print(f'{key}: {len(members)} countries -> {len(polys)} polys, AR {1000/normH:.2f}, '
          f'{os.path.getsize(f"{OUT}/{key}.json")//1024}KB')
