# src/trpt_optimization.jl
# TRPT Sizing Optimization module — Item B2.
#
# Physics model for the pentagonal TRPT rigid frame, sized for survival at
# peak 25 m/s wind loads with FOS ≥ 1.8.  Supports three manufacturable beam
# profiles (hollow circular, hollow elliptical, symmetric airfoil shell) and
# a scaling-along-length geometry for the pentagon frames.
#
# Mass model explicitly includes discrete 50 g knuckle point masses at each
# pentagon vertex (per B2 spec user approval, 2026-04-20).
#
# All structural analysis is analytic (Euler buckling + thin-wall second
# moment of area) so each objective-function evaluation is ≪1 ms.  This keeps
# the 168-hour search feasible with >1e8 evaluations of headroom.

using LinearAlgebra

# ── Material and manufacturability constants ─────────────────────────────────
# Re-used from structural_safety.jl (CFRP hollow tube).
const OPT_E_CFRP = DEFAULT_CFRP.E     # Pa   — Young's modulus
const OPT_RHO_CFRP = DEFAULT_CFRP.density   # kg/m³ — density
const OPT_T_MIN_WALL = 5e-4     # m    — 0.5 mm min manufacturable wall
const OPT_T_OVER_D_MAX = 0.15     # unitless — above this, tube collapses to solid rod
const OPT_T_OVER_D_MIN = 0.01     # unitless — below this, local shell buckling governs (V6.2: widened from 0.02)
const OPT_KNUCKLE_MASS_KG = 0.050    # kg — per-vertex knuckle (user approval 2026-04-20)

# Minimum manufacturable tube WALL thickness (2026-09-02, Rod — ticket T1).
# The DE's Do(r) = Do_top·(r/r_hub)^Do_scale_exp let small-radius rings
# collapse to ~0.06 mm walls; enforce 2 mm everywhere a tube wall is sized.
# This also forces a minimum sensible OD, since a 2 mm wall cannot fit inside
# a <4 mm tube (handled by clamping the wall to a solid rod below that size).
const MIN_TUBE_WALL_M = 2e-3    # m — 2 mm min wall

# ── Peak design load conditions ──────────────────────────────────────────────
const OPT_V_PEAK = 25.0   # m/s — peak design wind speed
const OPT_CT_PEAK = 1.0   # max BEM thrust coefficient (conservative)
const OPT_FOS_REQUIRED = 1.8     # Factor of Safety (hard constraint)
const OPT_TORSION_MARGIN = 1.10    # Required ratio A_actual / A_buckling_limit
const OPT_TORSION_FOS_REQUIRED = 1.5 # Tulloch torsional stability FOS (hard constraint)
const OPT_CT_RATED = 0.55    # Thrust coefficient at rated BEM operation
const OPT_TSR_RATED = 4.1     # Optimal tip-speed ratio

# ── Knuckle mass model (coupled to beam geometry) ─────────────────────────────
# Each knuckle is a bent CFRP tube section coupling two adjacent polygon beams.
# Mass scales with Do × t × (2·L_clamp + L_bend), where L_bend = Do·4/n_sides.
# L_clamp = 1.0·Do represents a weight-optimised cuff with lightening cutouts.
const KNUCKLE_L_CLAMP_FACTOR = 1.0   # beam engagement length / Do
const RHO_KNUCKLE = 1600.0           # kg/m³ — CFRP density (same as beams)
const KNUCKLE_T_WALL_FACTOR = 1.0    # knuckle wall t relative to beam t

"""
    knuckle_mass_at_ring(Do, t_over_D, n_sides) → Float64

Per-vertex knuckle mass (kg) for a bent CFRP tube coupling joining two beams
at a polygon vertex. Assumes weight-optimised patterning on the cuff.

Do: beam outer diameter (m), t_over_D: beam wall thickness ratio, n_sides: polygon sides.
"""
function knuckle_mass_at_ring(Do::Float64, t_over_D::Float64, n_sides::Int)
    t = t_over_D * Do * KNUCKLE_T_WALL_FACTOR
    L_clamp = KNUCKLE_L_CLAMP_FACTOR * Do
    L_bend = Do * 4.0 / n_sides
    L_eff = 2 * L_clamp + L_bend
    return RHO_KNUCKLE * π * Do * t * L_eff
end

"""
    tube_wall_thickness(Do, t_over_D) → Float64

Wall thickness of a CFRP tube with outer diameter `Do` and wall ratio
`t_over_D`, floored at `MIN_TUBE_WALL_M` (2 mm) and clamped to a solid rod
(`t ≤ Do/2`) so a tube thinner than 4 mm cannot take a wall that exceeds its
own radius.  Single authority for the wall used in ring mass (2026-09-02, T1).
"""
function tube_wall_thickness(Do::Float64, t_over_D::Float64; min_wall_m::Float64=MIN_TUBE_WALL_M)::Float64
    return min(max(t_over_D * Do, min_wall_m), Do / 2.0)
end

"""
    ring_beam_mass(Do, t_over_D, n_lines, L) → Float64

Mass (kg) of one polygon ring made of `n_lines` hollow CFRP tube segments,
each of length `L`, outer diameter `Do`, wall `tube_wall_thickness(Do, t_over_D)`.
This is the single authority for ring beam mass (2026-09-02, T1): the builder
and the airborne-mass sum both use it, so the ring weight is never averaged or
computed twice.
"""
function ring_beam_mass(Do::Float64, t_over_D::Float64, n_lines::Int, L::Float64; min_wall_m::Float64=MIN_TUBE_WALL_M)::Float64
    t = tube_wall_thickness(Do, t_over_D; min_wall_m=min_wall_m)
    area = π / 4.0 * (Do^2 - (Do - 2.0 * t)^2)
    return n_lines * OPT_RHO_CFRP * area * L
end

"""
    solve_ring_Do(N_comp, L, t_over_D; min_wall_m, fos_req, ends) → Do

Solve the tube outer diameter `Do` (m) of one polygon-ring beam (length `L`)
so its Euler buckling capacity meets `fos_req × N_comp`:

    P_crit = strut_properties(CircularTube(Do, t_eff), L, ends).P_crit
    t_eff  = tube_wall_thickness(Do, t_over_D; min_wall_m) / Do

`P_crit` is monotone in `Do`, so a bisection converges.  Uses the single wall
authority `tube_wall_thickness` and a single end condition (`ends`) so the
closed-form solve and the verification FEA agree (REV 2 §6).  Returns `Do` (m);
returns the manufacturable floor when `N_comp ≤ 0` (no compression).
"""
function solve_ring_Do(
    N_comp::Float64,
    L::Float64,
    t_over_D::Float64;
    min_wall_m::Float64=MIN_TUBE_WALL_M,
    fos_req::Float64=2.5,
    ends=FixedFixedEnds(),
)
    N_comp <= 0.0 && return 1e-3
    lo = 1e-3
    hi = 0.5
    # Grow hi until feasible (P_crit ≥ fos_req · N_comp).
    while strut_properties(
        CircularTube(hi, tube_wall_thickness(hi, t_over_D; min_wall_m=min_wall_m) / hi),
        L, ends,
    ).P_crit < fos_req * N_comp
        hi *= 2.0
    end
    for _ in 1:80
        mid = 0.5 * (lo + hi)
        t_eff = tube_wall_thickness(mid, t_over_D; min_wall_m=min_wall_m) / mid
        if strut_properties(CircularTube(mid, t_eff), L, ends).P_crit >= fos_req * N_comp
            hi = mid
        else
            lo = mid
        end
    end
    return hi
end

