# Wacker MSc thesis — TRPT frame force & section mass (source extract)

**Purpose:** literature check for the two sign-sensitive terms in the
three-section TRPT plan (`docs/plans/2026-08-25-three-section-trpt-geometry.md`):
1. the **hoop sign** — whether a cone's small end is net-compressed or
   net-expanded (KTD currently wraps `F_inward` in `abs()` in
   `src/structural_safety.jl`), and
2. the **transition compression law** — the kink-load multiplier at a radius step.

**Source:** `Structural optimisation of AWES with rotary transmission Jannis
Wacker.pdf`, 57 pp, Windswept drive
`03_Engineering/Academic Uni & Research/DTU Denmark/`.
Appendix (Matlab code + optimisation data): GitHub repo
`MScWacker/MSc-Thesis-Appendix` ("Structural optimisation of airborne wind
energy systems with rotary transmission").

**Extraction:** `pdftotext -layout` 2026-08-25 (Hermes, desktop). Full text:
`docs/validation/wacker-thesis-extract.txt` (2,054 lines; line numbers below
refer to that file). Ligature escapes (`\x1b`, `\x1c`, `\x1e`) restored to
fl/fi/ffi in the quotations below.

---

## §4.2.4 Structural Analysis — frame (ring) force resolution, signed

Lines 899–948 (verbatim, layout cleaned):

> The structural analysis of the TRPT serves two purposes. Firstly the tether
> and frame tube diameters dt and df are found which are needed for precise
> drag calculations. And secondly, the mass of the tethers and frames mt and
> mf are added to the lifter, blade and the ground station mass to find the
> total system mass m. The forces are due to tension and torque from rotor and
> lifter. Centrifugal forces will not be considered. Further, the components
> are considered stiff and non flexible.
>
> The material properties for the tethers and frames, which are made from high
> performance polyethylene Dyneema and carbon fibre tubes respectively, are set
> in this sub-model. Namely the tensile and compression strengths σtensf,
> σcompf, σtenst, σcompt as well as the densities ρf and ρt.
>
> The tensile force Ft acting on a tether depends on the TRPT shape and the
> applied axial tension T.
>
>     Ft = T / (cos(κ) · nt)                                  (4.8)
>
> Where κ is the angle between the tether orientation êt and the axis of
> rotation êx, with κ = êt · êx. Tulloch showed that cos(ϕ) is equal to the
> ratio of the frame distance to the tether length Ls/Lt, such that
>
>     Ft = T · Lt / (nt · Ls)                                 (4.9)
>
> The forces acting in the frame tube are caused by the in and outgoing tethers
> and can be derived from the geometry. Only the radial component (with respect
> to the rotation plane) of Ft is acting on the frame tube as force Fft. When
> φ is the angle between two frame sides φ = (2nf−4)π/(2nf) and ϕ is the
> **radial attachment angle**
>
>     ϕ = tan⁻¹( (cos(δ)·R1 − R2) / Ls )                     [radial attachment angle]
>
> then
>
>     Fft = Σ_out(i=in)  (T_i / 2) · tan(ϕ) · tan(φ/2)       (4.12)
>
>     Aft = Σ_out(i=in)  T_i · tan(ϕ) · tan(φ/2) · SF / σcomp,f   (4.13)
>
> All polygons and tethers are assumed to remain rigid, meaning neither the
> side lengths nor the angles at each corner are changing. Strong centrifugal
> forces can cause significant deformations at the rotor polygon. However,
> these can be reduced by choosing nf = nt or increasing the structural
> strengths of the polygons.
>
> To find the material mass the cross-sectional area must be multiplied by the
> frame tube length lft = 2R·sin(π/nf), the number of frame sides nf and the
> density of carbon fibre, estimated as ρf = 1600 kg/m³ [20].
>
>     mf = Σ_nR(i=1)  nf · Aft_i · lft_i · ρf                    (4.14)
>
>     m = mf + mt + ml + mb + mg                               (4.19)

**Nomenclature from the surrounding text:** R1 = upper frame radius of a
section (rotor-side), R2 = lower frame radius (ground-side), Ls = section
length, δ = torsional deformation angle, nf = polygon corners, nt = tethers,
SF = safety factor (= 5), σcomp,f = frame material compression strength.
Frame radii are per-section design variables: line 710 —
"Frame radii  Rrot, R2, ..., Rgen".

## TRPT section geometry (lines 801–835)

>     Q = R1·R2·T / √(lt² − R1² − R2² + 2·R1·R2·cos δ)         (4.1)
>
>     ls = √(lt² − R1² − R2² + 2·R1·R2·cos δ)                  (4.2)
>
> TRPT sections with Lt > R1 + R2 fail when δ reaches 180° and the tethers
> cross the axis...

Optimisation constraints are per-section (lines 1582–1583, 1601–1602):

>     δi < δc,i   for Lt,i > R1,i + R2,i   ∀i ∈ nL
>     δi < δlim,i for Lt,i ≤ R1,i + R2,i   ∀i ∈ nL

## Stated limitations (lines 1311–1316, verbatim)

> The frame analysis is limited to the material strength and does not consider
> buckling or bending effects. However, the frame is made of tubes in order to
> increase the second moment of area and reduce the risk of buckling. Further,
> the centrifugal forces are neglected, which would act opposite to the
> compression forces. In comparison to other components the weight
> contribution of the tethers and frames is minuscule, only making up around
> 2% of the total mass.

Also (lines 1044–1047): the drag model "diverges from Tulloch's model, by
increasing the number of tether partitions ntp from 2 to 20. Since the
rotation radius Rtp is non-linear along a tether section, an increased ntp
improves the accuracy of the numerical approximation for TRPT sections with
**a change in frame radius** or deformation δ ≠ 0."

---

## What this gives the two sign-sensitive terms (interpretation — NOT thesis text)

1. **Hoop sign.** Eq 4.12 is signed through tan(ϕ), and ϕ is signed through
   (cos δ·R1 − R2):
   - cylinder (R1·cos δ = R2): ϕ = 0 → **Fft = 0** (no frame compression);
   - cone shrinking downward (R1·cos δ > R2): ϕ > 0 → **compression**;
   - section expanding downward (R1·cos δ < R2): ϕ < 0 → tan(ϕ) < 0 → the
     frame load is **negative = net expansion/tension**, not compression.
   KTD's `abs(dot(−dir, r̂))` in `structural_safety.jl` discards exactly this
   sign; Wacker's formulation keeps it.
2. **Transition compression law.** At a radius step, the frame compression per
   side scales as (T/2)·tan(ϕ)·tan(φ/2) with tan(φ/2) = cot(π/nf). This is the
   kink-load multiplier: zero for a cylindrical section, growing with the
   per-section radius step ΔR ≈ R1·cos δ − R2 relative to Ls. KTD's polygon
   compression N_comp = F_v/(2·tan(π/n)) is the same polygon resolution —
   Wacker adds the signed per-section attachment angle ϕ that KTD replaces
   with `abs(dot(...))`.
3. **Section mass between uneven rings.** Eq 4.13/4.14 size each frame's
   cross-section from its local per-section compression force and sum the mass
   per ring — per-section mass allocation between unevenly sized rings, as a
   steady-state sizing model (material-strength criterion, SF=5; no Euler
   buckling, which KTD adds; frames+tethers ≈ 2% of total mass in his model).
