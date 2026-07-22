"""
Roavvy Quokka Mascot — Lottie Animation Generator (v2)
Character design based on official Roavvy brand reference images.
Run:  python3 tools/quokka_anim/gen_quokka_lottie.py
"""

import json, os

OUT = os.path.join(os.path.dirname(__file__),
                   '../../apps/mobile_flutter/assets/lottie')
os.makedirs(OUT, exist_ok=True)

# ── Palette (Lottie 0-1 float colors) ────────────────────────────────────────
# Based on official Roavvy quokka reference images
def rgb(r, g, b): return [r/255, g/255, b/255, 1]

C = dict(
    fur      = rgb(200, 121, 58),   # warm golden-brown  #C8793A
    furDark  = rgb(130,  74, 22),   # darker shading     #82481A
    furMid   = rgb(162,  95, 40),   # mid shadow         #A25F28
    furLight = rgb(220, 150, 80),   # highlight/rim      #DC9650
    earInner = rgb(155,  82, 28),   # ear inner shade    #9B521C
    eyeW     = rgb(252, 250, 248),  # eye sclera
    eyeIris  = rgb( 92,  52, 18),   # brown iris         #5C3412
    eyePupil = rgb( 14,   6,  2),   # near-black pupil
    eyeHL    = rgb(255, 255, 255),  # specular highlight
    eyeHL2   = rgb(200, 190, 180),  # soft secondary HL
    nose     = rgb( 28,  12,  4),   # very dark nose     #1C0C04
    noseMid  = rgb( 55,  28, 10),   # nose mid-tone
    paw      = rgb( 92,  45, 10),   # dark paws/feet     #5C2D0A
    tail     = rgb( 78,  36,  8),   # tail dark brown    #4E2408
    bandana  = rgb( 31,  45, 74),   # navy bandana       #1F2D4A
    bandHL   = rgb( 45,  65, 100),  # bandana highlight
    mouth    = rgb( 18,   8,  2),   # open mouth dark
    teeth    = rgb(245, 240, 232),  # cream teeth
    tongue   = rgb(200, 105, 88),   # tongue pink        #C86958
    mouthOut = rgb(115,  58, 18),   # mouth outline
)

SW = 3.0  # default stroke width

# ── Lottie primitives ─────────────────────────────────────────────────────────

def P(v):    return {"a": 0, "k": v}

def A(*keyframes):
    """Animated property. keyframes = [(frame, value), ...] Last gets no ease."""
    kfs = []
    for idx, (t, v) in enumerate(keyframes):
        s = v if isinstance(v, list) else [v]
        entry = {"t": t, "s": s}
        if idx < len(keyframes) - 1:
            entry["i"] = {"x": [0.5], "y": [1.0]}
            entry["o"] = {"x": [0.5], "y": [0.0]}
        kfs.append(entry)
    return {"a": 1, "k": kfs}

def EL(cx, cy, w, h):
    return {"ty": "el", "d": 1, "nm": "el", "p": P([cx, cy]), "s": P([w, h])}

def RC(cx, cy, w, h, r=0):
    return {"ty": "rc", "d": 1, "nm": "rc",
            "p": P([cx, cy]), "s": P([w, h]), "r": P(r)}

def SH(verts, inT, outT, closed=False):
    return {"ty": "sh", "d": 1, "nm": "sh",
            "ks": P({"v": verts, "i": inT, "o": outT, "c": closed})}

def FL(c, op=100): return {"ty":"fl","c":P(c),"o":P(op),"r":1,"nm":"fl"}
def ST(c, w, op=100): return {"ty":"st","c":P(c),"o":P(op),"w":P(w),"lc":2,"lj":2,"nm":"st"}

def TR(px, py, ax=0, ay=0, sx=100, sy=100, rot=0, op=100):
    return {"ty":"tr","p":P([px,py]),"a":P([ax,ay]),
            "s":P([sx,sy]),"r":P(rot),"o":P(op),"sk":P(0),"sa":P(0),"nm":"tr"}