# ── Closed-form sizing load model (R7, 2026-09-10) ────────────────────────────
# The sizing load per ring is the signed sum of three terms (REV 2 §5):
#
#     F_v = F_kink + F_helix − F_centrifugal
#
# * F_kink — the taper-transition (kink) force: the radial component of each
#   adjacent segment's line tension.  Exact geometry, signed: outward where the
#   line below leans outward (cylinder→cone transition), inward at the cone top.
# * F_helix — the torque-helix inward force, `HELIX_LOAD_FACTOR · T_line`.
#
#   THE 0.32 CALIBRATION WAS STALE AND IS RETRACTED (2026-09-16).  It was
#   measured 2026-09-10 on the pre-re-seed machine (L/r 2.0, 8 rings) and, per
#   the sizing-margin probe header, without the full matched twist.  On the
#   current re-seeded machine (L/r 1.5, 13 rings, matched twist) the FEA reads
#   `N_comp / T_line` = **1.186** at the bottom of the transmission cylinder, so
#   0.32 under-sized every cylinder ring by up to 3.7x.  Measured with
#   `scratch/diag_helix_calibration.jl` on `SEED_LR15_FROZEN`, which is
#   byte-identical to `seed_genome(5.0)`.
#
#   The value below is the LEGACY ENVELOPE (`OPT_DESIGN_LOAD_FACTOR` = 1.2,
#   "F_in_per_vertex = DLF × T_line") that R7 replaced with the 0.32.  The
#   re-measurement VINDICATES the envelope: this closed form's `T_line` (~360 N)
#   already runs above the FEA's mean segment tension (~232 N), so `1.2·T_line`
#   envelopes the FEA's worst-sample beam axial force (432 N against 427 N at
#   ring 2).  This is a deliberate conservative envelope, not a fit: the FEA's
#   ratio decays ≈ linearly to 0.866 by ring 8, because the ring axial force
#   ACCUMULATES downward — a local per-ring term cannot reproduce that shape.
#   A decay profile would save upper-cylinder mass; deferred, the envelope is
#   the safe choice.
# * F_centrifugal — outward relief from the ring's own rotating mass; zero at
#   ω = 0, which is why the (T_peak, ω=0) hub case is the binding one.
const HELIX_LOAD_FACTOR = 1.2    # F_helix / T_line; re-measured envelope (2026-09-16)

# The static thrust tension under-predicts the settled ODE segment tension by
# ≈ 15–20 % (ring weight projected on the shaft, ring-plane tilt, and the
# dynamic component).  Measured 2026-09-10: ODE seg-1 tension 365 N vs static
# thrust + lifter 308 N.  Applied to the thrust-derived part only — the lifter
# floor is known exactly.
const TENSION_LOAD_MARGIN = 1.2

# Closed-form → FEA approximation margin on the FoS requirement.  The solve is
# Euler-only on a single beam (one K, one wall); the verification FEA is a space
# frame that also carries bending (`util = N/N_crit + M/M_el`).  Measured
# 2026-09-10 on the 5 kW seed: with a 1.0 margin the FEA read FoS 1.85 (cone-top
# kink) and 2.34 (bending-dominated harvest ring) against a 2.5 floor; the
# 5 s acceptance window can dip ~15 % below the static FEA reading.  1.3 leaves
# the windowed FEA at ≥ 2.5 with headroom.
#
# RE-OPENED 2026-09-16.  That calibration was made while the helix term was
# under-sized (HELIX_LOAD_FACTOR = 0.32), so `fos_req` was never the binding
# constraint and 1.3 was never really exercised.  With the load model corrected
# the margin becomes a LIVE lever again and must be re-swept against the
# 5 s (P1) and 20 s (A3) windows.
const SIZING_FOS_MARGIN = 1.3

# ── Manufacturability floor on the ring tube outer diameter ──────────────────
# The Euler solve happily returns ~5.5 mm for a lightly compressed ring, because
# a 2 mm min-wall on a 5.5 mm OD is t/D ≈ 0.36 — a solid wire, not a tube, and
# not a manufacturable TRPT ring member.  It also made the sizing target INERT:
# every cylinder ring sat on the wall clamp, so `fos_req` (and therefore
# `SIZING_FOS_MARGIN`) could not move the section at all.  Measured 2026-09-16:
# margins 1.3 / 1.5 / 1.7 gave FoS 0.609 / 0.682 / 0.670 — non-monotonic, i.e.
# noise.  Flooring Do here puts the solve back in a real tube regime.
#
# VALUE (measured, `scratch/probe_do_floor_margin.jl`, margin 1.3, both windows):
#   6 mm -> FoS 2.294 (FAILS the 2.5 floor)   m_air 31.824 kg
#   8 mm -> FoS 2.521 (0.8 % headroom)        m_air 31.909 kg
#  10 mm -> FoS 4.164 (5 s AND 20 s)          m_air 32.492 kg   <-- chosen
#  12 mm -> FoS 5.336 / 5.171                 m_air 33.115 kg
# 10 mm is the lightest floor with real headroom; 12 mm buys 1.0 more FoS for
# 0.62 kg.  10 mm on a 2 mm wall is t/D = 0.2 — a genuine tube.
const MIN_RING_DO_M = 0.010

"""
    BeamSizing

Per-ring closed-form beam sections solved by [`size_beams_closed_form`](@ref).

Ground-first: index 1 is the ground ring, `length(radii)` is the hub ring.
`Do_per_ring[i]` is the solved outer diameter so the ring's Euler buckling
capacity (single wall authority `tube_wall_thickness`, single end condition)
meets `fos_req` under the signed kink + helix load.
"""
struct BeamSizing
    Do_per_ring::Vector{Float64}      # m — outer diameter per ring (ground-first)
    t_over_D::Float64                 # pinned wall ratio (single authority)
    N_comp_per_ring::Vector{Float64}  # N — axial compression per ring
    T_line_per_ring::Vector{Float64}  # N — line tension per ring
    fos_per_ring::Vector{Float64}     # Euler FoS at the solved Do
    fos_req::Float64
    helix_factor::Float64
    omega_eq::Float64                 # rad/s — equilibrium shaft speed used
end

