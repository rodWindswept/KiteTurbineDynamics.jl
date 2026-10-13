#!/usr/bin/env python3
# system-anatomy.py — F1 system-anatomy figure generator (figures seat, 2026-10-12)
#
# Emits, from one computed layout:
#   prototype.html       — round-1 composition mock (HTML/SVG, true geometry)
#   system-anatomy.tex   — the TikZ build (computed coordinates, cm units)
#
# Source geometry: the island-3 winner decode, reproduced by
# scratch/fig1_decode_winner.jl (same decode/build path as the certified
# machine-evolution-strip generator): design_from_vector_v10 ->
# size_beams_closed_form -> build_system_from_v10, no ODE.
#   data commit dd3cc6a (bankderate2) · winner genome i3-g26-i9 (gen 26)
#
# Register bindings (no other number prints):
#   NR-011  rings 6, n_lines 3, n_active 1, r_hub 4.580 m, r_bot 0.804 m
#   NR-017  main-rotor bank 7.088 deg at ring 6
#   NR-043  winner blade span 1.499 m at three decimals (v4 re-cut)
# Standing rule: the 22.0 slot value never prints as a rotor angle.
# Held-term picks pending (Track D): the knot name and the cyan-line name
# print here in the register/room form ("sky anchor", "cyan line"); the
# label set flips with the picks at the author-seat pass.
#
# Frame: deployment side elevation; the shaft sits at the operating
# elevation (30 deg model convention) so the lift chain and the wind read
# in the field frame.  Wind left to right; the ground station is upwind.
# Elevation number: no signed row yet, so the figure carries the beta glyph
# without a value.
#
# Run:  /usr/bin/python3 system-anatomy.py    (from this directory)

import math

# ---- decoded winner geometry (metres; from scratch/fig1_decode_winner.log) ----
COS30 = math.cos(math.radians(30.0))
SIN30 = math.sin(math.radians(30.0))
U = (COS30, SIN30)                    # shaft, up-shaft direction (downwind)
N = (-SIN30, COS30)                   # shaft-plane normal (up)

O = (0.0, 0.85)                       # R1 centre; raised so the ring clears the floor

RINGS = [                             # (station s, radius r) R1 -> R6
    (0.000000, 0.803683),
    (2.368716, 0.803683),
    (4.737359, 0.803683),
    (7.105929, 0.803683),
    (9.474428, 0.803683),
    (18.826179, 4.579979),
]
R_RING, R_HUB = 0.803683, 4.579979
ROPE_OFF = R_RING * COS30             # 0.696008 line attach radius, lower rings
HUB_OFF = R_HUB * COS30               # 3.966437 line attach radius, R6

ROTOR = {"r_in": 4.130158, "s_in": 18.882113, "r_out": 5.629560, "s_out": 18.695668,
         "bank": 7.088131}
BLADES = [                            # (rho_in, s_in, rho_out, s_out)
    (4.130158, 18.882113, 5.629560, 18.695668),
    (-2.065079, 18.882113, -2.814780, 18.695668),
    (-2.065079, 18.882113, -2.814780, 18.695668),
]
BEARING_OFF = 7.622365                # bridle_bearing_offset(r_top) = r_top/tan(31)
CYAN_L = 5.0                          # cyan_L0, the cut rope length
BACK_FWD = 11.0                       # BACK_ANCHOR_FWD_X_M, field placement
LIFT_ANG = math.radians(70.0)         # lifter elevation, model convention
LIFTDIR = (math.cos(LIFT_ANG), math.sin(LIFT_ANG))
KITE_L = [3.0, 5.5, 8.0]              # lifter disks along the lift line
KITE_HALF = 1.0

# ---- derived placement ----
def P(s, rho):
    return (O[0] + s * U[0] + rho * N[0], O[1] + s * U[1] + rho * N[1])

RING_PTS = [P(s, r) for (s, r) in RINGS]
R6C = P(RINGS[5][0], 0.0)
BEARING = P(RINGS[5][0] + BEARING_OFF, 0.0)
SKY = P(RINGS[5][0] + BEARING_OFF + CYAN_L, 0.0)
BACK_ANCHOR = (18.8 * COS30 + BACK_FWD, 0.0)
BLADE_PTS = [(P(si, ri), P(so, ro)) for (ri, si, ro, so) in BLADES]