def GR(items, name="g", px=0, py=0, ax=0, ay=0,
       sx=100, sy=100, rot=0, op=100):
    t = TR(px, py, ax, ay, sx, sy, rot, op)
    it = list(items) + [t]
    return {"ty":"gr","nm":name,"it":it,"np":len(it)}

def KS(px=100, py=100, ax=100, ay=100, sx=100, sy=100, rot=0, op=100):
    return {"o":P(op),"r":P(rot),"p":P([px,py,0]),"a":P([ax,ay,0]),"s":P([sx,sy,100])}

def KSA(p=None, s=None, r=None, o=None,
        px=100, py=100, ax=100, ay=100, sx=100, sy=100, rot=0, op=100):
    return {
        "o": o  if o else P(op),
        "r": r  if r else P(rot),
        "p": p  if p else P([px,py,0]),
        "a": P([ax,ay,0]),
        "s": s  if s else P([sx,sy,100]),
    }

def PA(*kfs):  return A(*[(t,[x,y,0]) for t,x,y in kfs])
def SA(*kfs):  return A(*[(t,[x,y,100]) for t,x,y in kfs])
def RA(*kfs):  return A(*kfs)
def OA(*kfs):  return A(*kfs)

def SL(name, ind, shapes, ip, op_f, layer_ks=None):
    return {"ddd":0,"ind":ind,"ty":4,"nm":name,"sr":1,
            "ks":layer_ks or KS(),"ao":0,
            "shapes":shapes,"ip":ip,"op":op_f,"st":0,"bm":0}

def DOC(name, dur_s, layers, fps=30):
    op_f = round(dur_s * fps)
    return {"v":"5.7.4","fr":fps,"ip":0,"op":op_f,
            "w":200,"h":200,"nm":name,"ddd":0,"assets":[],"layers":layers}

# ═══════════════════════════════════════════════════════════════════════════════
# CHARACTER SHAPE LIBRARY
# Based on official Roavvy quokka reference images (200×200 canvas)
#
# Anatomy layout:
#   Ear tops:    y ≈ 18  (round, no pink)
#   Head centre: (100, 80)  size 106×100
#   Eyes:        (80,74) / (120,74)  large with white sclera
#   Nose:        (100, 96)  large dark oval
#   Smile:       (100, 108)  open mouth
#   Bandana:     triangle, top ~y=118, point y=155
#   Body centre: (100, 158)  size 96×82
#   Arms:        (63,148) / (137,148)
#   Paws:        (60,167) / (140,167)
#   Feet:        (82,186) / (118,186)
#   Tail:        exits lower-right (150,168)
# ═══════════════════════════════════════════════════════════════════════════════

def ear_shapes():
    """Round ears — darker inside, no pink. Rendered behind head."""
    return [
        # Left ear: outer
        GR([EL(0,0, 38, 38), FL(C['fur']), ST(C['furDark'], SW)], "EarLo", px=66, py=36),
        # Left ear: inner shadow (slightly darker, centered)
        GR([EL(0,0, 24, 24), FL(C['earInner'])], "EarLi", px=66, py=38),
        # Right ear: outer
        GR([EL(0,0, 38, 38), FL(C['fur']), ST(C['furDark'], SW)], "EarRo", px=134, py=36),
        # Right ear: inner shadow
        GR([EL(0,0, 24, 24), FL(C['earInner'])], "EarRi", px=134, py=38),
    ]

def head_shapes():
    """Head base — round, large. Core fur body of the face."""
    return [
        # Head base
        GR([EL(0,0, 108, 102), FL(C['fur']), ST(C['furDark'], SW)], "HeadBase", px=100, py=80),
        # Subtle forehead highlight (lighter ellipse top-center)
        GR([EL(0,0, 60, 36), FL(C['furLight'])], "HeadHL", px=100, py=60, op=35),
        # Jaw/chin shadow
        GR([EL(0,0, 70, 30), FL(C['furMid'])], "HeadShd", px=100, py=108, op=45),
    ]