"""
    size_beams_closed_form(dec, p_base, cfg; t_over_D, ends) → BeamSizing

Size every TRPT ring's tube closed-form from the decoder's rotor stack (R7,
2026-09-10).  Drop-in replacement for the four free beam genes: once the rotors
are decoded the thrust/torque/tension are fixed, and the beam follows.

The load build reproduces `objective_v10`'s per-ring build on the **v5
three-section geometry** (`dec.radii`/`dec.zs`) with these corrections:

1. **Ground-first orientation.** `rotor.ring_idx` is already a ground-first
   system ring index (hub = `length(radii)`); the build uses `gi = ri` (the
   legacy caller applied `gi = ri + 1`, shifting every expansion rotor one ring
   toward the hub).
2. **Hub rotor counted once.** Expansion params come from the single authority
   `expansion_params_from_rotors`, which excludes the hub rotor.
3. **Top-down tension.** Each expansion rotor's `T_above` is the cumulative
   thrust of the rings actually above it, computed after the higher rotors have
   been placed.
4. **Actual hub annulus + operating CT.** The legacy build used a BEM *radius
   for power* at the sheared local wind (~2.1 m) while the ODE rotor is the
   decoded blade tip (≈ 3.66 m); thrust ∝ R², a ≈ 3× under-estimate.  The
   thrust now uses the decoded annulus and `ct_at_tsr(λ)` at the equilibrium ω.
5. **Lifter tension floor.** The constant-tension lifter pre-tensions every
   segment (`T_lift / n_lines`), so `T_min` is not zero.  The ODE budget
   (`scratch/r7_tension_budget.jl`) is thrust + lift + weight/tilt.

`F_v = F_kink(signed) + HELIX_LOAD_FACTOR·T_line` (centrifugal relief is NOT
applied — see the in-loop note), and `solve_ring_Do` is called per ring with a
`SIZING_FOS_MARGIN` because the solve is Euler-only while the verification FEA
also carries bending.  The **hub ring is a first-class load case**: sized at the
worse of the rated load and `(T_peak, ω = 0)` — peak-wind thrust with the rotor
stopped, i.e. no helix torque.  Beam self-mass (and therefore the lifter
tension) feeds back, so `n_mass_passes` fixed-point passes are run.

`cfg` is duck-typed (defined later in the include order) and supplies
`power_W`, `v_rated`, `min_wall_m`, `fos_hard` and `t_over_D`.
"""
function size_beams_closed_form(
    dec,
    p_base,
    cfg;
    t_over_D::Float64=cfg.t_over_D,
    ends=FixedFixedEnds(),
    n_mass_passes::Int=3,
    hub_peak_load::Bool=true,
    helix_factor::Float64=HELIX_LOAD_FACTOR,
    # Margin between the closed-form Euler solve and the windowed FEA acceptance
    # floor.  Exposed as a keyword (2026-09-16, Rod) so it can be SWEPT without
    # editing a `const`: it is global — every ring, every design — so any change
    # re-baselines ring mass and the whole campaign, and that decision needs a
    # measured basis rather than a guess.  Default preserves current behaviour.
    sizing_fos_margin::Float64=SIZING_FOS_MARGIN,
    # Manufacturability floor on the tube outer diameter.  Exposed for the same
    # reason as `sizing_fos_margin`: it is global (every ring, every design) and
    # it BINDS — once the load model was corrected, all seven cylinder rings sat
    # on this floor — so its value needs a measured basis, not a guess.
    min_Do_m::Float64=MIN_RING_DO_M,
)
    design = dec.design
    rotors = dec.rotors
    radii = dec.radii
    zs = dec.zs
    n_rings_tot = length(radii)
    n_lines = design.n_lines
    n_active = dec.n_active
    elev_rad = π / 6
    elev_deg = rad2deg(elev_rad)
    n_seg = n_rings_tot - 1
    L_seg = diff(zs)
    den = 2.0 * sin(π / n_lines)

    # ── 1. Expansion params EXCLUDING the hub rotor (single authority) ──────
    expansion_params = expansion_params_from_rotors(rotors, n_rings_tot, n_lines)

    # ── 2. Equilibrium shaft speed (the solve objective_v10 uses) ───────────
    P_per_rotor = n_active > 0 ? cfg.power_W / n_active : cfg.power_W
    v_ref_rotor = isempty(rotors) ? cfg.v_rated : rotors[1].v_wind
    λ_eff = n_active > 0 ? rotors[1].blade_scale : 1.0
    k_mppt_eff = p_base.k_mppt * λ_eff^2
    p_scaled = override_params(p_base; k_mppt=k_mppt_eff)
    ω_solved, _ = solve_equilibrium_self_consistent(
        design, expansion_params, p_scaled, n_lines, radii, zs;
        P_per_rotor=P_per_rotor, v_wind=cfg.v_rated, elev_rad=elev_rad,
    )
    ω_num = (ω_solved === nothing || !isfinite(ω_solved)) ? 0.0 : ω_solved

    # ── 3. Hub (main) rotor thrust from its ACTUAL swept annulus ────────────
    hub_rotor = nothing
    for rot in rotors
        if rot.ring_idx == n_rings_tot
            hub_rotor = rot
            break
        end
    end
    T_hub = if hub_rotor === nothing
        r_ref = BEM.rotor_radius_for_power(P_per_rotor, v_ref_rotor, n_lines)
        peak_hub_thrust(r_ref, elev_rad; v=cfg.v_rated, CT=OPT_CT_RATED)
    else
        v_hub = max(cfg.v_rated * hub_rotor.wind_factor, 0.1)
        r_out = radii[n_rings_tot] + hub_rotor.blade_tip_radius
        r_in = max(radii[n_rings_tot] + hub_rotor.blade_hub_radius, 0.0)
        A_hub = π * (r_out^2 - r_in^2)
        λ_op = ω_num > 0.0 ? ω_num * r_out / v_hub : 0.0
        ct_op = λ_op > 0.0 ? clamp(ct_at_tsr(λ_op), 0.0, 1.0) : OPT_CT_RATED
        0.5 * p_base.rho * v_hub^2 * A_hub * ct_op * cos(elev_rad)^2
    end

    # Expansion rotors: axial thrust lands on the rotor's OWN ring (gi = ri).
    thrust_per_ring = zeros(Float64, n_rings_tot)
    thrust_per_ring[n_rings_tot] = T_hub
    F_radial_per_ring = zeros(Float64, n_rings_tot)
    for er in sort(expansion_params; by=r -> r.ring_idx, rev=true)
        gi = er.ring_idx
        (1 <= gi <= n_rings_tot) || continue
        T_above = gi < n_rings_tot ?
            sum(@view thrust_per_ring[(gi + 1):end]) / n_lines : 0.0
        F_radial, F_axial, _, _, _ = expansion_rotor_forces(
            er, p_base.rho, cfg.v_rated, ω_num, elev_deg, radii[gi], T_above, n_lines
        )
        thrust_per_ring[gi] += F_axial
        F_radial_per_ring[gi] += F_radial
    end

    # Per-segment axial tension from rotor thrust (before the lifter floor).
    T_seg_thrust = zeros(Float64, n_seg)
    for s in 1:n_seg
        T_seg_thrust[s] = sum(@view thrust_per_ring[(s + 1):end]) / n_lines
    end

    # ── 4. Per-ring sizing (fixed-point passes for beam mass + lifter) ──────
    Do_per_ring = fill(0.05, n_rings_tot)
    N_comp_per_ring = zeros(Float64, n_rings_tot)
    N_rated_per_ring = zeros(Float64, n_rings_tot)  # compression before the hub peak case
    T_line_per_ring = zeros(Float64, n_rings_tot)
    for _pass in 1:max(n_mass_passes, 1)
        # Constant-tension lifter floor for THIS pass's beam mass.  Mirrors
        # sized_lifter_for(margin=1.5, elevation=70°) — the machine carries
        # itself, so the lifter's own 5 kg is excluded (Rod 2026-08-21).
        m_air = _closed_form_airborne_mass(Do_per_ring, dec, p_base, t_over_D, cfg)
        T_lift_line = 1.5 * m_air * 9.81 / sind(70.0) / n_lines

        for i in 1:n_rings_tot
            r = radii[i]
            L_poly = 2.0 * r * sin(π / n_lines)
            line_len_below = i > 1 ?
                sqrt(L_seg[i - 1]^2 + (radii[i] - radii[i - 1])^2) : NaN
            line_len_above = i < n_rings_tot ?
                sqrt(L_seg[i]^2 + (radii[i + 1] - radii[i])^2) : NaN
            T_below = TENSION_LOAD_MARGIN * (i > 1 ? T_seg_thrust[i - 1] : 0.0) + T_lift_line
            T_above = TENSION_LOAD_MARGIN * (i < n_rings_tot ? T_seg_thrust[i] : 0.0) +
                      T_lift_line

            # Signed taper kink: tension pulls each ring toward its neighbours.
            F_kink = 0.0
            if i > 1
                F_kink += T_below * (r - radii[i - 1]) / line_len_below
            end
            if i < n_rings_tot
                F_kink += T_above * (r - radii[i + 1]) / line_len_above
            end
            T_line = max(T_below, T_above)

            # Hub ring = (T_peak, ω = 0): no centrifugal relief, no helix.
            # Ground ring (1) is fixed and does not rotate.
            ω_i = (i == 1 || i == n_rings_tot) ? 0.0 : ω_num

            # (beam + knuckle self-mass enters the lifter floor through
            #  `_closed_form_airborne_mass` above, not through a radial relief)

            # Centrifugal relief is NOT applied.  A rotating ring's own mass does
            # relieve compression physically, but the ODE models blade/ring
            # rotational mass as INERTIA (`dω/dt = τ/(I_z + J_rotor)`,
            # 2026-08-25) and `analyse_ring` applies no radial centrifugal term,
            # so the verification FEA sees pure kink + helix.  Applying the
            # relief here made the closed form under-size against its own
            # verifier (ring 7 FEA FoS 1.85).  Recorded as a model gap.
            F_helix = (ω_i > 0.0) ? helix_factor * T_line : 0.0
            N_comp = max(F_kink + F_helix, 0.0) / den
            N_rated_per_ring[i] = N_comp
            Do_rated = solve_ring_Do(
                N_comp, L_poly, t_over_D;
                min_wall_m=cfg.min_wall_m, fos_req=cfg.fos_hard * sizing_fos_margin, ends=ends,
            )

            # Hub ring: additionally size at (T_peak, ω = 0) — peak wind,
            # rotor stopped.  Thrust scales v², the helix vanishes, and the
            # centrifugal relief is gone.
            if i == n_rings_tot && hub_peak_load
                scale_pk = (OPT_V_PEAK / cfg.v_rated)^2
                T_below_pk = TENSION_LOAD_MARGIN * T_seg_thrust[1] * scale_pk + T_lift_line
                F_kink_pk = T_below_pk * (r - radii[i - 1]) / line_len_below
                N_peak = max(F_kink_pk, 0.0) / den
                Do_peak = solve_ring_Do(
                    N_peak, L_poly, t_over_D;
                    min_wall_m=cfg.min_wall_m, fos_req=cfg.fos_hard * sizing_fos_margin, ends=ends,
                )
                if Do_peak > Do_rated
                    Do_rated = Do_peak
                    N_comp = max(N_comp, N_peak)
                    T_line = max(T_line, T_below_pk)
                end
            end

            Do_per_ring[i] = Do_rated
            N_comp_per_ring[i] = N_comp
            T_line_per_ring[i] = T_line
        end

        # ── Structural-spine floor for outward-dominated rings ──────────────
        # When the signed kink + helix is smaller than the outward spreading
        # force plus centrifugal relief, the Euler solve returns the 1 mm
        # floor.  A 1 mm tube is not a manufacturable TRPT ring, and those
        # rings are bending/tension dominated — a capacity the Euler-only solve
        # does not model (REV 2 §7.3 defers the bending estimate).  Floor them
        # at the strongest compression-sized ring.
        spine = 0.0
        for i in 1:n_rings_tot
            N_rated_per_ring[i] > 0.0 && (spine = max(spine, Do_per_ring[i]))
        end
        if spine > 0.0
            for i in 1:n_rings_tot
                if N_rated_per_ring[i] <= 0.0
                    Do_per_ring[i] = max(Do_per_ring[i], spine)
                end
            end
        end

        # ── Absolute manufacturability floor on the tube outer diameter ──────
        # Applied HERE, inside the mass fixed-point pass, so a floored section
        # feeds back into the lifter tension and the next pass.  Without it the
        # cylinder rings sit at ~5.5 mm with a 2 mm wall (t/D ≈ 0.36, a wire),
        # and the wall clamp — not `fos_req` — sets every section, which is what
        # made SIZING_FOS_MARGIN inert.  See MIN_RING_DO_M.
        for i in 1:n_rings_tot
            Do_per_ring[i] = max(Do_per_ring[i], min_Do_m)
        end
    end

    # ── 5. Report the Euler FoS actually achieved at the solved Do ──────────
    fos_per_ring = fill(Inf, n_rings_tot)
    for i in 1:n_rings_tot
        L_poly = 2.0 * radii[i] * sin(π / n_lines)
        t_eff = tube_wall_thickness(
            Do_per_ring[i], t_over_D; min_wall_m=cfg.min_wall_m
        ) / Do_per_ring[i]
        P_crit = strut_properties(CircularTube(Do_per_ring[i], t_eff), L_poly, ends).P_crit
        fos_per_ring[i] = N_comp_per_ring[i] > 0.0 ? P_crit / N_comp_per_ring[i] : Inf
    end

    return BeamSizing(
        Do_per_ring, t_over_D, N_comp_per_ring, T_line_per_ring,
        fos_per_ring, cfg.fos_hard, helix_factor, ω_num,
    )
