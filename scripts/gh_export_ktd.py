# scripts/gh_export_ktd.py
#
# Grasshopper -> KTD.jl design exporter.
#
# Paste this into a GHPython component (Rhino 7) or a Python 3 Script
# component (Rhino 8).  It measures the ring stack and blade geometry of a
# kite-turbine model and writes a design.json that KTD.jl reads via
# scripts/build_from_gh_json.jl.  Bridle, fuselage, and detail elements are
# intentionally ignored — KTD does not resolve them.
#
# ── Component inputs (name, type hint, access) ────────────────────────────
#   rings     Curve         List   All ring curves: ground ring, spacer
#                                  rings, hub ring.  Circles or closed
#                                  polygons, any order.
#   blades    GeometryBase  List   (optional) Blade breps/surfaces/outline
#                                  curves.  Grouped automatically by
#                                  nearest ring.
#   n_lines   int           Item   (optional) Override; auto-detected from
#                                  polygon vertex count when rings are
#                                  polylines.
#   chord_m   float         Item   (optional) Blade chord override (m).
#                                  Auto = face area / span for breps.
#   bank_deg  float         Item   (optional) Bank angle override (deg).
#                                  Auto-estimated from blade tilt.
#   label     str           Item   Design name, e.g. "Generic 3x5".
#   path      str           Item   Output path for design.json.
#   write     bool          Item   Button/toggle — writes file when True.
#
# ── Component outputs ─────────────────────────────────────────────────────
#   json_out  The JSON string (always produced, even when write=False).
#   info      Human-readable measurement report — check before trusting.
#
# Schema: "ktd-gh-design/v1".  Conventions:
#   * ring_radii_m / ring_z_m sorted ground -> hub (index 1 = ground ring,
#     index n = hub ring, i.e. KTD system ring numbering).
#   * Rotor blade offsets are SIGNED distances from the ring radius:
#     hub_offset_m < 0 means the annulus reaches inside the ring (the
#     physical blades straddle the ring: ~70% outside, ~30% inside).
#   * Ground ring = ring whose centre is nearest the world origin (put the
#     ground station at/near the origin, or check `info`).

import json
import math
import Rhino.Geometry as rg

SCHEMA = "ktd-gh-design/v1"


# ── helpers ────────────────────────────────────────────────────────────────

def _curve_points(crv, n=64):
    ok, pl = crv.TryGetPolyline()
    if ok:
        pts = [pl[i] for i in range(pl.Count)]
        if pts and pts[0].DistanceTo(pts[-1]) < 1e-9:
            pts = pts[:-1]
        return pts, len(pts)          # polygon: vertex count = n_lines
    params = crv.DivideByCount(n, True)
    return [crv.PointAt(t) for t in (params or [])], None


def _geometry_points(g):
    """Sample representative points from a Brep/Surface/Mesh/Curve."""
    if isinstance(g, rg.Brep):
        pts = [v.Location for v in g.Vertices]
        for f in g.Faces:
            dom_u, dom_v = f.Domain(0), f.Domain(1)
            for iu in range(5):
                for iv in range(5):
                    u = dom_u.ParameterAt(iu / 4.0)
                    v = dom_v.ParameterAt(iv / 4.0)
                    pts.append(f.PointAt(u, v))
        return pts
    if isinstance(g, rg.Surface):
        return _geometry_points(g.ToBrep())
    if isinstance(g, rg.Mesh):
        return [rg.Point3d(p) for p in g.Vertices]
    if isinstance(g, rg.Curve):
        pts, _ = _curve_points(g)
        return pts
    bb = g.GetBoundingBox(True)
    return list(bb.GetCorners())


def _centroid(pts):
    n = float(len(pts))
    return rg.Point3d(sum(p.X for p in pts) / n,
                      sum(p.Y for p in pts) / n,
                      sum(p.Z for p in pts) / n)


def _axial_radial(p, origin, direction):
    v = p - origin
    t = v * direction
    radial = v - direction * t
    return t, radial.Length


def _brep_area(g):
    try:
        amp = rg.AreaMassProperties.Compute(g)
        return amp.Area if amp else None
    except Exception:
        return None


# ── 1. measure rings ───────────────────────────────────────────────────────

_ring_data = []          # (center, radius, n_vertices_or_None)
for crv in (rings or []):
    if crv is None:
        continue
    ok, circ = crv.TryGetCircle()
    if ok:
        _ring_data.append((circ.Center, circ.Radius, None))
        continue
    pts, nv = _curve_points(crv)
    if len(pts) < 3:
        continue
    c = _centroid(pts)
    r = sum(p.DistanceTo(c) for p in pts) / float(len(pts))  # circumradius for polygons
    _ring_data.append((c, r, nv))

if len(_ring_data) < 2:
    raise Exception("Need at least 2 ring curves (ground + hub); got %d" % len(_ring_data))

# shaft axis: longest chord between ring centres
_centers = [d[0] for d in _ring_data]
_best = (0.0, 0, 1)
for i in range(len(_centers)):
    for j in range(i + 1, len(_centers)):
        dd = _centers[i].DistanceTo(_centers[j])
        if dd > _best[0]:
            _best = (dd, i, j)
_i0, _j0 = _best[1], _best[2]
# ground end = centre nearest world origin
if _centers[_i0].DistanceTo(rg.Point3d.Origin) <= _centers[_j0].DistanceTo(rg.Point3d.Origin):
    _origin, _tip = _centers[_i0], _centers[_j0]