# ---- blade-span dimension (NR-043): parallel to the drawn blade, down-left ----
SPAN_LABEL = f"{ROTOR['r_out'] - ROTOR['r_in']:.3f} m"   # 1.499 m, the drawn form
_B0, _B1 = BLADE_PTS[0]                                  # inner edge -> tip
_bl = math.hypot(_B1[0] - _B0[0], _B1[1] - _B0[1])
_bu = ((_B1[0] - _B0[0]) / _bl, (_B1[1] - _B0[1]) / _bl)
_bn = (-_bu[1], _bu[0])                                  # offset normal, down-left
DIM_OFF, DIM_GAP = 1.05, 0.15                            # line offset, extension gap
DIM_I = (_B0[0] + DIM_OFF * _bn[0], _B0[1] + DIM_OFF * _bn[1])
DIM_T = (_B1[0] + DIM_OFF * _bn[0], _B1[1] + DIM_OFF * _bn[1])
DIM_I0 = (_B0[0] + DIM_GAP * _bn[0], _B0[1] + DIM_GAP * _bn[1])
DIM_T0 = (_B1[0] + DIM_GAP * _bn[0], _B1[1] + DIM_GAP * _bn[1])
DIM_I2 = (_B0[0] + (DIM_OFF + DIM_GAP) * _bn[0], _B0[1] + (DIM_OFF + DIM_GAP) * _bn[1])
DIM_T2 = (_B1[0] + (DIM_OFF + DIM_GAP) * _bn[0], _B1[1] + (DIM_OFF + DIM_GAP) * _bn[1])
SPAN_LDR_A, SPAN_LDR_B = (11.05, 15.07), (13.176, 13.596)  # label leader

ROPE_SEGS = []
for k in range(5):
    s0, s1 = RINGS[k][0], RINGS[k + 1][0]
    if k < 4:
        pairs = [(0.0, 0.0), (ROPE_OFF, ROPE_OFF), (-ROPE_OFF, -ROPE_OFF)]
    else:
        pairs = [(0.0, 0.0), (ROPE_OFF, HUB_OFF), (-ROPE_OFF, -HUB_OFF)]
    for (o0, o1) in pairs:
        ROPE_SEGS.append((P(s0, o0), P(s1, o1)))

BRIDLE_TARGETS = [P(RINGS[5][0], 0.0), P(RINGS[5][0], HUB_OFF), P(RINGS[5][0], -HUB_OFF)]
BRIDLES = [(BEARING, t) for t in BRIDLE_TARGETS]

KITE_CENTRES = [(SKY[0] + L * LIFTDIR[0], SKY[1] + L * LIFTDIR[1]) for L in KITE_L]
NP_K = (-LIFTDIR[1], LIFTDIR[0])       # disk plane direction
KITE_DISKS = [((c[0] - KITE_HALF * NP_K[0], c[1] - KITE_HALF * NP_K[1]),
               (c[0] + KITE_HALF * NP_K[0], c[1] + KITE_HALF * NP_K[1]))
              for c in KITE_CENTRES]

STATION = (-1.50, 0.0, 1.35, 1.95)     # x0, z0, x1, z1 (dashed block)
GROUND_Z = 0.0
GROUND_X = (-4.0, 32.0)

WINDS = [(-3.4, 10.6), (-3.4, 11.9), (-3.4, 13.2)]

BETA_C = O
BETA_R = 2.2

# ---- layout constants ----
K = 0.65                              # cm per metre (authoring scale)
XMIN, XMAX = -4.0, 32.0
ZMIN, ZMAX = -1.7, 26.6
W_CM = (XMAX - XMIN) * K
H_CM = (ZMAX - ZMIN) * K

def tx(x, z):
    return ((x - XMIN) * K, (z - ZMIN) * K)

def f3(p):
    return f"({p[0]:.3f},{p[1]:.3f})"