end

"""
    _closed_form_airborne_mass(Do_per_ring, dec, p_base, t_over_D, cfg) → Float64

Airborne mass (kg) implied by a per-ring Do vector, mirroring
`expansion_airborne_mass(sys, p; include_lifter=false)` so `size_beams_closed_form`
can size the constant-tension lifter before a system exists.  Ring beam +
knuckle mass are summed per ring over the airborne rings (`2:end`), plus the
tether, main-rotor blades and expansion-rotor assemblies.
"""
function _closed_form_airborne_mass(Do_per_ring, dec, p_base, t_over_D, cfg)
    design = dec.design
    n_lines = design.n_lines
    radii = dec.radii
    m_tether = n_lines * design.tether_length *
               (DYNEEMA_DENSITY * π * (p_base.tether_diameter / 2)^2)
    m_rings = 0.0
    m_knuckle = 0.0
    for i in 2:length(radii)
        L_poly = 2.0 * radii[i] * sin(π / n_lines)
        m_rings += ring_beam_mass(
            Do_per_ring[i], t_over_D, n_lines, L_poly; min_wall_m=cfg.min_wall_m
        )
        m_knuckle += n_lines * knuckle_mass_at_ring(Do_per_ring[i], t_over_D, n_lines)
    end
    expansion_params = expansion_params_from_rotors(dec.rotors, length(radii), n_lines)
    m_expansion = sum(er -> er.mass, expansion_params; init=0.0)
    m_blades = 0.0
    for rot in dec.rotors
        if rot.ring_idx == length(radii)
            span = rot.blade_tip_radius - rot.blade_hub_radius
            m_blades += n_lines * M_BLADE_REF_KG * span^3
        end
    end
    n_blade_nodes = n_lines + sum(er -> er.n_blades, expansion_params; init=0)
    return m_tether + m_rings + m_knuckle + m_expansion + m_blades +
           n_blade_nodes * OPT_KNUCKLE_MASS_KG
end

# ── Combined design-load factor (DLF) ────────────────────────────────────────
# Under perfectly uniform taper + zero twist + zero gust, the net radial force
# per pentagon vertex is ZERO (tension components from segments above and below
# cancel).  In real operation the vertex feels:
#   (a) Taper-transition loads where non-uniformity exists
#   (b) Torque reaction — the peak shaft torque at fault conditions creates a
#       tangential line inclination (helix) that projects inward at each vertex
#   (c) Gust-induced asymmetric line tension — a single line can carry 1.5× the
#       mean during a 3-s gust (IEC 61400-1 coherent gust)
#
# DLF is a lumped envelope that converts line tension into an effective radial
# inward force per vertex.
#
# CALIBRATED 2026-04-20 from scripts/calibrate_dlf.jl by running the canonical
# 10 kW multi-body ODE through six structural-load scenarios and extracting the
# per-ring inward-force envelope.  Per-scenario peak DLFs:
#
#   steady 11 m/s         : 0.83   (rated operation)
#   steady 15 m/s         : 0.56
#   steady 20 m/s         : 0.40
#   steady 25 m/s         : 0.32   (peak design wind, no fault)
#   coherent gust 11→25   : 0.74   (gust transient)
#   emergency brake (3×k) : 1.39   ← FAULT CASE, MITIGATED OPERATIONALLY
#
# Reference data + figures: scripts/results/trpt_opt/dlf/.
#
# OPERATIONAL DECISION (Rod, 2026-04-20):
# Emergency brake at 3× k_mppt step is NOT a sizing case. The live system
# avoids sudden braking entirely — rotor shutdown sequence is:
#   1. Ease off the MPPT load through a controlled ramp (not a step).
#   2. Haul on the back-anchor tether to yaw the shaft off-axis.
#   3. Rotor stalls aerodynamically before mechanical braking is applied.
#   4. Haul the stalled rotor down on the lifter line.
# No step change in k_mppt ever hits the airframe in normal operation.
#
# Sizing envelope therefore excludes the ebrake peak. DLF is chosen at 1.2 to:
#   • Provide ~60% margin over the worst aero-only case (steady11 = 0.83).
#   • Cover coherent-gust transients (0.74) with 60% margin.
#   • Reserve margin for Class-A turbulence and manufacturing tolerance.
#   • Remain below the 1.39 ebrake peak (no design against avoided fault).
const OPT_DESIGN_LOAD_FACTOR = 1.2   # unitless — F_in_per_vertex = DLF × T_line

# Beam profile types — discrete choice for the optimizer (imported from SpacerRingDesign)

"""
    BeamSpec

Geometric specification of one pentagon-segment beam.

Fields:
- `profile`        — one of PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL
- `Do`             — outer dimension (m): diameter (circular), major axis (elliptical), chord (airfoil)
- `t_over_D`       — wall thickness ratio (unitless)
- `aspect_ratio`   — Do_minor / Do_major for elliptical; thickness-to-chord for airfoil; ignored for circular
"""
struct BeamSpec
    profile::BeamProfile
    Do::Float64
    t_over_D::Float64
    aspect_ratio::Float64
