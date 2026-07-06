# Rig Topology — Windswept TRPT Kite Turbine

**Status:** DRAFT (2026-07-06, grilled with Rod)
**Purpose:** Canonical reference for structural checks. Every member with
attachment points and load paths. Checks are written against this document.

---

## TRPT shaft

The shaft is a tension structure of `n_lines` Dyneema tethers passing through
`n_rings` polygon rings. Rings are numbered 1 (ground) to N (hub).

| Component | Description |
|-----------|-------------|
| Ring | n_lines-sided polygon of CFRP beam struts connected by knuckles |
| Knuckle | Rigid joint between two adjacent struts. Accepts ring tube ID. Stronger than struts — does not yield before struts (Rod 2026-07-06). Tether passes through and affixes at each knuckle |
| Tether | n_lines Dyneema lines running from ground ring to hub ring through knuckles. Carry axial tension + torsional twist |
| Beam strut | CFRP hollow tube between knuckles. Compression (Euler buckling) at low ω; tension at high ω (net outward) |

Ring radii taper from r_bottom (ground ring) to r_hub (generating rotor ring).
Spacing follows `ring_spacing_v4` with design-dependent taper profile.

---

## Hub rotor

The generating rotor at the hub ring. Main power-producing rotor.

| Component | Description |
|-----------|-------------|
| Hub blades | CFRP blades, root at hub ring. Centrifugal off-loading via `m_blade_total` in structural evaluator (`trpt_optimization.jl:449`) |
| Hub ring | Outermost ring (ring N). Carries hub blade mass + thrust |

---

## Expansion rotors

Small 3-blade propellers on intermediate rings. Currently 3 rotors at rings
14, 17, 20 (configuration not permanent — Rod). One blade per tether vertex
(= n_lines blades per rotor).

### Blade geometry (post-70/30 fix)

Blade extends from −0.3·span (inboard of ring) to +0.7·span (outboard of ring).
Cuff fuses blade to ring vertex. Bank angle is set by bridle configuration,
not rigidly at the cuff.

### Bridles

Each blade has two bridles converging at a single anchor point on the TRPT line:

| Bridle | Attachment on blade | Attachment on TRPT line |
|--------|--------------------|------------------------|
| Outer | 70% of outboard span (0.49·span from ring, toward tip) | ~30% down the line segment to the ring below |
| Inner | 70% of inboard span (0.21·span from ring, toward hub) | Same point as outer bridle |

Bridles work in tension — they retard blade bending and lift, holding the blade
against aero forces (Rod). The bridle geometry sets the effective bank angle.

**Load path:** Blade centrifugal + aero lift → bridle tension → lateral point
load on TRPT line segment at the anchor point. Root bending at cuff is from
the short cantilever between cuff and bridle attachment (reduced ~10× vs
unbridled cantilever).

---

## Radial spoke ties

Radial Dyneema lines from each ring vertex to a floating center node at the
shaft axis (Rod 2026-07-06). Engage under net-outward radial load — below
engagement onset they are slack.

| Property | Value |
|----------|-------|
| Line | Dyneema, diameter TBD (7mm proposed, likely over-designed per Rod). `required_MBL_N` emitted as Gate 2 CSV column |
| Attachment | Ring vertex → floating center node on shaft axis |
| Engagement | T_spoke = max(F_centripetal + F_exp − F_in_aero, 0) |
| Drag | τ = ρ·C_D·d·ω²·R⁴/8 per spoke (ODE path: `ring_forces.jl`) |
| Strength check | FoS = SWL / T_spoke. Gate 2 gate at 1.0, caveat flag at <1.5 |

No inner-tip ties needed — spokes handle radial load; tip ties would flatten
banked rotors against the rotation plane (Rod).

---

## Top swivel and lift system

| Component | Description |
|-----------|-------------|
| Swivel bearing | At top of TRPT shaft. Rated RPM = hardware ω ceiling (TBD — Rod to supply) |
| Rigidised pipe | Pipe-shrouded lift line segment passing through swivel bearing. Stationary member on rotation axis — wrap rate IS applicable |
| Washer + knot | Underside of swivel bearing held by washer and finished knot on rigidised pipe |
| Back line | Anchored to ground above swivel. Prevents torque propagation into lift line |
| Lift line | Extends from swivel to autogyro lifting kites which launch the system |

---

## Members inventoried for structural envelope

| Member | Check | Status |
|--------|-------|--------|
| Ring strut (compression) | Euler buckling | ✅ `_evaluate_trpt_design_impl` |
| Ring strut (tension) | CFRP yield (600 MPa) | ✅ Phase B, non-binding |
| Knuckle | Pass-through (FoS ≥ strut tension) | ✅ Rod 2026-07-06 |
| Hub blade centrifugal | Off-loading via m_vertex | ✅ `trpt_optimization.jl:449` |
| Expansion blade root bending | Beam-on-two-supports (cuff + bridle) | ⬜ Deferred |
| Bridle tension (outer) | Dyneema line rating | ⬜ Needs bridle model |
| Bridle tension (inner) | Dyneema line rating | ⬜ Needs bridle model |
| TRPT line lateral load | Point load at bridle anchor | ⬜ Needs bridle model |
| Spoke tension | Dyneema SWL | ✅ `SpokeParams`, evaluator |
| Spoke drag | Parasitic torque | ✅ `ring_forces.jl` (ODE only) |
| Tether axial tension | TETHER_SWL | ✅ Gate 4 in objective_v10 |
| Back line | Catenary model | ✅ `ring_forces.jl` |
| Swivel RPM | Hardware ceiling | TBD — Rod |

---

## Configurations

The expansion rotor count and ring positions are not permanent. The structural
evaluator accepts arbitrary `expansion_blade_geo` and `m_expansion_blade_per_ring`
vectors. Gate 2 runs on the current 3-rotor configuration; future campaigns
may vary it.