# ---- label table (metres): (pos, anchor, lines, leaders, style) ----
LABELS: list = [
    dict(name="lifter", pos=(27.40, 23.55), anchor="east",
         lines=["lifter stack", "autogyro rotors, lift only"],
         leaders=[((27.45, 23.95), (29.10, 24.28))]),
    dict(name="liftline", pos=(27.60, 20.30), anchor="east",
         lines=["lift line"],
         leaders=[((27.65, 20.45), (28.62, 20.50))]),
    dict(name="skyanchor", pos=(26.50, 17.50), anchor="east",
         lines=["sky anchor", "the three-way knot"],
         leaders=[((26.55, 17.70), (27.23, 16.72))]),
    dict(name="cyanline", pos=(25.90, 13.60), anchor="east",
         lines=["cyan line"],
         leaders=[((25.85, 13.75), (25.40, 15.52))]),
    dict(name="bearing", pos=(25.20, 12.55), anchor="east",
         lines=["lift bearing"],
         leaders=[((25.25, 12.70), (23.18, 13.88))]),
    dict(name="bridles", pos=(21.00, 15.60), anchor="east",
         lines=["bridles (three)"],
         leaders=[((20.95, 15.72), (20.60, 14.15))]),
    dict(name="mainrotor", pos=(15.40, 4.05), anchor="west",
         lines=["main rotor (R6)", "three blades, bank 7.088°"],
         leaders=[((15.35, 4.30), (17.30, 7.52))]),
    dict(name="bladespan", pos=(10.90, 15.20), anchor="east",
         lines=["blade span", SPAN_LABEL],
         leaders=[(SPAN_LDR_A, SPAN_LDR_B)]),
    dict(name="hubring", pos=(11.50, 12.55), anchor="east",
         lines=["R6, the hub ring", "4.580 m"],
         leaders=[((11.62, 12.70), (14.62, 13.17))]),
    dict(name="segments", pos=(4.50, 1.55), anchor="west",
         lines=["segments S1 to S5", "three tension lines each"],
         leaders=[((4.55, 1.95), (3.22, 2.53))]),
    dict(name="groundring", pos=(-3.45, 2.75), anchor="west",
         lines=["R1, the ground ring", "0.804 m"],
         leaders=[((-1.35, 2.90), (-0.48, 1.68))]),
    dict(name="station", pos=(-3.45, -0.50), anchor="west",
         lines=["ground station: generator and PTO"],
         leaders=[((-0.95, -0.32), (0.10, 0.10))]),
    dict(name="backline", pos=(26.70, 5.30), anchor="east",
         lines=["backline", "altitude limiter, not a load path"],
         leaders=[((26.75, 5.52), (27.26, 5.98))]),
]

INSET = dict(x0=-3.6, z0=18.3, x1=5.4, z1=23.8)
INSET_ROWS = [
    ("ring", "a frame of the shaft. The lines join at its vertices."),
    ("line", "one tensioned line of the TRPT. Three span each segment."),
    ("rotor", "blades on one ring. This machine has one: the main rotor."),
]

TITLE = ("Kite turbine anatomy: the ground-generation rotary machine")
SUB = ("Island-3 winner geometry (NR-011): six rings, three TRPT lines, one active rotor. "
       "The shaft is drawn at the operating elevation. The dashed outline sits outside "
       "the primary render scope.")

STAMP1 = ("source: island-3 winner decode, best_vector.csv, data commit dd3cc6a "
          "· rows NR-011 · NR-017 · NR-043")
STAMP2 = ("script: scratch/fig1_decode_winner.jl · drawn to the 5 m scale bar "
          "· dashed outline: outside the primary render scope")

SCALE_BAR: dict = dict(x0=17.5, x1=22.5, z=-0.5, label="5 m")

# ================= checks =================
assert len(RINGS) == 6 and len(ROPE_SEGS) == 15 and len(BLADES) == 3
assert abs(R_HUB - 4.580) < 1e-3 and abs(R_RING - 0.804) < 1e-3
assert abs(ROTOR["bank"] - 7.088) < 1e-3
assert SPAN_LABEL == "1.499 m"
assert abs((ROTOR["r_out"] - ROTOR["r_in"]) - 1.4994019682084492) < 1e-5

def _seg_hits(a, b, c, d):
    """Open-segment intersection test (a-b vs c-d)."""
    def cr(o, p, q):
        return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])
    return cr(c, d, a) * cr(c, d, b) < 0 and cr(a, b, c) * cr(a, b, d) < 0

assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, _B0, _B1)        # leader clears the blade
assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, DIM_T0, DIM_T2)  # leader clears the extensions
assert not _seg_hits(SPAN_LDR_A, SPAN_LDR_B, DIM_I0, DIM_I2)
assert not _seg_hits(DIM_I, DIM_T, _B0, _B1)                  # dimension clears the blade
print("self-checks ok: 6 rings, 15 ropes, 3 blades, span 1.499 m on NR-043, dimension clearances hold, radii and bank on NR-011/NR-017")