end

"""
    TRPTDesign

Full specification of a TRPT structural design candidate.

Fields:
- `profile`          — beam cross-section type (same for all rings)
- `Do_top`           — outer dimension at the hub-side (topmost) ring (m)
- `t_over_D`         — wall thickness ratio
- `aspect_ratio`     — profile-specific secondary dimension ratio
- `Do_scale_exp`     — exponent for Do scaling along TRPT: Do_i = Do_top × (r_i/r_top)^exp
                       exp=0 ⇒ uniform; exp=0.5 ⇒ sqrt (current baseline); exp=1 ⇒ linear
- `r_hub`            — top ring radius (m)
- `taper_ratio`      — r_bottom / r_top for the tapered pentagon stack
- `n_rings`          — number of intermediate polygon spacer rings (integer)
- `tether_length`    — total axial length of the TRPT (m, inherited from system)
- `n_lines`          — number of pentagon lines (5 for a regular pentagon)
- `knuckle_mass_kg`  — point mass at each vertex (kg)
"""
struct TRPTDesign
    profile::BeamProfile
    Do_top::Float64
    t_over_D::Float64
    aspect_ratio::Float64
    Do_scale_exp::Float64
    r_hub::Float64
    taper_ratio::Float64
    n_rings::Int
    tether_length::Float64
    n_lines::Int
    knuckle_mass_kg::Float64
end

# ── Beam cross-section properties ────────────────────────────────────────────
"""
    beam_section_properties(spec::BeamSpec) → (A, I_min, I_torsional)

Cross-section area (m²), minimum second moment of area (m⁴, controlling
Euler buckling), and torsional constant (m⁴, for reference).
"""
function beam_section_properties(spec::BeamSpec)
    tube = if spec.profile == PROFILE_CIRCULAR
        CircularTube(spec.Do, spec.t_over_D)
    elseif spec.profile == PROFILE_ELLIPTICAL
        EllipticalTube(spec.Do, spec.t_over_D, spec.aspect_ratio)
    else
        AirfoilTube(spec.Do, spec.t_over_D, spec.aspect_ratio)
    end
    # Sizing optimization campaigns use conservative PinPin ends condition
    props = strut_properties(tube, 1.0, PinPinEnds())
    return (props.A, props.I_min, props.J)
end

# ── Geometry helpers ─────────────────────────────────────────────────────────
"""
    ring_radii(design) → Vector{Float64}

Return the radii (m) of all n_rings+2 pentagon frames: ground (index 1),
intermediate (2..n_rings+1), and hub (index n_rings+2).

Ground ring is always r_bottom = r_hub × taper_ratio; hub ring is r_hub.
Intermediate rings are linearly interpolated in radius.
"""
function ring_radii(design::TRPTDesign)
    n_total = design.n_rings + 2
    r_top = design.r_hub
    r_bot = design.r_hub * design.taper_ratio
    return [r_bot + (r_top - r_bot) * (i - 1) / (n_total - 1) for i in 1:n_total]
end

"""
    segment_axial_lengths(design) → Vector{Float64}

Axial length (m) of each of the n_rings+1 inter-ring segments.
Uniform axial spacing: L_seg = tether_length / (n_rings + 1).
"""
function segment_axial_lengths(design::TRPTDesign)
    n_seg = design.n_rings + 1
    return fill(design.tether_length / n_seg, n_seg)
end

"""
    beam_spec_at_ring(design, r) → BeamSpec

Return the beam spec for a ring at radius r, using the scaling
Do_i = Do_top × (r_i / r_top)^Do_scale_exp.
"""
function beam_spec_at_ring(design::TRPTDesign, r::Float64)
    scale = (r / design.r_hub)^design.Do_scale_exp
    return BeamSpec(
        design.profile, design.Do_top * scale, design.t_over_D, design.aspect_ratio
    )
end

# ── Peak load distribution at 25 m/s ─────────────────────────────────────────
"""
    peak_hub_thrust(r_rotor, elev_angle; v=OPT_V_PEAK, ρ=1.225, CT=OPT_CT_PEAK)

Aerodynamic thrust on the rotor disc at peak wind speed (N).
Conservative CT=1.0 captures the worst case within the BEM envelope
(actual BEM peak CT ≈ 0.55 at λ_opt, but gust/runaway conditions can
push CT toward the Betz upper bound of 8/9; 1.0 is a safe ceiling).
"""
function peak_hub_thrust(
    r_rotor::Float64,
    elev_angle::Float64;
    v::Float64=OPT_V_PEAK,
    ρ::Float64=1.225,
    CT::Float64=OPT_CT_PEAK,
)
    return 0.5 * ρ * v^2 * π * r_rotor^2 * CT * cos(elev_angle)^2
end

"""
    segment_inward_force(design, seg_idx, T_line) → F_inward_per_vertex

Inward radial force per pentagon vertex (N) on the lower ring of segment
seg_idx, due to the line tension T_line flowing through that segment with a
taper angle determined by the radii of its two end rings.

Each ring receives contributions from TWO adjacent segments (one above,
one below); this function returns the contribution of one segment.
"""
function segment_inward_force(
    design::TRPTDesign,
    seg_idx::Int,
    T_line::Float64,
    radii::AbstractVector,
    L_seg::AbstractVector,
)
    r_lo = radii[seg_idx]       # lower ring
    r_hi = radii[seg_idx + 1]     # upper ring
    L = L_seg[seg_idx]
    # Line length along the taper:
    line_len = sqrt(L^2 + (r_hi - r_lo)^2)
    # Inward radial component of tension at lower ring (lines taper inward going up):
    sin_theta = (r_hi - r_lo) / max(line_len, 1e-12)   # + if hi > lo (ring_hi larger, line leans outward going up)
    # We want the inward component on the LOWER ring.  If r_hi > r_lo (unusual,
    # for inverted taper), line leans outward going up → tension pulls lower
    # ring outward (negative inward).  Normal case r_hi < r_lo: line leans
    # inward going up → tension pulls lower ring inward.
    return -T_line * sin_theta   # sign: +inward
end

# ── Design evaluation ────────────────────────────────────────────────────────
"""
    EvalResult

Outcome of evaluating one candidate TRPT design.
"""
struct EvalResult
    feasible::Bool
    mass_total_kg::Float64
    mass_beams_kg::Float64
    mass_knuckles_kg::Float64
    min_fos::Float64
    worst_ring_idx::Int
    fos_per_ring::Vector{Float64}
    N_comp_per_ring::Vector{Float64}
    P_crit_per_ring::Vector{Float64}
    Do_per_ring::Vector{Float64}
    torsion_margin_ok::Bool
    min_torsional_fos::Float64
    constraint_msg::String
    # Centrifugal clamp diagnostics (2026-07-06)
    n_clamped_rings::Int          # count of rings where F_v clamped to 0 (net outward)
    max_outward_N::Float64        # worst net outward force per vertex (N), 0 if none
    # Spoke tie diagnostics (2026-07-06)
    min_spoke_fos::Float64        # minimum spoke FoS (Inf if none or disabled)
    n_spokes_engaged::Int         # count of spokes under tension
    max_spoke_tension_N::Float64  # worst spoke tension (N), 0 if none
    required_MBL_N::Float64        # minimum MBL for FoS_gate (gate × max_T / derating)
    # Outward-load checks (2026-07-06 Phase B)
    min_fos_tension::Float64       # strut tension FoS (Inf if none)
    min_fos_blade_root::Float64    # blade-root bending FoS (Inf if no expansion rotors)
    min_fos_bridle::Float64        # bridle tension FoS (Inf if none)
    max_lateral_line_load_N::Float64  # worst lateral point load on tether from bridle anchor (N)
end

