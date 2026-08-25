# Tulloch PhD thesis — TRPT ring compression passages (source extract)

**Purpose:** literature check for the two sign-sensitive terms in the
three-section TRPT plan (`docs/plans/2026-08-25-three-section-trpt-geometry.md`):
1. the **hoop sign** — whether a cone's small end is net-compressed or
   net-expanded, and
2. the **transition compression law** — the kink-load multiplier at a radius step.

**Source:** `Tulloch, PhD Thesis Final Submission.pdf`, 308 pp, Windswept
drive `03_Engineering/Academic Uni & Research/Strathclyde/`.
**Extraction:** `pdftotext -layout` 2026-08-25 (Hermes, desktop) — replaces
the earlier `/tmp/tulloch.txt` extract referenced in
`handovers/handover-2026-08-16-anchor-session.md`. Full text:
`docs/validation/tulloch-thesis-extract.txt` (19,670 lines; line numbers below
refer to that file). Ligature escapes (`\x1b`, `\x1c`, `\x1e`) restored to
fl/fi/ffi in the quotations below.

---

## Rotor ring: net EXPANSION (lines 5130–5157, verbatim)

> The bank angle, and on some rotors tested the anhedral arc, of the wings
> provide a radial force that acts to **expand the ring**. The centrifugal
> forces, on the rotors components as they rotate, provide an additional
> radial force that also acts to **expand the rotor**. The expansion of the
> rotor ensures that many of the load paths within the rotor are tensile, thus
> using the tensegrity principle. It is also crucial to the transmission of
> torque down to the ground station...
>
> The ring, in particular, ensures that the wings follow the desired flight
> path. The radial tethers main role is to limit the radial deformation of the
> ring, ensuring that it maintains a circular shape. The radial forces act to
> expand the rotor and keep the structure in tension.

## Cone angle & ring compression (lines 5730–5772, verbatim)

> The TRPT shown in Figure 3.10 is used for a number of the experiments
> conducted as part of this work. It consists of five carbon fibre rings, the
> top ring is also the Daisy Kite's rotor... The TRPT shown in Figure 3.10 was
> designed to have a **cone angle of 22°**. This is to avoid any abrupt changes
> in the TRPT's diameter. As torsion is applied to the TRPT, the system
> deforms... In its initial state the tethers are parallel to the axis of
> rotation, and therefore unable to react any torsional force. Once two
> adjacent rings have different rotational positions relative to one another,
> the tethers are no longer parallel to the axis of rotation. The tethers are
> then able to react against the torsion and transmit torque along the TRPT.
>
> As the TRPT deforms the outer tethers move inwards towards the axis of
> rotation. If the six outer tethers reach the axis of rotation they will
> cross and the transmittable torque collapses to zero. **The rings within the
> TRPT act to resist this compression force, keeping the outer tethers away
> from the central axis.** When designing the TRPT it was feared that an abrupt
> change in the TRPT diameter would increase the compression force beyond the
> rings ultimate strength, causing the rings to fail. **By slowly decreasing the
> TRPT diameter from the flying rotor down to the ground stations wheel, the
> compressive forces within the TRPT are kept low.**

## Failure modes (lines 5966–6029, verbatim)

> As mentioned previously, if the outer tethers reach the central axis and
> cross, the transmittable torque collapses to zero. This will occur if the
> TRPT is overloaded with torque such that the torsional deformation between
> two adjacent rings exceeds 180°. ... It is also noted that if the tethers
> are allowed to continually twist round each other, such that the torsional
> deformation between adjacent rings becomes much larger than 180°, **the
> compression force on the rings will increase beyond their ultimate strength,
> causing the rings to fail.** The distance between adjacent rings dictates the
> point at which this occurs. If the diameter of the rings is larger than the
> length of the tethers between two adjacent rings, it is not possible for the
> torsional deformation to reach 180°. In this case the tethers or rings will
> fail if the TRPT is overloaded with axial tension or torque.
>
> The TRPT has three main failure modes; 1) Tethers cross due to excessive
> torsional deformation, 2) tethers fail due to excessive tension and 3) rings
> fail due to excessive compression force.

## Design guidance (lines 16210–16245, verbatim)

> The radius of the current TRPTs are decreased slowly from the rotor towards
> the ground station to avoid any abrupt changes in diameter. Given the
> advantage of reducing the TRPT radius a new TRPT design is proposed. By
> reducing the TRPT radius down to a minimum at the rotor the tether drag can
> be reduced. In the proposed TRPT design the first TRPT ring is in the plane
> of the rotor and the TRPT has a constant radius along its length.
>
> As the TRPT radius is decreased the force ratio will increase thus requiring
> a smaller length to radius ratio. The lower sections of TRPT-5, the most
> recent TRPT prototype, have a radius of 0.35 m. If this radius was used a
> maximum force ratio of 0.72...

---

## What this gives the two sign-sensitive terms (interpretation — NOT thesis text)

1. **Hoop sign.** The thesis states both signs explicitly: the ROTOR ring is
   net-expanded (wing bank/anhedral + centrifugal radial force, §3.1.2), while
   the CONE rings carry net compression (tethers move inward under twist and
   the rings "resist this compression force", §3.1.3). It does not give a
   closed-form signed expression — for that see the Wacker extract, whose
   signed radial attachment angle ϕ = tan⁻¹((cos δ·R1 − R2)/Ls) is the
   quantitative version of the same sign distinction.
2. **Transition compression law.** Qualitative only, stated twice: a 22° cone
   angle was chosen "to avoid any abrupt changes in the TRPT's diameter", and
   an abrupt diameter change was feared to push ring compression "beyond the
   rings ultimate strength". The thesis gives the design rule (taper slowly,
   bounded cone slope), not a multiplier. The quantitative kink multiplier is
   again Wacker eq 4.12. The field-calibrated numbers here: 22° cone angle,
   TRPT-5 lower-section radius 0.35 m.
3. **Ring compression as a real failure mode** is confirmed as thesis failure
   mode 3 ("rings fail due to excessive compression force"), alongside the
   >180° twist threshold discussion.