# ================= TikZ emission =================
def texify(s):
    """Unicode and LaTeX specials -> pdflatex-safe text."""
    return (s.replace("°", "\\textdegree{}")
             .replace("·", "\\textperiodcentered{}")
             .replace("—", "---")
             .replace("–", "--")
             .replace("_", "\\_")
             .replace("&", "\\&")
             .replace("%", "\\%")
             .replace("#", "\\#"))

def tex_pt(p):
    x, y = tx(p[0], p[1])
    return f"({x:.3f}cm,{y:.3f}cm)"

L = []
L.append("% system-anatomy.tex — F1 system anatomy, island-3 winner re-cut.")
L.append("% GENERATED by system-anatomy.py (figures seat, 2026-10-12). Do not hand-edit;")
L.append("% re-run the generator. Geometry: scratch/fig1_decode_winner.jl (decode + build")
L.append("% of the bankderate2 island-3 winner, data commit dd3cc6a). Rows NR-011, NR-017, NR-043.")
L.append("% Frame: deployment side elevation, shaft at the operating elevation; wind L->R.")
L.append("% Palette and styles: ../elements/ktd-fig-elements.tex (defined once, reused).")
L.append("\\documentclass{article}")
L.append(f"\\usepackage[paperwidth={W_CM+0.6:.2f}cm,paperheight={H_CM+0.6:.2f}cm,margin=0.25cm]{{geometry}}")
L.append("\\usepackage{tikz}")
L.append("\\usepackage{xcolor}")
L.append("\\usepackage{amsmath}")
L.append("\\usetikzlibrary{calc,arrows.meta}")
L.append("\\pagestyle{empty}")
L.append("\\setlength{\\parindent}{0pt}")
L.append("\\input{../elements/ktd-fig-elements.tex}")
L.append("\\begin{document}")
L.append("\\begin{tikzpicture}[x=1cm,y=1cm]")

def dr(style, pts, close=False, fill=None):
    body = " -- ".join(tex_pt(p) for p in pts)
    fillopt = f", fill={fill}" if fill else ""
    L.append(f"  \\draw[{style}{fillopt}] {body}{' -- cycle' if close else ''};")

# 1) station block (dashed, under everything)
x0, z0, x1, z1 = STATION
dr("ktd station", [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], close=True)

# 2) ground line
dr("ktd ground", [(GROUND_X[0], GROUND_Z), (GROUND_X[1], GROUND_Z)])

# 3) (shaft axis omitted: the centre rope, centre bridle and cyan line are
#    collinear with it; a dashed axis would duplicate, not clarify)

# 4) backline (dashed) + ground anchor glyph
dr("ktd back", [SKY, BACK_ANCHOR])
ax, az = BACK_ANCHOR
tri = [(ax - 0.22, az + 0.34), (ax + 0.22, az + 0.34), (ax, az + 0.06)]
dr("draw=ktdChain, line width=0.8pt, fill=ktdChain", tri, close=True)

# 5) TRPT ropes (3 per segment)
for (a, b) in ROPE_SEGS:
    dr("ktd line", [a, b])

# 6) rings; R1 heavy
for i, p in enumerate(RING_PTS):
    style = "ktd ring heavy" if i == 0 else "ktd ring"
    dr(style, [P(RINGS[i][0], -RINGS[i][1]), P(RINGS[i][0], RINGS[i][1])])

# 7) main-rotor blades (all three; the two -rho blades overlap in projection)
for (a, b) in BLADE_PTS:
    dr("ktd blade", [a, b])

# 7b) blade-span dimension (NR-043): extension lines + arrowed dimension line
dr("ktd leader", [DIM_I0, DIM_I2])
dr("ktd leader", [DIM_T0, DIM_T2])
L.append(f"  \\draw[ktd dim arrow] {tex_pt(DIM_I)} -- {tex_pt(DIM_T)};")

# 8) lift chain
KITE_TOP_END = (KITE_CENTRES[-1][0] + 1.2 * LIFTDIR[0], KITE_CENTRES[-1][1] + 1.2 * LIFTDIR[1])
dr("ktd chain", [SKY, KITE_TOP_END])
for (a, b) in KITE_DISKS:
    dr("ktd chain", [a, b])