"""
    _evaluate_trpt_design_impl(design, radii, L_seg; kwargs...) → EvalResult

Shared structural analysis for all TRPT evaluate_design methods (v1, v2, v4).
Receives pre-computed geometry arrays (radii, L_seg) from the caller and
performs the full per-ring structural analysis including centripetal
off-loading at the hub ring (blade mass), Euler buckling of polygon
segments, Tulloch/Wacker torsional collapse check, and compressive
stress margin check.

# Keyword Arguments
- `r_rotor`: generating rotor radius (m)
- `elev_angle`: shaft elevation angle (rad)
- `v_peak`: peak wind speed for structural load (m/s)
- `fos_req`: minimum required FoS against buckling
- `omega_rotor`: rotor angular velocity (rad/s)
- `m_blade_total`: total blade mass on hub ring (kg)
- `v_rated`: rated wind speed (m/s)
- `P_rated`: rated power (W)
- `r_eff_override`: optional override radii for torsional collapse (m).
  If provided, used instead of nominal radii for the torsional lever-arm
  calculation — expansion rotors increase effective radius.
- `F_radial_per_ring`: optional per-ring radial expansion force (N).
  If provided, subtracted from the aerodynamic inward force at each ring,
  directly reducing ring compression — force-first modelling.

- `m_expansion_blade_per_ring`: optional per-ring expansion blade mass (kg, total,
  not per-vertex). Added to `m_vertex` at each ring carrying expansion rotors.
  The existing `F_centripetal = m_vertex·ω²·r` machinery handles the force.
  Rings without expansion rotors get zero. Default: nothing (backward compatible).

- `spoke`: optional radial spoke tie parameters (SpokeParams). When enabled, the
  net-outward radial load (currently clamped to F_v=0) is routed through spoke
  tension. Spoke FoS is computed per ring and reported in EvalResult. Default:
  nothing (disabled — current clamp behavior, bit-identical).
"""
function _evaluate_trpt_design_impl(
    design::T,
    radii::Vector{Float64},
    L_seg::Vector{Float64};
    r_rotor::Float64,
    elev_angle::Float64,
    v_peak::Float64,
    fos_req::Float64,
    omega_rotor::Float64,
    m_blade_total::Float64,
    v_rated::Float64,
    P_rated::Float64,
    r_eff_override::Union{Nothing,Vector{Float64}}=nothing,
    F_radial_per_ring::Union{Nothing,Vector{Float64}}=nothing,
    thrust_per_ring::Union{Nothing,Vector{Float64}}=nothing,
    m_expansion_blade_per_ring::Union{Nothing,Vector{Float64}}=nothing,
    spoke::Union{Nothing,KiteTurbineDynamics.SpokeParams}=nothing,
    expansion_blade_geo::Union{Nothing,Vector{NamedTuple{(:ring_idx, :mass, :bank_deg, :chord, :span),Tuple{Int,Float64,Float64,Float64,Float64}}}}=nothing,
    tether_diameter::Float64=0.003,  # for bridle line spec (tether_diameter × 0.8)
) where {T}
    n_rings_tot = length(radii)
    n_seg = length(L_seg)

    # ── Determine loading model ────────────────────────────────────────────
    # Distributed: each ring i contributes thrust_per_ring[i] and its share
    # of the total torque.  Tension builds cumulatively down the shaft.
    # Single-rotor (backward compatible): all thrust at the hub ring.
    use_distributed = thrust_per_ring !== nothing

    # Per-ring thrust (for line tension distribution).  radii is GROUND-FIRST
    # (index 1 = ground, index n_rings_tot = hub), so the single rotor's thrust
    # sits at the LAST index (hub), not the first.
    T_ring = if use_distributed
        thrust_per_ring
    else
        T_single = peak_hub_thrust(r_rotor, elev_angle; v=v_rated, CT=OPT_CT_RATED)
        vcat(zeros(n_rings_tot - 1), T_single)
    end

    T_total_rated = sum(T_ring)

    # Per-ring rated torque contribution
    tau_ring_rated = if use_distributed
        # Each ring's rotor contributes P_i = thrust_i * v (approx).
        # For simplicity: distribute total torque proportionally to thrust.
        tau_total = P_rated / omega_rotor
        [t / T_total_rated * tau_total for t in T_ring]
    else
        tau_total = P_rated / omega_rotor
        vcat(zeros(n_rings_tot - 1), tau_total)
    end

    # ── Torsional stability (per-segment, cumulative torque) ───────────────
    torsion_radii = r_eff_override !== nothing ? r_eff_override : radii
    min_torsional_fos = Inf
    for i in 1:n_seg
        r_min = min(torsion_radii[i], torsion_radii[i + 1])
        L = L_seg[i]
        # Torque from all rings ABOVE this segment (ground-first: indices i+1..end)
        tau_above = sum(tau_ring_rated[(i + 1):end])
        τ_cap = T_total_rated * r_min^2 / sqrt(L^2 + 2 * r_min^2)
        tfos = τ_cap / max(tau_above, 1e-9)
        min_torsional_fos = min(min_torsional_fos, tfos)
    end
    torsional_collapse_ok = (min_torsional_fos >= OPT_TORSION_FOS_REQUIRED)

    # ── Line tension distribution (cumulative thrust) ──────────────────────
    # At ring i, the tension below is sum of thrust from rings 1..i.
    # Peak load scales proportionally.
    T_ring_peak = if use_distributed
        [t * (v_peak / v_rated)^2 for t in T_ring]
    else
        T_pk = peak_hub_thrust(r_rotor, elev_angle; v=v_peak)
        vcat(zeros(n_rings_tot - 1), T_pk)
    end

    # Ground-first cumulative: tension below ring i = sum of thrust above ring i
    # (rings i..end).  reverse(cumsum(reverse(x)))[i] == sum(x[i:end]).
    cumulative_T_rated = reverse(cumsum(reverse(T_ring)))
    cumulative_T_peak  = reverse(cumsum(reverse(T_ring_peak)))
    T_line_axial_rated = T_total_rated / design.n_lines
    T_line_axial_peak  = sum(T_ring_peak) / design.n_lines

    # ── Per-ring structural analysis ─────────────────────────────────────────
    fos_per_ring = Float64[]
    Ncomp_per_ring = Float64[]
    Pcrit_per_ring = Float64[]
    Do_per_ring = Float64[]
    min_fos = Inf
    worst_idx = 0
    torsion_ok = true
    mass_beams = 0.0
    mass_knuckles = 0.0
    n_clamped = 0
    max_outward_N = 0.0
    n_spokes_engaged = 0
    max_spoke_tension_N = 0.0
    min_spoke_fos = Inf
    required_mbl = 0.0
    min_fos_tension = Inf

    m_blade_per_vertex = m_blade_total / design.n_lines

    for (i, r) in enumerate(radii)
        line_len_below =
            i > 1 ? sqrt(L_seg[i - 1]^2 + (radii[i] - radii[i - 1])^2) : L_seg[1]
        line_len_above =
            i < n_rings_tot ? sqrt(L_seg[i]^2 + (radii[i + 1] - radii[i])^2) : L_seg[end]

        # Tension at ring i: cumulative thrust from rings 1..i (above and including this ring)
        # divided by n_lines, scaled by geometric factors.
        T_above_rated = cumulative_T_rated[i] / design.n_lines
        T_above_peak  = cumulative_T_peak[i] / design.n_lines

        T_line =
            max(T_above_peak, T_above_rated) * max(line_len_below, line_len_above) /
            min(L_seg[max(i-1, 1)], L_seg[min(i, n_seg)])

        F_in_per_vertex_aero = OPT_DESIGN_LOAD_FACTOR * T_line

        # Force-first expansion modelling (Rod 2026-06-13):
        # Expansion rotor radial force pushes outward on the ring attachment
        # points, directly reducing net inward force and ring compression.
        F_exp_per_vertex = if F_radial_per_ring !== nothing
            F_radial_per_ring[i] / design.n_lines
        else
            0.0
        end

        n_float = float(design.n_lines)
        L_poly = 2.0 * r * sin(π / n_float)

        # Centripetal off-loading: blade + beam mass at this vertex
        spec = beam_spec_at_ring(design, r)
        tube = if spec.profile == PROFILE_CIRCULAR
            CircularTube(spec.Do, spec.t_over_D)
        elseif spec.profile == PROFILE_ELLIPTICAL
            EllipticalTube(spec.Do, spec.t_over_D, spec.aspect_ratio)
        else
            AirfoilTube(spec.Do, spec.t_over_D, spec.aspect_ratio)
        end
        props = strut_properties(tube, L_poly, PinPinEnds())

        A = props.A
        m_beam_per_vertex = props.mass * L_poly
        m_knuckle = knuckle_mass_at_ring(spec.Do, design.t_over_D, design.n_lines)
        m_vertex =
            m_knuckle +
            m_beam_per_vertex +
            (i == n_rings_tot ? m_blade_per_vertex : 0.0) +
            (m_expansion_blade_per_ring !== nothing ? m_expansion_blade_per_ring[i] / design.n_lines : 0.0)

        F_centripetal = m_vertex * omega_rotor^2 * r
        F_v_total = F_in_per_vertex_aero - F_centripetal - F_exp_per_vertex
        if F_v_total < 0.0
            n_clamped += 1
            outward_N = -F_v_total
            if outward_N > max_outward_N
                max_outward_N = outward_N
            end
            # Spoke tension check (2026-07-06): when net radial force is outward,
            # the spoke carries it. T_spoke = -F_v_total (sign convention: positive
            # = tension in spoke, pulling center node toward ring vertex).
            if spoke !== nothing && spoke.enabled
                T_spoke = outward_N  # per-vertex spoke tension
                n_spokes_engaged += 1
                if T_spoke > max_spoke_tension_N
                    max_spoke_tension_N = T_spoke
                end
                fos_spoke = spoke.SWL_N / T_spoke
                if fos_spoke < min_spoke_fos
                    min_spoke_fos = fos_spoke
                end
                # Strut tension check (2026-07-06 Phase B): when net outward,
                # strut sees tension instead of compression buckling
                T_strut = outward_N / (2.0 * sin(π / n_float))
                sigma_tension = T_strut / A  # A from props (strut cross-section)
                fos_tension = CFRP_SIGMA_YIELD_TENSION_MPA * 1e6 / sigma_tension
                if fos_tension < min_fos_tension
                    min_fos_tension = fos_tension
                end
            end
        end
        F_v = max(F_v_total, 0.0)
        N_comp = F_v / (2.0 * sin(π / n_float))

        P_crit = props.P_crit

        # ── Tension stiffening from ring polygon hoop tension ──────────────
        # Expansion rotors apply F_radial to their ring, creating polygon hoop
        # tension that stiffens beams against Euler buckling — like a guitar
        # string under tension is harder to deflect laterally.
        #   T_ring = F_radial / (2·sin(π/n))    [hoop tension per vertex]
        #   P_crit_eff = P_crit + T_ring         [beam-column approximation]
        if F_exp_per_vertex > 0
            T_ring = F_exp_per_vertex / (2.0 * sin(π / n_float))
            P_crit += T_ring
        end

        is_buckling_ring = (i > 1 && i < n_rings_tot)
        if is_buckling_ring && N_comp > 0
            fos = P_crit / N_comp
            push!(fos_per_ring, fos)
            push!(Ncomp_per_ring, N_comp)
            push!(Pcrit_per_ring, P_crit)
            push!(Do_per_ring, spec.Do)
            if fos < min_fos
                min_fos = fos
                worst_idx = i
            end
        else
            push!(fos_per_ring, Inf)
            push!(Ncomp_per_ring, 0.0)
            push!(Pcrit_per_ring, 0.0)
            push!(Do_per_ring, spec.Do)
        end

        if is_buckling_ring && A < (OPT_TORSION_MARGIN * abs(N_comp) / 5e8)
            torsion_ok = false
        end

        mass_beams += design.n_lines * props.mass * L_poly
        mass_knuckles += design.n_lines * m_knuckle
    end

    mass_total = mass_beams + mass_knuckles

    if n_clamped > 0
        if spoke !== nothing && spoke.enabled
            @warn "Spoke check: $n_clamped ring(s) engaged (max tension $(round(max_spoke_tension_N; digits=0)) N/vertex, min FoS $(round(min_spoke_fos; digits=2))). $n_spokes_engaged spokes active."
            # required_MBL = FoS_gate × max_spoke_tension / (splice × creep)
            # derating chain: MBL → splice 0.90 → creep/fatigue 0.50 → SWL
            FOS_GATE = 1.0
            required_mbl = FOS_GATE * max_spoke_tension_N / (0.90 * 0.50)
        else
            @warn "Centrifugal clamp: $n_clamped ring(s) with net outward load (max $(round(max_outward_N; digits=0)) N/vertex). FoS on these rings reads ∞; outward load path (tension/bending/knuckles) is unverified. See DECISIONS.md §2026-07-06."
        end
    end

    # ── Bridle tension + blade-root bending (2026-07-06) ─────────────────
    # Expansion blades are bridled, not cantilevered. Outer bridle at 0.49·span
    # outboard, inner at 0.21·span inboard, both anchored at ~30% down the
    # line segment below (Rod 2026-07-06). Bridle line: tether_diameter × 0.8.
    # Conservative lumped-mass: bridle carries 100% of normal centrifugal force
    # on its span portion (assumes zero cuff reaction — overestimates tension).
    min_fos_bridle_val = Inf
    max_lateral = 0.0
    if expansion_blade_geo !== nothing
        for geo in expansion_blade_geo
            mass, bank, span = geo.mass, geo.bank_deg, geo.span
            r_root = radii[geo.ring_idx]
            # Outboard portion: 70% of mass, CG at r_root + 0.35·span
            m_out = 0.7 * mass
            r_cg_out = r_root + 0.35 * span
            F_cf_out = m_out * r_cg_out * omega_rotor^2
            T_outer = F_cf_out * abs(sind(bank))  # normal component → bridle tension

            # Inboard portion: 30% of mass, CG at r_root - 0.15·span
            m_in = 0.3 * mass
            r_cg_in = r_root - 0.15 * span
            F_cf_in = m_in * max(r_cg_in, 0.01) * omega_rotor^2
            T_inner = F_cf_in * abs(sind(bank))

            # Bridle line SWL: Dyneema, tether_diameter × 0.8
            # MBL scales with d²; use spoke derating chain
            d_bridle = tether_diameter * 0.8
            # Rough MBL: ~2 kN/mm² for Dyneema → MBL ≈ π·(d/2)² × 2e9 × 0.5
            # Simpler: scale from 7mm spoke: MBL ∝ d²
            mbl_bridle = (d_bridle / 0.007)^2 * 44_000.0
            swl_bridle = mbl_bridle * 0.90 * 0.50  # same derating chain

            fos_outer = swl_bridle / max(T_outer, 0.01)
            fos_inner = swl_bridle / max(T_inner, 0.01)
            fos_bridle = min(fos_outer, fos_inner)
            if fos_bridle < min_fos_bridle_val
                min_fos_bridle_val = fos_bridle
            end

            # Lateral line load at bridle anchor (vector sum of tensions)
            lat = sqrt(T_outer^2 + T_inner^2)
            if lat > max_lateral; max_lateral = lat; end
        end
    end
    min_fos_bridle = min_fos_bridle_val
    max_lateral_line_load_N = max_lateral

    # Blade-root bending: short cantilever from cuff to bridle points
    # Reduced ~10× vs unbridled — defer full beam-on-supports model
    min_fos_blade_root = Inf

    feasible =
        (min_fos >= fos_req) &&
        torsion_ok &&
        (design.t_over_D >= OPT_T_OVER_D_MIN) &&
        (design.t_over_D <= OPT_T_OVER_D_MAX) &&
        torsional_collapse_ok
    msg = if feasible
        "OK"
    else
        (
        if !torsion_ok
            "compressive stress > 500 MPa limit"
        elseif min_fos < fos_req
            "FOS $(round(min_fos, digits=2)) < $fos_req at ring $worst_idx"
        elseif !torsional_collapse_ok
            "Torsional collapse FOS $(round(min_torsional_fos, digits=2)) < $OPT_TORSION_FOS_REQUIRED"
        else
            "t/D out of manufacturable bounds"
        end
    )
    end

    return EvalResult(
        feasible,
        mass_total,
        mass_beams,
        mass_knuckles,
        min_fos,
        worst_idx,
        fos_per_ring,
        Ncomp_per_ring,
        Pcrit_per_ring,
        Do_per_ring,
        torsion_ok,
        min_torsional_fos,
        msg,
        n_clamped,
        max_outward_N,
        min_spoke_fos,
        n_spokes_engaged,
        max_spoke_tension_N,
        required_mbl,
        min_fos_tension,
        min_fos_blade_root,
        min_fos_bridle,
        max_lateral_line_load_N,
    )
