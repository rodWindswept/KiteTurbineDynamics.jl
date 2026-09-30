# TRPT model vs Tulloch (2021) — literature cross-check

**Date:** 2026-09-25
**Source:** `Tulloch, PhD Thesis Final Submission.pdf` — Oliver Tulloch, *Modelling and
Analysis of Rotary Airborne Wind Energy Systems — a Tensile Rotary Power Transmission
Design*, PhD, University of Strathclyde, 2021, 308 pp.
Repository extract: `docs/validation/tulloch-thesis-extract.txt` (19,670 lines; the
equations cited below are all present in that extract).
**Question:** does the repo's TRPT modelling represent the physics in the thesis?
**Status:** findings for Rod. No source file was changed. The one physics-criterion
change proposed here needs a written proposal and an acceptance run first (AGENTS.md,
Rod's standing rule for physics-model changes).

Every equation number below is Tulloch's. Every repo line reference is the working
tree as read on the date above.

---

## 1. Verdict

| # | TRPT model element | Tulloch | Repo | Verdict |
|---|---|---|---|---|
| 1 | Torque law τ = n·T·r_a·r_b·sin(Δα)/chord, chord² = L² + r_a² + r_b² − 2r_a r_b cosΔα | (4.28)–(4.31), (5.2) | `initialization.jl:1708–1721`, `ring_forces.jl:469–472`, `dashboard_panels.jl:40` | **Match** — algebraically identical |
| 2 | Zero twist transmits zero torque | (4.31), §5.3.1 | same law | **Match** |
| 3 | Twist shortens the ring spacing (rings pull together) | §3.5, §4.6 | `trpt_matched_place` solves `L_ax` from the chord | **Match** |
| 4 | Dynamic model: per-line tension-only springs between rigid rings | §4.7 multi-spring | `rope_forces.jl` per-line springs, `RingNode` radii rigid | **Match** (Tulloch's higher-fidelity of his two dynamic models) |
| 5 | Tether drag per unit length, each line split in two, applied to the nearest ring | (4.35)–(4.63), §4.5.2, §4.6 | `rope_forces.jl:425` + `hdrag = 0.5·drag` per end | **Match in form**; coefficient differs — see F3 |
| 6 | Over-twist failure at 180° (tethers reach the axis) | §3.1.3, §4.4, §5.3.1 | `ring_forces.jl:467` guard `abs(Δα) ≥ 0.95π` | **Near match** (171° vs 180°) |
| 7 | Over-twist *operating* limit is δcrit from (4.34)/(5.4), not 180° | §5.3.1 | repo uses δα* = 2·asin(L/√(2(L²+2r²))) | **Mismatch** — F1 |
| 8 | Torque capacity τ_cap | (5.4) + force ratio, §5.3.1 | `trpt_optimization.jl:934` | **Mismatch** — F2 |
| 9 | Line drag coefficient CDt | 1.2 baseline, 2.7 fitted to Daisy-8 (§5.4.3) | `TETHER_DRAG_CD = 1.0` in the ODE | **Mismatch** — F3 |
| 10 | Ring-segment rotational springs kr | (4.68), (4.74) | absent | **Gap** — F5 |

Confirmed: elements 1–6 are the ones that carry the torque, the geometry and the
load path, and they reproduce the thesis. Elements 7–8 do not, and they are the two
that are named after Tulloch in the code and the docs.

---

## 2. What matches, in detail

**2.1 The torque law is Tulloch's (4.31).** Tulloch (4.31):

    Q = R1·R2·Fx · sinδ / √(l_t² − R1² − R2² + 2·R1·R2·cosδ)

with `l_t` the tether length and (4.30) `l_s = √(l_t² − C²)`, (4.29)
`C² = R1² + R2² − 2·R1·R2·cosδ`. The repo's placement law
(`initialization.jl:1708–1721`) is the same expression with `chord` = `l_t`,
`L_ax` = `l_s`, `T_s` the per-line tension and `n_lines · T_s` = `Fx`:

    chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos(Δα)
    n_lines · T_s · r_a · r_b · sin(Δα) / chord = τ

Elastic stretch is added as `chord_s = chord0·(1 + T_s/EA)`, which is a refinement —
Tulloch assumes the tethers do not stretch (§4.4). It does not change the form.

**2.2 The axial contraction is right.** Tulloch §3.5: as the TRPT deforms
rotationally the distance between the rings becomes smaller; §4.6: "the constant
tether length forces the discs to move towards each other". `trpt_matched_place`
notes this in the same words and returns a transmission shorter than the untwisted
design length. This is the mechanism behind the gust positive-feedback loop recorded
in Tulloch §3.5 and it is present in the repo.

**2.3 The dynamic model is the multi-spring one.** Tulloch §4.7 gives each tether its
own linear spring `kt` (removing the "tethers do not change length" assumption of
his Spring-Disc model §4.6), with the ring masses free to move. The repo holds each
line as a tension-only spring between attachment points on rigid rings, with the
rings free in 3D. That is the §4.7 class, with rigid rather than segmented rings.
Tulloch's conclusion that the multi-spring representation suits larger systems
(§5.2.3) therefore applies to the repo's choice.

**2.4 The drag split is his.** Tulloch §4.6 splits each tether into two equal
segments and applies the torque loss of each segment to the nearest disc, so the
end discs take less. `rope_forces.jl` applies half the sub-segment drag to each end
node. Same arrangement.

**2.5 The 22° cone.** Tulloch §3.1.3: the Daisy TRPT was designed with a cone angle
of 22° to avoid an abrupt change in diameter, and the taper keeps the ring
compression low. `objective_evaluator.jl:147` carries `cone_slope_deg = 22.0` and the
campaign seed tapers 0.575 m → 2.4 m.

---

## 3. Findings

### F1 — HIGH. The collapsed-twist limit δα* is not Tulloch's, and it is not a crossing limit

**Where.** Four call sites, one formula:

| Site | Use |
|---|---|
| `initialization.jl:1425, 1454` (`max_segment_cross_ratio`) | design floor |
| `objective_evaluator.jl:315` (`twist_collapse_check`) | gates the ODE window, hard rejects an eval |
| `ring_forces.jl:467` area (`L_seg = p.tether_length/(Nr−1)`) | damping-block guard |
| `soft_ramp_controller.jl:_δα_star` | freezes the k_mppt ramp within 5° |
| `trpt_optimization.jl:934` area | τ_cap for the hard torsional FoS (see F2) |

    δα* = 2·asin(L / √(2(L² + 2r²))),  L = ring-centre separation, r = max(r_a, r_b)

The code and the docs call this "the discrete geometric crossing limit", "the tightest
limit", the point where "the lines have crossed" (`objective_evaluator.jl:298–300`),
and **"δα* from Tulloch"** (`soft_ramp_controller.jl:49`). Three things are wrong.

**(a) It is not Tulloch's limit.** Tulloch puts the over-twist limit at δcrit from
(4.34), equal-radius form (5.4) with ϕ = l_t/R:

    cos δcrit = 1 − ϕ²/2 + (ϕ/2)·√(ϕ² − 4)

δcrit depends on the *tether length over the ring radius* only. §5.3.1 is explicit:
"The torsional deformation must be kept below δcrit", "a TRPT section will fail prior
to the tethers crossing", and for ϕ < 2 "it is not geometrically possible for the
torsional deformation to reach 180°. The tethers are therefore not able to cross. In
this situation the material strength of the tethers and rings will dictate the failure
point." §3.1.3 says the same in words: "If the diameter of the rings is larger than the
length of the tethers between two adjacent rings, it is not possible for the torsional
deformation to reach 180°."

**(b) It is not the crossing limit of any model.** The six outer tethers reach the axis,
and therefore cross, when Δα = 180°. Every tether's midpoint sits at radius
`r·cos(Δα/2)` at mid-span, so all six converge on the axis at 180° whatever the ring
separation and whatever the line count — which is why Tulloch's rule has no `n_lines`
and no `L` in it. The repo's formula has both, and returns 2.86° for the case Rod
raised (L = 0.1 m, r = 2 m), where the tether is not remotely near the axis.

**(c) It is not even the torque-peak angle of the model it comes from.** δα* is the
stationary point of `τ = n·T·r²·sinδ/chord` with the ring gap `L` held **fixed** — the
kinematics of a tether that stretches while the rings stay apart, which is neither
Tulloch's model (§4.4 holds the tether length and lets the gap shorten) nor the repo's
own placement law. And it is an approximation of that: the true stationary point of the
fixed-gap law is `r²c² − c(L²+2r²) + r² = 0`, i.e. `cos = r²/(L²+2r²)` to first order,
whereas δα* uses `cos = 2r²/(L²+2r²)` — double. The torque value at δα* happens to land
within a few percent of the true fixed-gap peak, which is why the error looks harmless
in a plot of torque and is plain in the angle.

**Measured on the live campaign seed** (`seed_genome(5.0)`, 13 rings, 6 lines, 12
segments, taper 0.575 m → 2.4 m; probe `.scratch/trpt_tulloch_geom.jl`):

| segment | r_min (m) | L_ax (m) | l_t (m) | ϕ = l_t/r_min | repo δα* | Tulloch (5.4)/§3.1.3 |
|---|---|---|---|---|---|---|
| 1–8 | 0.575 | 0.886 | 0.886 | 1.54 | 62.8° | ϕ < 2 → **cannot cross**; rings meet at 100.7° |
| 9 | 0.575 | 1.485 | 1.601 | 2.78 | 56.2° | δcrit = **100.3°** |
| 10 | 1.175 | 3.033 | 3.271 | 2.78 | 56.2° | δcrit = **100.3°** |
| 11–12 | 2.400 | 3.600 | 3.600 | 1.50 | 61.9° | ϕ < 2 → **cannot cross**; rings meet at 97.2° |

Ten of the twelve segments have a ring diameter larger than their tether length, so on
Tulloch's own criterion they cannot cross at all. The two that can have a limit of
100.3°, against the repo's 56.2°.

**(d) The fourth call site is a live torque ceiling in the ODE, and it is nearly inert.**
`rope_forces.jl:515–569` saturates each segment's transmitted torque at `τ(δα*)`. This
looked like the mechanism that manufactures a cliff, so it was measured against Tulloch's
own law, with the ring separation contracting as (4.30) requires. It permits **93–110%**
of the transmitted torque at every twist from 30° to 100° on the seed's segment classes
(worst cut ~7% near 70°; the cap value crosses Tulloch's curve at 90°). It creates no
cliff and it does not explain the observed wind-up. Its defect is provenance and form —
it caps at the fixed-gap angle where the ceiling should be `τ_max` at δcrit, and it caps
at all on segments that have no δcrit.

**What it costs.** The limit binds, and it is the only reason the campaign seed's
preload is raised. Recorded 2026-09-20 (`DECISIONS.md:349–357`, 383–386): at the honest
taut preload the seed read demand 0.8565 — **under** the continuum sin-law ceiling of
0.9524, so the sin law alone cleared it — while the crossing ratio read 1.0911 at
Δα = 58.93° against δα* = 54.01°. `design_axial_preload` therefore scaled `F_top` up by
`max(demand, cross)·1.05` until every segment sat under 54°. Δα = 58.93° is a
legitimate operating point on Tulloch's criterion for every one of those segments.
The raised preload raises line tension, ring compression, and so ring mass and FoS
demand. It also refuses real machines: `test_trpt_realisability.jl` §E records L/r 1.2
refused, and the whole L/r 2.0 → 1.5 re-seed was driven in part by a refusal.

**It is conservative, never optimistic.** δα* is below Tulloch's δcrit wherever δcrit
exists, and it imposes a limit where Tulloch has none. No design the current gate
admits violates the thesis. This is a misattribution and a design-space distortion,
not a safety hole.

### F2 — HIGH. τ_cap is the same fixed-gap idealisation, and it is the DE's hard torsional constraint

`trpt_optimization.jl:934`:

    τ_cap = T_total_rated · r_min² / √(L² + 2·r_min²)
    min_torsional_fos = τ_cap / τ_carry            (hard floor OPT_TORSION_FOS_REQUIRED = 1.5)

That expression is the peak of the constant-gap law, not Tulloch's capacity. Tulloch's
capacity is `Q_max = R·Fx·(force ratio)max`, with the force ratio max read off (5.4)
and Figure 5.29 — 0.5 for the Figure 5.25 case (R = 0.4 m, l_t = 1 m, Fx = 500 N →
Q_max = 100 N·m, which the repo formula reproduces as 83.4 N·m).

On the seed's segment classes, against Tulloch's own Q_max at the same axial force:

| segment | repo τ_cap/T | Tulloch Q_max/T | error |
|---|---|---|---|
| 1–8 (ϕ = 1.54) | 0.275 | no interior maximum — torque rises to ring contact | not comparable |
| 9 (ϕ = 2.78) | 0.195 | 0.244 (δcrit = 100.3°) | −19.8% |
| 10 (ϕ = 2.78) | 0.399 | 0.498 (δcrit = 100.3°) | −19.8% |
| 11–12 (ϕ = 1.50) | 1.164 | no interior maximum | not comparable |

Where δcrit exists the formula is ~20% low, so the DE over-constrains. Where ϕ < 2 it
has no Tulloch counterpart at all: the thesis says capacity there is set by tether
strength and ring strength, and for the seed that is ten of twelve segments. A hard
floor of 1.5 on a quantity with no physical meaning on 83% of the transmission is a
search-space distortion, and it can hide the real limit.

### F3 — MEDIUM. The ODE drag coefficient is 1.0 where Tulloch calibrates 2.7

`rope_forces.jl:425` passes `TETHER_DRAG_CD` (= 1.0, `aerodynamics.jl:335`) into
`tether_drag_force!`. Tulloch uses CDt = 1.2 in all his simulations (Table 2.2) and
§5.4.3 finds the Daisy-8 fit is best at **CDt = 2.7** — "over double the value of 1.2
used in all other simulations". At TRPT-4 and optimal TSR the torque loss is 4.9 N·m at
CDt = 1.2 and 9.9 N·m at 2.7. The repo's own prototype builder already uses 2.7
(`scripts/daisy_builder.jl:75`, citing §5.4.3); the ODE does not. Drag torque in the
TRPT is therefore under-predicted by roughly 2.7× against Tulloch's fitted value, and
by 1.2× against his baseline.

This one needs a decision, not a derivation: 1.0 is a textbook Dyneema cross-flow value,
1.2 is Tulloch's default, 2.7 is what fits his field data. Record which one the
campaigns are run at.

### F4 — MEDIUM. The damping block takes the axial gap as the line's unloaded length

`ring_forces.jl:455, 470–472`:

    L_seg = p.tether_length / (Nr - 1)
    chord = √(L_seg² + 2r_s²(1 − cos Δα))
    T_est = n_lines · EA_rope · (chord − L_seg)/L_seg
    τ_est = T_est · r_s² · sin|Δα| / chord

This treats the *ring spacing* as the tether's unloaded length, so the strain grows as
the square of the twist. In Tulloch's model the tether length is fixed and the spacing
shortens (4.30), and `trpt_matched_place` places the machine that way, so the state
this block is handed does not sit at the strain the block assumes. It feeds `k_sec`
and hence the damping coefficient `c_s = 2√(k_sec·I_s)`. The block itself is honest
that it is for damper sizing only ("for damper sizing only", `:469`) and that the
torsional spring comes from the line geometry (`:426–428`), so this is a magnitude
error in the damping, not a wrong load path. Worth a look before the next controller
tuning pass, since ζ is set from it.

### F5 — DISCUSSION. Two Tulloch components are absent, deliberately or by omission

- **Ring-segment rotational springs.** Tulloch's multi-spring potential energy (4.68)
  includes `½·kr·(θ_i,j − θ_i,j+1)²` — the in-plane bending of the ring between adjacent
  attachment points — and (4.74) carries it. The repo has rigid rings and prices ring
  integrity instead through the compression/Euler check per ring. Different model,
  arguably richer in the compression direction, but it is not his, and the ring's
  in-plane compliance is not in the dynamics.
- **Radial restraint.** Tulloch §3.1.3: six radial tethers run from the attachment
  points to a central tether and "constrain the rings radial deformation". The repo's
  spoke spring is ruled inert (`ring_forces.jl:371–396`) and `F_radial` is a structural
  load only, by Rod's 2026-09-22 ruling. That ruling is about the ring's *centre of
  mass*; Tulloch's point is about radial restraint at the rim. The two are not the same
  statement and the rim restraint has no equivalent in the ODE.

### F6 — DISCUSSION. α is a coaxial twist DOF riding on a non-coaxial column

Tulloch's whole formulation assumes the rings are rigid, orthogonal to a common axis of
rotation, and share that axis. The repo's rings translate and tilt in 3D
(`pp1_tilt, pp2_tilt`, `docs/agents/physics-topology.md` §3.1.1) and the column is a
free-floating tensegrity. The twist is carried as one scalar α per ring, so Δα is a
rotation *about a shared axis* by construction. Whatever the tilt, the model reads the
twist as α_j − α_i. I have not tested whether that is a fair reduction when a ring
tilts; it is worth stating explicitly somewhere, because every item in section 1 of this
table inherits the assumption.

---

## 4. Proposed corrections (not applied)

1. **One authority for the twist limit.** A single function, called by all four sites:
   per segment, `ϕ = l_t / min(r_a, r_b)`; if `ϕ ≥ 2` return
   `δcrit = acos(1 − ϕ²/2 + (ϕ/2)√(ϕ²−4))`; if `ϕ < 2` return "no over-twist limit"
   and let the existing tether-tension and ring-compression checks carry the load.
   Then delete the fixed-gap δα* everywhere, including the `soft_ramp_controller`
   margin and its 5° freeze.
2. **Re-derive τ_cap** from (5.4) and the force ratio, or drop the torsional FoS as a
   hard DE constraint on segments that cannot reach δcrit and let tether strength and
   ring compression be the constraint there.
3. **Record the drag CD decision** and use one value in the ODE, the prototype builder
   and the objective.
4. **Keep the sin-law demand check.** It is Tulloch's own continuum limit, it is
   correct, and it is what the corrected floor should be built on.

### Tests this needs (test-first, per AGENTS.md)

- **Static:** the new limit function against (5.4) — ϕ = 2.5 → 104.5°, ϕ = 5 → 92.5°,
  ϕ → 10 → 91.2°, ϕ → ∞ → 90°, and ϕ < 2 → no limit. Plus a regression asserting the
  campaign seed's segments 1–8 and 11–12 return "no limit" and 9–10 return 100.3°.
- **Acceptance:** the campaign seed settles without the crossing floor, then a 30 s ODE
  window at the resulting twist (~59°) checked for a steady line tension and no runaway
  twist. This is the one that decides whether the corrected floor is stable in the ODE
  or whether the tight floor was accidentally holding something else down. Expect the
  preload to fall to the bare profile and ring compression to fall with it.

**Reassurance for the change:** the current gate admits nothing Tulloch forbids, so
correcting it can only loosen the design floor. It cannot make an accepted design
unsafe on the thesis criterion. It can, however, move every campaign number that
depends on preload, ring compression or the torsional FoS — so it needs the acceptance
run and a re-baseline, not a quiet edit.

---

## 5. Working-tree observation (unrelated to this audit)

The tree carries 11 modified `src/` files. On it, `test/test_trpt_realisability.jl`
fails at line 131 (`maximum(r.demand) < 1.0`) and `settle_to_operational_state` on the
campaign seed raises from `trpt_matched_place` (`initialization.jl:1819`) with
"TRPT segment 12 of 12 is past the torsional realisability cliff: transmitting
τ = 10564.74 N·m at T = 68.2 N/line needs sin(Δα) = 16.1376 > 1". Flagged, not
diagnosed: it may be a parallel session mid-change. Every number in this audit is read
from the committed text of the formulas, which the working tree does not alter.