dr("ktd chain", [BEARING, SKY])                       # cyan line
for (a, b) in BRIDLES:
    dr("ktd chain thin", [a, b])
# lift bearing collar (perp to axis)
c1 = (BEARING[0] - 0.28 * N[0], BEARING[1] - 0.28 * N[1])
c2 = (BEARING[0] + 0.28 * N[0], BEARING[1] + 0.28 * N[1])
dr("draw=ktdChain, line width=2.6pt, line cap=round", [c1, c2])
L.append(f"  \\fill[ktdChain] {tex_pt(SKY)} circle (0.085cm);")

# 9) wind arrows + beta arc
for (wx, wz) in WINDS:
    L.append(f"  \\draw[ktd wind] {tex_pt((wx, wz))} -- {tex_pt((wx + 2.7, wz))};")
bx, bz = BETA_C
p0 = (bx + BETA_R, bz)
p1 = (bx + BETA_R * COS30, bz + BETA_R * SIN30)
L.append(f"  \\draw[black!55, line width=0.6pt] {tex_pt(p0)} arc (0:30:{BETA_R * K:.3f}cm);")
L.append(f"  \\node[ktd lab grey, anchor=west] at {tex_pt((2.60, 1.30))} {{$\\beta$}};")
L.append(f"  \\node[ktd lab grey, anchor=west] at {tex_pt((-3.55, 13.55))} {{wind}};")

# 10) labels + leaders
for lab in LABELS:
    x, z = lab["pos"]
    anchor = "east" if lab["anchor"] == "east" else "west"
    node_text = "\\\\".join(texify(l) for l in lab["lines"])
    L.append(f"  \\node[ktd lab, anchor={anchor}] at {tex_pt((x, z))} {{{node_text}}};")
    for (a, b) in lab["leaders"]:
        L.append(f"  \\draw[ktd leader] {tex_pt(a)} -- {tex_pt(b)};")

# 11) inset
dr("draw=black!35, line width=0.5pt", [(INSET["x0"], INSET["z0"]), (INSET["x1"], INSET["z0"]),
    (INSET["x1"], INSET["z1"]), (INSET["x0"], INSET["z1"])], close=True)
L.append(f"  \\node[ktd labb, anchor=north west] at {tex_pt((INSET['x0'] + 0.35, INSET['z1'] - 0.45))} "
         "{ring \\textperiodcentered\\ line \\textperiodcentered\\ rotor};")
# glyphs + definitions
gx = INSET["x0"] + 1.15
rowsz = [22.35, 20.90, 19.45]
# ring glyph: triangle
gc = (gx, rowsz[0])
tv = [(-0.55, 0.42), (0.55, 0.42), (0.0, -0.52)]
tv = [(gc[0] + a, gc[1] + b) for (a, b) in tv]
dr("ktd ring", tv, close=True)
for p in tv:
    L.append(f"  \\fill[ktdRing] {tex_pt(p)} circle (0.035cm);")
# line glyph: two ring stubs + three lines
gl = (gx, rowsz[1])
dr("ktd ring", [(gl[0] - 0.55, gl[1] + 0.42), (gl[0] + 0.55, gl[1] + 0.42)])
dr("ktd ring", [(gl[0] - 0.55, gl[1] - 0.42), (gl[0] + 0.55, gl[1] - 0.42)])
for off in (-0.18, 0.0, 0.18):
    dr("ktd line", [(gl[0] + off * 2.2, gl[1] + 0.42), (gl[0] + off * 2.2, gl[1] - 0.42)])
# rotor glyph: ring segment + blade
gr = (gx, rowsz[2])
dr("ktd ring", [(gr[0] - 0.55, gr[1] + 0.10), (gr[0] + 0.55, gr[1] + 0.10)])
dr("ktd blade", [(gr[0] - 0.18, gr[1] + 0.30), (gr[0] + 0.62, gr[1] - 0.24)])
for idx, (term, row_text) in enumerate(INSET_ROWS):
    zz = rowsz[idx]
    L.append(f"  \\node[ktd lab, anchor=west] at {tex_pt((gx + 1.0, zz - 0.12))} "
             f"{{\\textbf{{{term}}} --- {row_text}}};")