def face_shapes():
    """Face features: eyes, nose, mouth. Rendered on top of head."""
    return [
        # ── Eyes ─────────────────────────────────────────────────────────────
        # Left: sclera → iris → pupil → highlight
        GR([EL(0,0, 28, 30), FL(C['eyeW']), ST(C['furDark'], 1.5)], "EyLW", px=80, py=74),
        GR([EL(0,0, 20, 22), FL(C['eyeIris'])],                      "EyLI", px=80, py=76),
        GR([EL(0,0, 12, 14), FL(C['eyePupil'])],                     "EyLP", px=80, py=77),
        GR([EL(0,0,  9,  9), FL(C['eyeHL'])],                        "EyLH", px=86, py=71),
        GR([EL(0,0,  5,  5), FL(C['eyeHL2'])],                       "EyLH2",px=78, py=79, op=60),

        # Right: sclera → iris → pupil → highlight
        GR([EL(0,0, 28, 30), FL(C['eyeW']), ST(C['furDark'], 1.5)], "EyRW", px=120, py=74),
        GR([EL(0,0, 20, 22), FL(C['eyeIris'])],                      "EyRI", px=120, py=76),
        GR([EL(0,0, 12, 14), FL(C['eyePupil'])],                     "EyRP", px=121, py=77),
        GR([EL(0,0,  9,  9), FL(C['eyeHL'])],                        "EyRH", px=126, py=71),
        GR([EL(0,0,  5,  5), FL(C['eyeHL2'])],                       "EyRH2",px=118, py=79, op=60),

        # ── Nose ──────────────────────────────────────────────────────────────
        # Large dark oval — the quokka's most prominent feature
        GR([EL(0,0, 26, 19), FL(C['nose'])],    "NoseBase",  px=100, py=97),
        GR([EL(0,0, 14, 10), FL(C['noseMid'])], "NoseMid",   px=100, py=94, op=60),
        GR([EL(0,0,  7,  5), FL(C['eyeHL'])],   "NoseHL",    px=103, py=92, op=50),

        # ── Mouth ─────────────────────────────────────────────────────────────
        # Open smile: dark interior + teeth strip + tongue hint
        GR([EL(0,0, 30, 14), FL(C['mouth'])],    "MthDk",  px=100, py=110),
        GR([RC(0,0, 24,  8, 4), FL(C['teeth'])], "MthTth", px=100, py=107),
        GR([EL(0,0, 18,  8), FL(C['tongue'])],   "MthTng", px=100, py=113, op=80),

        # Smile corner curves
        GR([SH([[-14, -3],[0, 4],[14,-3]],
               [[0,0],[-6,0],[0,0]],
               [[6,0],[6,0],[0,0]], False),
            ST(C['mouthOut'], 2.5)], "SmileCrv", px=100, py=108),

        # Philtrum groove (subtle line from nose to upper lip)
        GR([SH([[0,-8],[0,8]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['furMid'], 1.5)], "Philt", px=100, py=103, op=40),
    ]

def body_shapes():
    """Round plump body — same fur colour throughout, no belly patch."""
    return [
        # Main body ellipse — centred a bit higher so feet peek out below
        GR([EL(0,0, 96, 74), FL(C['fur']), ST(C['furDark'], SW)], "BodyBase", px=100, py=153),
        # Top highlight
        GR([EL(0,0, 56, 28), FL(C['furLight'])], "BodyHL", px=100, py=136, op=30),
        # Lower shadow
        GR([EL(0,0, 76, 36), FL(C['furMid'])], "BodyShd", px=100, py=170, op=40),
    ]

def bandana_shapes():
    """Navy Roavvy bandana (triangle V-shape)."""
    front_v   = [[-38, -14], [38, -14], [0, 22]]
    front_in  = [[0, 0], [0, 0], [0, 0]]
    front_out = [[0, 0], [0, 0], [0, 0]]
    return [
        # Neck band strip
        GR([RC(0,0, 80, 16, 4), FL(C['bandana'])],         "BandTop",   px=100, py=120),
        # Bandana front triangle
        GR([SH(front_v, front_in, front_out, True),
            FL(C['bandana']), ST(C['furDark'], 1.0)],        "BandFront", px=100, py=136),
        # Subtle highlight on bandana fold
        GR([SH([[-28, -12],[0, 10]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['bandHL'], 1.5)],                           "BandHL",    px=100, py=138, op=50),
    ]

def arm_left_shapes(rot=20):
    """Left arm — short stubby with dark paw."""
    return [
        GR([RC(0,0, 22, 42, 11), FL(C['fur']), ST(C['furDark'], SW)],
           "ArmL", px=62, py=145, ax=0, ay=-16, rot=rot),
        GR([EL(0,0, 22, 18), FL(C['paw']), ST(C['furDark'], 2.0)],
           "PawL", px=54, py=163),
        # Toe divider lines
        GR([SH([[0,-5],[0,5]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeL1", px=50, py=163),
        GR([SH([[0,-6],[0,6]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeL2", px=55, py=163),
        GR([SH([[0,-5],[0,5]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeL3", px=60, py=163),
    ]

def arm_right_shapes(rot=-20):
    """Right arm — short stubby with dark paw."""
    return [
        GR([RC(0,0, 22, 42, 11), FL(C['fur']), ST(C['furDark'], SW)],
           "ArmR", px=138, py=145, ax=0, ay=-16, rot=rot),
        GR([EL(0,0, 22, 18), FL(C['paw']), ST(C['furDark'], 2.0)],
           "PawR", px=146, py=163),
        GR([SH([[0,-5],[0,5]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeR1", px=141, py=163),
        GR([SH([[0,-6],[0,6]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeR2", px=146, py=163),
        GR([SH([[0,-5],[0,5]], [[0,0],[0,0]], [[0,0],[0,0]], False),
            ST(C['tail'], 1.5)], "ToeR3", px=151, py=163),
    ]

def leg_left_shapes():
    return [
        GR([RC(0,0, 26, 28, 13), FL(C['fur']), ST(C['furDark'], SW)],
           "LegL", px=80, py=182, ax=0, ay=-8),
        GR([EL(0,0, 28, 15), FL(C['paw'])], "FootL", px=78, py=193),
    ]

def leg_right_shapes():
    return [
        GR([RC(0,0, 26, 28, 13), FL(C['fur']), ST(C['furDark'], SW)],
           "LegR", px=120, py=182, ax=0, ay=-8),
        GR([EL(0,0, 28, 15), FL(C['paw'])], "FootR", px=122, py=193),
    ]

def tail_shapes():
    """Thin curved tail — exits lower-right side of body."""
    return [
        GR([EL(0,0, 18, 30), FL(C['tail']), ST(C['furDark'], 2.0)],
           "TailBase", px=152, py=165, rot=-22),
        GR([EL(0,0, 10, 18), FL(C['tail'])],
           "TailTip", px=158, py=179, rot=-30),
    ]

# ── Layer assembler ───────────────────────────────────────────────────────────
# Lottie render order: first in array = on top, last = background
#   0 Face details  ← top
#   1 Head base
#   2 Ears
#   3 Bandana
#   4 Left arm (in front of legs + body)
#   5 Right arm
#   6 Left leg (in front of body so feet are visible)
#   7 Right leg
#   8 Body
#   9 Tail          ← back

def build_layers(ip, op_f, K=None):
    K = K or {}
    arm_l_rot = K.pop('armLrot', 20)
    arm_r_rot = K.pop('armRrot', -20)
    layers = []
    i = 1
    defs = [
        ("Face",    face_shapes(),               "face"),
        ("Head",    head_shapes(),               "head"),
        ("Ears",    ear_shapes(),                "ears"),
        ("Bandana", bandana_shapes(),            "band"),
        ("ArmL",    arm_left_shapes(arm_l_rot),  "armL"),
        ("ArmR",    arm_right_shapes(arm_r_rot), "armR"),
        ("LegL",    leg_left_shapes(),           "legL"),
        ("LegR",    leg_right_shapes(),          "legR"),
        ("Body",    body_shapes(),               "body"),
        ("Tail",    tail_shapes(),               "tail"),
    ]
    for name, shapes, key in defs:
        layers.append(SL(name, i, shapes, ip, op_f, K.get(key)))
        i += 1
    return layers

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

def anim_idle():
    K = dict(
        body = KSA(
            s=SA((0,100,100),(45,102,102),(90,100,100)),
            p=PA((0,100,100),(45,100,101),(90,100,100)),
        ),
        head = KSA(
            s=SA((0,100,100),(45,101,101),(90,100,100)),
            p=PA((0,100,100),(45,100,101),(90,100,100)),
        ),
        face = KSA(
            s=SA((0,100,100),(45,101,101),(90,100,100)),
            p=PA((0,100,100),(45,100,101),(90,100,100)),
        ),
        ears = KSA(
            s=SA((0,100,100),(45,101,101),(90,100,100)),
            p=PA((0,100,100),(45,100,101),(90,100,100)),
        ),
        band = KSA(
            s=SA((0,100,100),(45,101.5,101.5),(90,100,100)),
            p=PA((0,100,100),(45,100,101),(90,100,100)),
        ),
        armL = KSA(r=RA((0,0),(30,4),(60,0),(90,0))),
        armR = KSA(r=RA((0,0),(30,-4),(60,0),(90,0))),
    )
    return DOC("Quokka Idle", 3.0, build_layers(0, 90, K))

def anim_wave():
    K = dict(
        armRrot = -75,
        head = KSA(r=RA((0,0),(10,-6),(25,5),(37,-4),(45,0))),
        face = KSA(r=RA((0,0),(10,-6),(25,5),(37,-4),(45,0))),
        ears = KSA(r=RA((0,0),(10,-6),(25,5),(37,-4),(45,0))),
        body = KSA(r=RA((0,0),(12,3),(28,-2),(45,0))),
        band = KSA(r=RA((0,0),(12,3),(28,-2),(45,0))),
        armL = KSA(r=RA((0,0),(15,6),(30,-3),(45,0))),
        armR = KSA(r=RA((0,0),(8,-25),(16,15),(24,-28),(32,10),(45,0))),
    )
    return DOC("Quokka Wave", 1.5, build_layers(0, 45, K))

def anim_dance():
    hop_p = PA((0,100,100),(8,100,92),(15,100,100),(23,100,92),(30,100,100),
               (38,100,92),(45,100,100),(53,100,92),(60,100,100))
    hop_s = SA((0,100,100),(8,104,96),(15,100,100),(23,104,96),(30,100,100),
               (38,104,96),(45,100,100),(53,104,96),(60,100,100))
    head_r = RA((0,0),(8,-10),(15,0),(23,10),(30,0),(38,-10),(45,0),(53,10),(60,0))
    K = dict(
        armLrot = 30, armRrot = -30,
        body  = KSA(p=hop_p, s=hop_s),
        head  = KSA(p=PA((0,100,100),(8,100,90),(15,100,100),(23,100,90),(30,100,100),
                         (38,100,90),(45,100,100),(53,100,90),(60,100,100)), r=head_r),
        face  = KSA(p=PA((0,100,100),(8,100,90),(15,100,100),(23,100,90),(30,100,100),
                         (38,100,90),(45,100,100),(53,100,90),(60,100,100)), r=head_r),
        ears  = KSA(p=PA((0,100,100),(8,100,90),(15,100,100),(23,100,90),(30,100,100),
                         (38,100,90),(45,100,100),(53,100,90),(60,100,100)), r=head_r),
        band  = KSA(p=hop_p),
        armL  = KSA(r=RA((0,0),(15,-42),(30,0),(45,-42),(60,0))),
        armR  = KSA(r=RA((0,0),(15,42),(30,0),(45,42),(60,0))),
        legL  = KSA(r=RA((0,0),(10,14),(20,0),(30,-12),(40,0),(50,14),(60,0))),
        legR  = KSA(r=RA((0,0),(10,-14),(20,0),(30,12),(40,0),(50,-14),(60,0))),
    )
    return DOC("Quokka Dance", 2.0, build_layers(0, 60, K))

def anim_celebrate():
    K = dict(
        armLrot = -55, armRrot = 55,
        body  = KSA(
            p=PA((0,100,100),(12,100,76),(22,100,76),(35,100,104),(45,100,100),(60,100,100)),
            s=SA((0,100,100),(12,114,114),(22,114,114),(35,98,98),(45,100,100),(60,100,100)),
        ),
        head  = KSA(
            p=PA((0,100,100),(12,100,74),(22,100,74),(35,100,102),(45,100,100),(60,100,100)),
            s=SA((0,100,100),(12,112,112),(22,112,112),(35,98,98),(45,100,100),(60,100,100)),
            r=RA((0,0),(10,-12),(22,10),(35,0),(60,0)),
        ),
        face  = KSA(
            p=PA((0,100,100),(12,100,74),(22,100,74),(35,100,102),(45,100,100),(60,100,100)),
            s=SA((0,100,100),(12,112,112),(22,112,112),(35,98,98),(45,100,100),(60,100,100)),
            r=RA((0,0),(10,-12),(22,10),(35,0),(60,0)),
        ),
        ears  = KSA(
            p=PA((0,100,100),(12,100,74),(22,100,74),(35,100,102),(45,100,100),(60,100,100)),
            s=SA((0,100,100),(12,112,112),(22,112,112),(35,98,98),(45,100,100),(60,100,100)),
        ),
        band  = KSA(
            p=PA((0,100,100),(12,100,76),(22,100,76),(35,100,104),(45,100,100),(60,100,100)),
            s=SA((0,100,100),(12,114,114),(22,114,114),(35,98,98),(45,100,100),(60,100,100)),
        ),
        armL  = KSA(
            r=RA((0,0),(8,-72),(18,-82),(35,-70),(50,-25),(60,0)),
            s=SA((0,100,100),(12,112,112),(22,112,112),(40,100,100),(60,100,100)),
        ),
        armR  = KSA(
            r=RA((0,0),(8,72),(18,82),(35,70),(50,25),(60,0)),
            s=SA((0,100,100),(12,112,112),(22,112,112),(40,100,100),(60,100,100)),
        ),
        legL  = KSA(p=PA((0,100,100),(12,98,90),(22,98,90),(35,100,100),(60,100,100))),
        legR  = KSA(p=PA((0,100,100),(12,102,90),(22,102,90),(35,100,100),(60,100,100))),
    )
    return DOC("Quokka Celebrate", 2.0, build_layers(0, 60, K))

def anim_walk():
    def hop(phase):
        frames = [(0+phase*8, 100, 100), (4+phase*8, 100, 96), (8+phase*8, 100, 100)]
        return frames
    body_p = PA((0,100,100),(8,100,96),(15,100,100),(23,100,96),(30,100,100),
                (38,100,96),(45,100,100))
    head_p = PA((0,100,100),(8,100,95),(15,100,100),(23,100,95),(30,100,100),
                (38,100,95),(45,100,100))
    K = dict(
        body  = KSA(p=body_p, r=RA((0,0),(8,4),(15,0),(23,-4),(30,0),(38,4),(45,0))),
        head  = KSA(p=head_p, r=RA((0,0),(8,-4),(15,0),(23,4),(30,0),(38,-4),(45,0))),
        face  = KSA(p=head_p, r=RA((0,0),(8,-4),(15,0),(23,4),(30,0),(38,-4),(45,0))),
        ears  = KSA(p=head_p, r=RA((0,0),(8,-4),(15,0),(23,4),(30,0),(38,-4),(45,0))),
        band  = KSA(p=body_p, r=RA((0,0),(8,4),(15,0),(23,-4),(30,0),(38,4),(45,0))),
        armL  = KSA(r=RA((0,-22),(8,22),(15,-22),(23,22),(30,-22),(38,22),(45,-22))),
        armR  = KSA(r=RA((0,22),(8,-22),(15,22),(23,-22),(30,22),(38,-22),(45,22))),
        legL  = KSA(r=RA((0,-18),(8,18),(15,-18),(23,18),(30,-18),(38,18),(45,-18))),
        legR  = KSA(r=RA((0,18),(8,-18),(15,18),(23,-18),(30,18),(38,-18),(45,18))),
    )
    return DOC("Quokka Walk", 1.5, build_layers(0, 45, K))

def anim_point():
    K = dict(
        armRrot = -88,
        body  = KSA(r=RA((0,0),(15,7),(30,7),(50,4),(60,0)),
                    s=SA((0,100,100),(15,104,96),(30,104,96),(50,102,98),(60,100,100))),
        head  = KSA(r=RA((0,0),(15,-10),(30,-10),(50,-5),(60,0)),
                    p=PA((0,100,100),(15,104,100),(30,104,100),(50,102,100),(60,100,100))),
        face  = KSA(r=RA((0,0),(15,-10),(30,-10),(50,-5),(60,0)),
                    p=PA((0,100,100),(15,104,100),(30,104,100),(50,102,100),(60,100,100))),
        ears  = KSA(r=RA((0,0),(15,-10),(30,-10),(50,-5),(60,0)),
                    p=PA((0,100,100),(15,104,100),(30,104,100),(50,102,100),(60,100,100))),
        band  = KSA(r=RA((0,0),(15,7),(30,7),(50,4),(60,0)),
                    s=SA((0,100,100),(15,104,96),(30,104,96),(50,102,98),(60,100,100))),
        armL  = KSA(r=RA((0,0),(15,15),(30,15),(50,8),(60,0))),
        armR  = KSA(r=RA((0,0),(12,-55),(22,-90),(38,-90),(52,-35),(60,0)),
                    s=SA((0,100,100),(22,108,108),(38,108,108),(52,100,100),(60,100,100))),
        legL  = KSA(r=RA((0,0),(15,-5),(30,-5),(50,-2),(60,0))),
        legR  = KSA(r=RA((0,0),(15,5),(30,5),(50,2),(60,0))),
    )
    return DOC("Quokka Point", 2.0, build_layers(0, 60, K))

def anim_think():
    K = dict(
        armLrot = 65,
        head  = KSA(r=RA((0,0),(15,12),(30,8),(45,14),(60,10)),
                    p=PA((0,100,100),(15,97,100),(30,97,100),(60,97,100))),
        face  = KSA(r=RA((0,0),(15,12),(30,8),(45,14),(60,10)),
                    p=PA((0,100,100),(15,97,100),(30,97,100),(60,97,100))),
        ears  = KSA(r=RA((0,0),(15,12),(30,8),(45,14),(60,10)),
                    p=PA((0,100,100),(15,97,100),(30,97,100),(60,97,100))),
        body  = KSA(r=RA((0,0),(15,5),(30,5),(45,5),(60,5)),
                    s=SA((0,100,100),(15,98,102),(30,98,102),(60,98,102))),
        band  = KSA(r=RA((0,0),(15,5),(30,5),(45,5),(60,5))),
        armL  = KSA(r=RA((0,0),(10,72),(20,62),(35,74),(50,66),(60,0))),
        armR  = KSA(r=RA((0,0),(15,-8),(30,-5),(60,0))),
        legL  = KSA(r=RA((0,0),(15,4),(30,4),(60,4))),
        legR  = KSA(r=RA((0,0),(15,-4),(30,-4),(60,-4))),
    )
    return DOC("Quokka Think", 2.0, build_layers(0, 60, K))

# ── Write all animations ──────────────────────────────────────────────────────

ANIMATIONS = {
    "quokka_idle.json":      anim_idle,
    "quokka_wave.json":      anim_wave,
    "quokka_dance.json":     anim_dance,
    "quokka_celebrate.json": anim_celebrate,
    "quokka_walk.json":      anim_walk,
    "quokka_point.json":     anim_point,
    "quokka_think.json":     anim_think,
}

print("Generating Roavvy Quokka Lottie animations (v2 — brand-matched)...")
for filename, fn in ANIMATIONS.items():
    data = fn()
    path = os.path.join(OUT, filename)
    with open(path, 'w') as f:
        json.dump(data, f, separators=(',', ':'))
    size_kb = os.path.getsize(path) / 1024
    print(f"  {filename}: {data['op']} frames, {size_kb:.1f} KB")

print(f"\nSaved to {OUT}")
print("Reload preview.html to see updated character")