else:
    _origin, _tip = _centers[_j0], _centers[_i0]
_dir = _tip - _origin
_dir.Unitize()

# sort rings along the axis, ground first
_stack = sorted(_ring_data, key=lambda d: (d[0] - _origin) * _dir)
ring_z = [float((d[0] - _origin) * _dir) for d in _stack]
ring_r = [float(d[1]) for d in _stack]

# n_lines: modal polygon vertex count, else input override
_nv = [d[2] for d in _stack if d[2]]
if _nv:
    _n_lines = max(set(_nv), key=_nv.count)
elif n_lines:
    _n_lines = int(n_lines)
else:
    raise Exception("Rings are circles — supply the n_lines input.")

# ── 2. measure blades, group into rotors by nearest ring ──────────────────

_groups = {}
for g in (blades or []):
    if g is None:
        continue
    pts = _geometry_points(g)
    if len(pts) < 2:
        continue
    tr = [_axial_radial(p, _origin, _dir) for p in pts]
    t_c = sum(t for t, _ in tr) / float(len(tr))
    k = min(range(len(ring_z)), key=lambda i: abs(ring_z[i] - t_c))
    r_min = min(r for _, r in tr)
    r_max = max(r for _, r in tr)
    # bank estimate: axial offset of tip-side points vs hub-side points
    t_in = [t for t, r in tr if r < r_min + 0.25 * (r_max - r_min)]
    t_out = [t for t, r in tr if r > r_max - 0.25 * (r_max - r_min)]
    dt = (sum(t_out) / len(t_out) - sum(t_in) / len(t_in)) if (t_in and t_out) else 0.0
    span = max(r_max - r_min, 1e-9)
    bank = math.degrees(math.atan2(abs(dt), span))
    area = _brep_area(g)
    _groups.setdefault(k, []).append(
        {"r_min": r_min, "r_max": r_max, "bank": bank,
         "chord": (area / span) if area else None})

rotors = []
for k in sorted(_groups):
    bl = _groups[k]
    n_b = len(bl)
    r_ring = ring_r[k]
    hub_off = sum(b["r_min"] for b in bl) / n_b - r_ring
    tip_off = sum(b["r_max"] for b in bl) / n_b - r_ring
    banks = [b["bank"] for b in bl]
    chords = [b["chord"] for b in bl if b["chord"]]
    rotors.append({
        "ring_idx": k + 1,                       # 1-based, ground=1 .. hub=n
        "n_blades": n_b,
        "hub_offset_m": round(hub_off, 4),       # signed: <0 = inside ring
        "tip_offset_m": round(tip_off, 4),
        "chord_m": round(float(chord_m), 4) if chord_m else
                   (round(sum(chords) / len(chords), 4) if chords else None),
        "bank_angle_deg": round(float(bank_deg), 2) if bank_deg else
                          round(sum(banks) / len(banks), 2),
    })

# ── 3. derived quantities + report ─────────────────────────────────────────

tether_length = ring_z[-1] - ring_z[0]
seg_L = [ring_z[i + 1] - ring_z[i] for i in range(len(ring_z) - 1)]
seg_r = [0.5 * (ring_r[i] + ring_r[i + 1]) for i in range(len(ring_r) - 1)]
Lr = [L / r for L, r in zip(seg_L, seg_r) if r > 1e-9]

design = {
    "schema": SCHEMA,
    "label": label or "gh-design",
    "n_lines": int(_n_lines),
    "n_rings": len(ring_r) - 2,                  # intermediate rings only
    "r_hub_m": round(ring_r[-1], 4),
    "r_bottom_m": round(ring_r[0], 4),
    "tether_length_m": round(tether_length, 4),
    "ring_radii_m": [round(r, 4) for r in ring_r],
    "ring_z_m": [round(z - ring_z[0], 4) for z in ring_z],
    "mean_Lr": round(sum(Lr) / len(Lr), 4) if Lr else None,
    "rotors": rotors,
}

json_out = json.dumps(design, indent=2)

_lines = [
    "KTD export '%s'  (%s)" % (design["label"], SCHEMA),
    "rings: %d total (%d intermediate), n_lines=%d" %
        (len(ring_r), design["n_rings"], design["n_lines"]),
    "r_bottom=%.3f m  r_hub=%.3f m  L=%.2f m  mean L/r=%.3f" %
        (design["r_bottom_m"], design["r_hub_m"],
         design["tether_length_m"], design["mean_Lr"] or 0.0),
    "ground ring = nearest world origin; CHECK this is correct.",
]
for ro in rotors:
    frac_in = -ro["hub_offset_m"] / max(ro["tip_offset_m"] - ro["hub_offset_m"], 1e-9)
    _lines.append(
        "rotor @ ring %d/%d: %d blades, offsets [%+.2f, %+.2f] m "
        "(%.0f%% of span inside ring), chord=%s, bank=%.1f deg" %
        (ro["ring_idx"], len(ring_r), ro["n_blades"],
         ro["hub_offset_m"], ro["tip_offset_m"], 100.0 * frac_in,
         ("%.3f m" % ro["chord_m"]) if ro["chord_m"] else "MISSING — set chord_m",
         ro["bank_angle_deg"]))
if not rotors:
    _lines.append("WARNING: no blades wired in — no rotors exported.")

if write and path:
    with open(path, "w") as f:
        f.write(json_out)
    _lines.append("written -> %s" % path)
else:
    _lines.append("write=False — nothing written.")

info = "\n".join(_lines)