end
"""
    evaluate_design(design, r_rotor, elev_angle; v_peak, fos_req) → EvalResult

Static structural analysis of a TRPT design candidate under peak 25 m/s
wind load.  Performs:

1. Rotor thrust calc → line tension (per of n_lines lines).
2. For each ring, sum inward force from the segments above and below.
3. Polygon segment compression N_comp from inward force (standard n-gon equilibrium).
4. Per-segment Euler buckling capacity P_crit = π²·E·I_min / L_poly².
5. FOS = P_crit / N_comp for each ring.  Design is feasible iff min FOS ≥ fos_req.
6. Torsional rigidity check: A(cross-section) ≥ OPT_TORSION_MARGIN × A_buckling_limit.
7. Total mass = Σ beam_mass + n_vertices × knuckle_mass.

All evaluate_design methods (TRPTDesign, TRPTDesignV2, TRPTDesignV4)
delegate to the shared `_evaluate_trpt_design_impl` so cross-campaign
comparability is guaranteed — a v2 design evaluated through v1's path
uses the same physics as v4's path.
"""
function evaluate_design(
    design::TRPTDesign;
    r_rotor::Float64=5.0,
    elev_angle::Float64=π/6,
    v_peak::Float64=OPT_V_PEAK,
    fos_req::Float64=OPT_FOS_REQUIRED,
    omega_rotor::Float64=4.1 * OPT_V_PEAK / 5.0,
    m_blade_total::Float64=11.0,
    v_rated::Float64=11.0,
    P_rated::Float64=10000.0,
)
    if design.Do_top <= 0 ||
        design.t_over_D <= 0 ||
        design.n_rings < 3 ||
        design.taper_ratio <= 0 ||
        design.r_hub <= 0
        return EvalResult(
            false,
            Inf,
            Inf,
            0.0,
            0.0,
            0,
            Float64[],
            Float64[],
            Float64[],
            Float64[],
            false,
            0.0,
            "invalid geometry",
            0, 0.0, Inf, 0, 0.0, 0.0, Inf, Inf, 0.0, 0.0,
        )
    end

    radii = ring_radii(design)
    L_seg = segment_axial_lengths(design)

    return _evaluate_trpt_design_impl(
        design,
        radii,
        L_seg;
        r_rotor=r_rotor,
        elev_angle=elev_angle,
        v_peak=v_peak,
        fos_req=fos_req,
        omega_rotor=omega_rotor,
        m_blade_total=m_blade_total,
        v_rated=v_rated,
        P_rated=P_rated,
    )