# 12) title, sub, scale bar, stamps
L.append(f"  \\node[ktd title, anchor=west] at {tex_pt((-3.70, 26.15))} {{{texify(TITLE)}}};")
L.append(f"  \\node[ktd sub, anchor=north west, text width={W_CM-1.2:.1f}cm] "
         f"at {tex_pt((-3.70, 25.55))} {{{texify(SUB)}}};")
sb = SCALE_BAR
dr("ktd ground", [(sb["x0"], sb["z"]), (sb["x1"], sb["z"])])
dr("ktd ground", [(sb["x0"], sb["z"] - 0.28), (sb["x0"], sb["z"] + 0.28)])
dr("ktd ground", [(sb["x1"], sb["z"] - 0.28), (sb["x1"], sb["z"] + 0.28)])
L.append(f"  \\node[ktd lab, anchor=west] at {tex_pt((sb['x1'] + 0.35, sb['z']))} {{{sb['label']}}};")
L.append(f"  \\node[ktd faint, anchor=west] at {tex_pt((-3.70, -1.05))} {{{texify(STAMP1)}}};")
L.append(f"  \\node[ktd faint, anchor=west] at {tex_pt((-3.70, -1.55))} {{{texify(STAMP2)}}};")

L.append("\\end{tikzpicture}")
L.append("\\end{document}")

tex = "\n".join(L) + "\n"
with open("system-anatomy.tex", "w") as fh:
    fh.write(tex)
print(f"wrote system-anatomy.tex ({len(tex)} bytes); canvas {W_CM:.2f} x {H_CM:.2f} cm")

# ================= SVG / prototype emission =================
PX = 37.795  # px per cm
SX = K * PX  # px per metre
Wp, Hp = W_CM * PX, H_CM * PX

def sv(p):
    x, y = tx(p[0], p[1])
    return (x * PX, Hp - y * PX)

def sline(style, pts, close=False):
    d = " ".join(("M" if i == 0 else "L") + f"{sv(p)[0]:.1f},{sv(p)[1]:.1f}"
                 for i, p in enumerate(pts))
    if close:
        d += " Z"
    return f'<path d="{d}" {style}/>'

S = []
def st(w_pt, color, dash=None, cap="butt"):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'fill="none" stroke="{color}" stroke-width="{w_pt*4/3:.2f}" '
            f'stroke-linecap="{cap}"{d}')

C_ring, C_trpt, C_blade, C_chain = "#6C7A89", "#14606A", "#CC8A00", "#0E8C88"
C_ink, C_grey, C_faint = "#1A1A1A", "#595959", "#8C8C8C"

x0, z0, x1, z1 = STATION
S.append(sline(st(0.8, "#595959", "4 3.3"), [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], True))
S.append(sline(st(1.0, "#444444"), [(GROUND_X[0], GROUND_Z), (GROUND_X[1], GROUND_Z)]))
S.append(sline(st(0.8, C_chain, "4.6 3.3"), [SKY, BACK_ANCHOR]))
ax, az = BACK_ANCHOR
S.append(f'<path d="M{sv((ax-0.22, az+0.34))[0]:.1f},{sv((ax-0.22, az+0.34))[1]:.1f} '
         f'L{sv((ax+0.22, az+0.34))[0]:.1f},{sv((ax+0.22, az+0.34))[1]:.1f} '
         f'L{sv((ax, az+0.06))[0]:.1f},{sv((ax, az+0.06))[1]:.1f} Z" fill="{C_chain}"/>')
for (a, b) in ROPE_SEGS:
    S.append(sline(st(0.85, C_trpt), [a, b]))
for i, p in enumerate(RING_PTS):
    w = 3.2 if i == 0 else 2.2
    S.append(sline(st(w, C_ring, None, "round"), [P(RINGS[i][0], -RINGS[i][1]),
                                                  P(RINGS[i][0], RINGS[i][1])]))
for (a, b) in BLADE_PTS:
    S.append(sline(st(2.8, C_blade, None, "round"), [a, b]))
# blade-span dimension (NR-043): extensions + arrowed dimension line
for (a, b) in [(DIM_I0, DIM_I2), (DIM_T0, DIM_T2)]:
    S.append(sline(st(0.6, C_faint), [a, b]))
_d1, _d2 = sv(DIM_I), sv(DIM_T)
S.append(f'<path d="M{_d1[0]:.1f},{_d1[1]:.1f} L{_d2[0]:.1f},{_d2[1]:.1f}" fill="none" '
         f'stroke="#666666" stroke-width="1.0" marker-start="url(#arr)" marker-end="url(#arr)"/>')
top_end = (KITE_CENTRES[-1][0] + 1.2 * LIFTDIR[0], KITE_CENTRES[-1][1] + 1.2 * LIFTDIR[1])
S.append(sline(st(1.9, C_chain, None, "round"), [SKY, top_end]))
for (a, b) in KITE_DISKS:
    S.append(sline(st(1.9, C_chain, None, "round"), [a, b]))
S.append(sline(st(1.9, C_chain, None, "round"), [BEARING, SKY]))
for (a, b) in BRIDLES:
    S.append(sline(st(1.1, C_chain), [a, b]))
S.append(sline(st(2.6, C_chain, None, "round"), [c1, c2]))
sx, sy = sv(SKY)
S.append(f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="3.2" fill="{C_chain}"/>')
for (wx, wz) in WINDS:
    a, b = sv((wx, wz)), sv((wx + 2.7, wz))
    S.append(f'<path d="M{a[0]:.1f},{a[1]:.1f} L{b[0]:.1f},{b[1]:.1f}" stroke="#4D4D4D" '
             f'stroke-width="1.5" marker-end="url(#arr)"/>')
p0, p1 = sv((bx + BETA_R, bz)), sv((bx + BETA_R * COS30, bz + BETA_R * SIN30))
S.append(f'<path d="M{p0[0]:.1f},{p0[1]:.1f} A{BETA_R*SX:.1f},{BETA_R*SX:.1f} 0 0 0 '
         f'{p1[0]:.1f},{p1[1]:.1f}" fill="none" stroke="#666666" stroke-width="0.8"/>')
def stext(x, z, s, size=10.5, color=C_ink, anchor="start", weight="normal"):
    px, py = sv((x, z))
    return (f'<text x="{px:.1f}" y="{py:.1f}" font-family="system-ui, sans-serif" '
            f'font-size="{size}" fill="{color}" text-anchor="{anchor}" '
            f'font-weight="{weight}">{s}</text>')

S.append(stext(2.60, 1.30, "β", size=10.5, color=C_grey))
S.append(stext(-3.55, 13.55, "wind", size=10.5, color=C_grey))

for lab in LABELS:
    x, z = lab["pos"]
    anchor = "end" if lab["anchor"] == "east" else "start"
    for i, line in enumerate(lab["lines"]):
        S.append(stext(x, z - i * 0.62, line, anchor=anchor))
    for (a, b) in lab["leaders"]:
        pa, pb = sv(a), sv(b)
        S.append(f'<path d="M{pa[0]:.1f},{pa[1]:.1f} L{pb[0]:.1f},{pb[1]:.1f}" '
                 f'stroke="{C_faint}" stroke-width="0.6"/>')

S.append(sline(st(0.5, "#AAAAAA"), [(INSET["x0"], INSET["z0"]), (INSET["x1"], INSET["z0"]),
                                    (INSET["x1"], INSET["z1"]), (INSET["x0"], INSET["z1"])], True))
S.append(stext(INSET["x0"] + 0.35, INSET["z1"] - 0.5, "ring · line · rotor", size=11, weight="600"))
gc2 = (INSET["x0"] + 1.15, rowsz[0])
tv2 = [(gc2[0] - 0.55, gc2[1] + 0.42), (gc2[0] + 0.55, gc2[1] + 0.42), (gc2[0], gc2[1] - 0.52)]
S.append(sline(st(1.7, C_ring, None, "round"), tv2, True))
for p in tv2:
    px, py = sv(p)
    S.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="1.4" fill="{C_ring}"/>')
gl2 = (gx, rowsz[1])
S.append(sline(st(1.7, C_ring, None, "round"), [(gl2[0]-0.55, gl2[1]+0.42), (gl2[0]+0.55, gl2[1]+0.42)]))
S.append(sline(st(1.7, C_ring, None, "round"), [(gl2[0]-0.55, gl2[1]-0.42), (gl2[0]+0.55, gl2[1]-0.42)]))
for off in (-0.18, 0.0, 0.18):
    S.append(sline(st(0.85, C_trpt), [(gl2[0]+off*2.2, gl2[1]+0.42), (gl2[0]+off*2.2, gl2[1]-0.42)]))
gr2 = (gx, rowsz[2])
S.append(sline(st(1.7, C_ring, None, "round"), [(gr2[0]-0.55, gr2[1]+0.10), (gr2[0]+0.55, gr2[1]+0.10)]))
S.append(sline(st(2.8, C_blade, None, "round"), [(gr2[0]-0.18, gr2[1]+0.30), (gr2[0]+0.62, gr2[1]-0.24)]))
for i, (term, txt) in enumerate(INSET_ROWS):
    px, py = sv((gx + 1.0, rowsz[i] - 0.12))
    S.append(f'<text x="{px:.1f}" y="{py:.1f}" font-family="system-ui, sans-serif" '
             f'font-size="10" fill="{C_ink}"><tspan font-weight="700">{term}</tspan>'
             f' — {txt}</text>')

S.append(stext(-3.70, 26.15, TITLE, size=14, weight="600"))
S.append(stext(-3.70, 25.35, SUB, size=10, color=C_grey))
sb = SCALE_BAR
S.append(sline(st(1.0, "#444444"), [(sb["x0"], sb["z"]), (sb["x1"], sb["z"])]))
S.append(sline(st(1.0, "#444444"), [(sb["x0"], sb["z"]-0.28), (sb["x0"], sb["z"]+0.28)]))
S.append(sline(st(1.0, "#444444"), [(sb["x1"], sb["z"]-0.28), (sb["x1"], sb["z"]+0.28)]))
S.append(stext(sb["x1"] + 0.35, sb["z"], sb["label"]))
S.append(stext(-3.70, -1.05, STAMP1, size=8.5, color=C_faint))
S.append(stext(-3.70, -1.55, STAMP2, size=8.5, color=C_faint))

svg = "\n".join(S)
html = f"""<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>F1 system anatomy — round-1 composition mock</title>
<style>
 body {{ font-family: system-ui, -apple-system, "Segoe UI", sans-serif; background:#f4f4f4; margin:0; padding:16px; }}
 .card {{ background:#fff; color:#1a1a1a; border:1px solid #d9d9d9; border-radius:2px;
          padding:16px 18px; max-width:{Wp/16+3.5:.1f}em; box-shadow:0 1px 3px rgba(0,0,0,.08); }}
 .note {{ font-size:12px; color:#6b7280; margin:0 0 10px 2px; }}
 .caption {{ margin-top:12px; border-top:1px dashed #ccc; padding-top:8px; font-size:12px; color:#333; }}
</style></head>
<body>
<p class="note">F1 system anatomy — round-1 composition mock (figures seat, 2026-10-12).
True decoded geometry of the island-3 winner (data commit dd3cc6a); register-bound labels only
(NR-011, NR-017); canvas {W_CM:.1f} x {H_CM:.1f} cm at {K} cm/m. The TikZ build draws from the
same computed coordinates.</p>
<div class="card">
<svg viewBox="0 0 {Wp:.0f} {Hp:.0f}" width="{Wp:.0f}" height="{Hp:.0f}" role="img"
 aria-label="System anatomy of the ground-generation rotary kite turbine">
<defs><marker id="arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#4D4D4D"/></marker></defs>
{svg}
</svg>
<div class="caption">
 <div>⟨plain caption — takeaway, one sentence, jargon-free; lands in the kit captions⟩</div>
 <div style="color:#555;margin-top:3px">⟨technical caption — undergrad register, STE-clean; every number a register citation⟩</div>
</div>
</div>
</body></html>
"""
with open("prototype.html", "w") as fh:
    fh.write(html)
print(f"wrote prototype.html ({len(html)} bytes); svg {Wp:.0f}x{Hp:.0f} px viewport")

# ================= label ledger (house artefact: every string drawn) =================
strings = []
for lab in LABELS:
    strings.extend(lab["lines"])
strings.extend([TITLE, SUB, STAMP1, STAMP2, SCALE_BAR["label"], "wind", "β",
                "ring · line · rotor"])
strings.extend(f"{term} — {txt}" for (term, txt) in INSET_ROWS)
with open("label-ledger.txt", "w") as fh:
    fh.write("\n".join(sorted(set(strings))) + "\n")
print(f"wrote label-ledger.txt ({len(set(strings))} strings)")