end

# ── Baseline extraction from existing SystemParams ────────────────────────────
"""
    baseline_design(p::SystemParams) → TRPTDesign

Construct the baseline TRPT design matching the current `SystemParams`:
CFRP hollow circular tube, Do=0.01396×√R scaling (exponent=0.5), uniform
axial spacing, taper consistent with current rL ratio.
"""
function baseline_design(p::SystemParams)::TRPTDesign
    r_hub = p.trpt_hub_radius
    r_bot_guess = 0.48 * r_hub   # DRR: 2.0 → 0.96 for 10 kW; ratio ≈ 0.48
    taper_ratio = r_bot_guess / r_hub
    n_rings = p.n_rings
    tether_len = p.tether_length
    # Baseline Do_top = DO_SCALE × √r_hub (matches structural_safety.jl scaling)
    Do_top = 0.01396 * sqrt(r_hub)
    return TRPTDesign(
        PROFILE_CIRCULAR,
        Do_top,
        0.05,                  # baseline t/D
        1.0,                   # aspect_ratio unused for circular
        0.5,                   # Do_scale_exp: sqrt scaling
        r_hub,
        taper_ratio,
        n_rings,
        tether_len,
        p.n_lines,
        OPT_KNUCKLE_MASS_KG,
    )
end

# ── Search-space bounds ──────────────────────────────────────────────────────
"""
    search_bounds(p::SystemParams, profile::BeamProfile) → (lo, hi)

Vector-form bounds for the optimizer, for a fixed beam profile:
  x = [Do_top, t_over_D, aspect_ratio, Do_scale_exp, r_hub, taper_ratio, n_rings_float]
"""
function search_bounds(p::SystemParams, profile::BeamProfile)
    # Scale bounds by system size (square-root of rotor radius) so 50 kW and
    # 10 kW share the same bounds function.
    sc = sqrt(p.trpt_hub_radius / 2.0)          # =1 at 10 kW, ≈2.24 at 50 kW
    Do_lo = 0.005 * sc;
    Do_hi = 0.120 * sc     # 5–120 mm at 10 kW

    # r_hub is tightly constrained — it must match the rotor-hub mounting
    # geometry (blade root attachment).  Allow ±10% from baseline to let the
    # optimizer probe small-radius advantages without breaking rotor assembly.
    r_hub_lo = 0.90 * p.trpt_hub_radius
    r_hub_hi = 1.10 * p.trpt_hub_radius

    # taper_ratio lower bound enforced by ground-anchor footprint; a
    # realistic minimum is r_bot ≥ 0.6 m regardless of hub radius.  Upper
    # limit 1.0 = no taper (cylindrical TRPT).
    taper_lo = max(0.20, 0.6 / p.trpt_hub_radius)
    taper_hi = 1.0

    # n_rings — torsional stability floor (empirical): need enough rings to
    # keep per-segment twist below buckling of the rope helix.  Baseline has
    # 14 rings for 30 m; use min 7 (one every ~4 m) and max 40.
    n_rings_lo = 7.0
    n_rings_hi = 40.0

    if profile == PROFILE_ELLIPTICAL
        ar_lo = 0.25;
        ar_hi = 1.0          # minor/major
    elseif profile == PROFILE_AIRFOIL
        ar_lo = 0.08;
        ar_hi = 0.20         # NACA 0008 to 0020
    else
        ar_lo = 1.0;
        ar_hi = 1.0           # ignored (fixed at 1.0 for circular)
    end
    # [Do_top, t_over_D, aspect_ratio, Do_scale_exp, r_hub, taper_ratio, n_rings]
    lo = [Do_lo, OPT_T_OVER_D_MIN, ar_lo, 0.0, r_hub_lo, taper_lo, n_rings_lo]
    hi = [Do_hi, OPT_T_OVER_D_MAX, ar_hi, 1.0, r_hub_hi, taper_hi, n_rings_hi]
    return lo, hi
end

"""
    design_from_vector(x, profile, p) → TRPTDesign

Map a flat parameter vector (as emitted by the optimizer) into a TRPTDesign.
"""
function design_from_vector(x::AbstractVector, profile::BeamProfile, p::SystemParams)
    n_rings = max(3, Int(round(x[7])))
    return TRPTDesign(
        profile,
        x[1],                        # Do_top
        x[2],                        # t_over_D
        x[3],                        # aspect_ratio
        x[4],                        # Do_scale_exp
        x[5],                        # r_hub
        clamp(x[6], 0.05, 1.0),      # taper_ratio
        n_rings,
        p.tether_length,
        p.n_lines,
        OPT_KNUCKLE_MASS_KG,
    )
end

"""
    objective(x, profile, p) → mass (or +∞ if infeasible)

Scalar cost function for the optimizer.
"""
function objective(
    x::AbstractVector,
    profile::BeamProfile,
    p::SystemParams;
    rotor_radius::Float64=5.0,
    elev_angle::Float64=π/6,
)
    design = design_from_vector(x, profile, p)
    r_rotor = rotor_radius                        # passed from caller for scaling
    result = evaluate_design(design; r_rotor=r_rotor, elev_angle=elev_angle)
    return result.feasible ? result.mass_total_kg : 1e6 + result.mass_total_kg
end
