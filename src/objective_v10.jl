# src/objective_v10.jl
#
# V10: Unified rotor architecture — all rotors are expansion rotors.
# Hub rotor special case removed.  Rotor placement via 60-pattern bitmask
# over top 10 rings with ≥2 bare rings between active rotors.
# Blade scale and bank angle are gradients (top→bottom).
# Per-rotor BEM sizing with power-law wind shear.
# Eight constraint gates (3 new: tether FoS, overtwist, slack).
#
# Reference: docs/plans/2026-06-20-v10-full-dynamic-constraints.md
#
# Design vector (14 DoF), beam profile: elliptical only (circular via aspect=1.0)
#   x[1]   Do_top           [m]    beam OD at hub  (min 0.05)
#   x[2]   t_over_D         [-]    wall thickness ratio
#   x[3]   beam_aspect      [-]    elliptical b/a (1.0 = circular)
#   x[4]   Do_scale_exp     [-]    Do(r) = Do_top*(r/r_hub)^exp
#   x[5]   r_hub            [m]    hub ring radius
#   x[6]   r_bottom         [m]    ground ring radius  (min 0.5)
#   x[7]   target_Lr        [-]    common L/r target
#   x[8]   n_lines          [int]  polygon sides (3-16)
#   x[9]   density_profile  [-]    ring density bias (-0.8..0.8)
#   x[10]  rotor_mask       [int]  proxy -> 60 valid bitmasks
#   x[11]  bank_top         [deg]  bank at ring 1 (0-25)
#   x[12]  bank_bottom      [deg]  bank at lowest rotor (0-25)
#   x[13]  blade_scale_top    [-]    blade linear scale at ring 1 (0.005-2.0); area ∝ λ²
#   x[14]  blade_scale_bottom [-]    blade linear scale at lowest rotor (0.005-2.0)

const TRPT_V10_DIM = 14

# ══════════════════════════════════════════════════════════════════════════════
# Valid rotor masks — top 10 rings, ≥2 bare rings between active rotors
# ══════════════════════════════════════════════════════════════════════════════

function _generate_valid_rotor_masks(n_pos::Int=10, min_gap::Int=2)
    masks = UInt16[]
    for m in 0:((1 << n_pos) - 1)
        # Require a rotor at position 1 (hub, highest wind).
        # The hub rotor is the primary power source; designs without one
        # waste DE search time on configurations that are never optimal.
        (m & 1) == 0 && continue
        valid = true
        prev_one = -min_gap - 1
        for i in 0:(n_pos - 1)
            if (m >> i) & 1 == 1
                if i - prev_one <= min_gap
                    valid = false
                    break
                end
                prev_one = i
            end
        end
        if valid
            push!(masks, UInt16(m))
        end
    end
    return sort(masks)
end

const VALID_ROTOR_MASKS = _generate_valid_rotor_masks(10, 2)
const N_VALID_MASKS = length(VALID_ROTOR_MASKS)  # 60

"""
    decode_rotor_mask(x_proxy::Float64) -> (mask::UInt16, n_active::Int, positions::Vector{Int})

Decode a continuous proxy variable x ∈ [0, 60) to a valid rotor bitmask.
Returns the mask, the number of active rotors, and their ring indices (1-based from hub).
"""
function decode_rotor_mask(x_proxy::Float64)
    idx = clamp(round(Int, x_proxy), 0, N_VALID_MASKS - 1)
    mask = VALID_ROTOR_MASKS[idx + 1]
    positions = Int[]
    for i in 0:9
        if (mask >> i) & 1 == 1
            push!(positions, i + 1)  # 1-based ring index from hub
        end
    end
    return mask, length(positions), positions
end

# ══════════════════════════════════════════════════════════════════════════════
# Wind shear model
# ══════════════════════════════════════════════════════════════════════════════

"""
    wind_speed_at_ring(ring_z, hub_altitude, v_ref, h_ref, shear_exp=0.14)

Power-law wind shear: v(z) = v_ref × (z / h_ref)^α
"""
function wind_speed_at_ring(
    ring_z::Float64, hub_altitude::Float64, v_ref::Float64=11.0,
    h_ref::Float64=50.0, shear_exp::Float64=0.14,
)::Float64
    z = max(ring_z, 1.0)
    return v_ref * (z / h_ref)^shear_exp
end

# ══════════════════════════════════════════════════════════════════════════════
# Design vector → TRPTDesign + Rotor array
# ══════════════════════════════════════════════════════════════════════════════

"""
    RotorSpecV10

Per-ring rotor specification for V10 unified architecture.
"""
struct RotorSpecV10
    ring_idx::Int         # which TRPT ring (1-based from hub)
    bank_angle_deg::Float64
    blade_scale::Float64
    v_wind::Float64       # local wind speed at this ring (m/s)
    r_rotor::Float64      # BEM rotor radius for this rotor (m)
    blade_tip_radius::Float64
    blade_hub_radius::Float64
    blade_chord::Float64
end

"""
    design_from_vector_v10(x, beam_profile, p; max_ground_radius, power_W, v_rated)

Decode a V10 design vector into a TRPTDesignV4 and an array of RotorSpecV10.
"""
function design_from_vector_v10(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    cylinder_cone::Bool=false,   # 2026-08-25: three-section geometry (opt-in, ODE path)
    simple_rotors::Bool=false,   # 2026-08-25: x10 = {1,2,3} concurrent top rotors (replaces bitmask)
    cone_slope_deg::Float64=22.0,   # swept: TRPT transition-cone slope (Jensen/Tulloch 22° reference)
    rotor_spacing_frac::Float64=0.8,   # swept: min rotor spacing = frac · 2·r_rotor (0.8 reference)
    power_split::Union{Nothing,Float64}=nothing,   # top-rotor power fraction; nothing = equal P/n
    blocking_factor::Float64=1.0,   # downstream-rotor inflow de-rating (1.0 = no wake/blocking)
)
    # Base v5 design (first 9 vars)
    design = design_from_vector_v5(
        x[1:9], beam_profile, p; max_ground_radius=max_ground_radius
    )

    # Rotor placement (x[10] = rotor_mask proxy)
    if simple_rotors
        # 1/2/3 concurrent top rotors (2026-08-25): re-interpret x10 as a count.
        # The bitmask decode stays untouched for the legacy/static path.
        n_rotors = clamp(round(Int, x[10]), 1, 3)
        mask = UInt16(0)
        positions_raw = collect(1:n_rotors)   # positions 1..n_rotors from the hub
    else
        mask, _, positions_raw = decode_rotor_mask(x[10])
    end

    # Cylinder+cone (2026-08-25, OPT-IN): a small-radius transmission cylinder
    # [0, taper_start_z] below a steep cone [taper_start_z, tether_length] (the
    # Tulloch-proposed geometry).  The cone length is the 22°-bounded slope
    # (Tulloch: "avoid any abrupt changes in diameter"), so taper_start_z is
    # fixed by the radius step, not the rotor position.  Off by default (frozen
    # legacy static solver keeps the full cone).
    taper_start_z = 0.0
    harvest_length = 0.0
    if cylinder_cone && design.r_hub > design.r_bottom
        # Harvest cylinder (top, r_top): enough ring intervals for n_rotors
        # concurrent rotors at the SAME radius, spaced by the ring spacing
        # (target_Lr·r_top).  The min-rotor-spacing (frac·2·r_rotor) is a CHECK
        # below, not the harvest length.
        if simple_rotors
            n_rotors = clamp(round(Int, x[10]), 1, 3)
            harvest_length = (n_rotors - 1) * design.target_Lr * design.r_hub
        end
        cone_length = (design.r_hub - design.r_bottom) / tan(deg2rad(cone_slope_deg))
        taper_start_z = clamp(
            design.tether_length - harvest_length - cone_length, 0.0,
            max(design.tether_length - harvest_length, 0.0)
        )
    end

    # Ring geometry (full cone when taper_start_z == 0 and harvest_length == 0).
    zs, _, _ = ring_spacing_v5(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr,
        taper_start_z, harvest_length;
        density_profile=design.density_profile,
    )
    n_rings = length(zs)

    # Map rotor mask positions to ring indices (intermediate ring numbering).
    # ring_spacing_v5 returns n_rings intermediate ring positions.
    # The system builder adds ground (ring 1) and hub (ring n_rings+2) later;
    # rotor ring indices here use intermediate numbering [1, n_rings]
    # and are remapped to system numbering in build_from_campaign_v10.
    # Mask position 1 = hub ring → intermediate ring n_rings.
    # Convert: mask position p → ring index = n_rings - p + 1
    positions = Int[]
    for p in positions_raw
        ring_idx = n_rings - p + 1
        if ring_idx >= 1 && ring_idx <= n_rings
            push!(positions, ring_idx)
        end
    end
    n_active = length(positions)

    # Bank angle gradient (x[11]=bank_top, x[12]=bank_bottom)
    bank_top = clamp(x[11], 0.0, 25.0)
    bank_bottom = clamp(x[12], 0.0, 25.0)

    # Blade scale gradient (x[13]=blade_scale_top, x[14]=blade_scale_bottom).
    # 2026-08-20 rename: these genes are a BLADE LINEAR SCALE (area ∝ λ²),
    # not a tip-speed ratio — λ is reserved for TSR throughout the codebase.
    blade_scale_top = clamp(x[13], 0.1, 2.0)
    blade_scale_bottom = clamp(x[14], 0.1, 2.0)

    # Hub altitude from shaft geometry (rings already computed above)
    hub_altitude = design.tether_length * sind(30.0)  # nominal 30° elevation

    # Power per rotor (2026-08-25): power_split gives the TOP rotor its fraction,
    # the rest share (1 − power_split).  The 14-D genome carries NO power_split
    # gene — the value is a sweep knob (ObjectiveConfig.power_split) threaded
    # through the `power_split` kwarg.  If unset (nothing), simple_rotors falls
    # back to equal P/n (legacy); the x[15] probe is retained defensively.
    if power_split === nothing
        power_split = (simple_rotors && length(x) >= 15) ? clamp(x[15], 0.2, 0.8) : 1.0 / max(n_active, 1)
    else
        power_split = clamp(power_split, 0.0, 1.0)
    end

    # Min rotor spacing check (2026-08-25): the concurrent top rotors sit on
    # adjacent rings (spacing target_Lr·r_hub); reject if that is tighter than
    # rotor_spacing_frac · 2·r_rotor.
    spacing_ok = true
    if simple_rotors && n_active > 1
        ring_spacing = design.target_Lr * design.r_hub
        r_rotor_ref = BEM.rotor_radius_for_power(power_W / n_active, v_rated, design.n_lines)
        spacing_ok = ring_spacing >= rotor_spacing_frac * 2 * r_rotor_ref
    end

    # Build rotor specs
    rotors = RotorSpecV10[]
    for (i, pos) in enumerate(positions)
        if pos > n_rings || pos < 1
            continue
        end

        # Gradient interpolation
        t = n_active > 1 ? (i - 1) / (n_active - 1) : 0.0
        bank_i = bank_top + t * (bank_bottom - bank_top)
        blade_scale_i = blade_scale_top + t * (blade_scale_bottom - blade_scale_top)

        # Wind speed at this ring's altitude; downstream rotors see de-rated
        # inflow (blocking_factor — a named placeholder, not CFD).
        ring_z = zs[pos]  # pos is now ring index (ground→hub)
        ring_altitude = max(ring_z * sind(30.0), 1.0)
        v_i = wind_speed_at_ring(ring_altitude, hub_altitude, v_rated)
        i > 1 && (v_i *= blocking_factor)

        # BEM rotor radius for this rotor at its power share + local wind speed
        P_i = (i == 1) ? power_split * power_W : (1.0 - power_split) * power_W / max(n_active - 1, 1)
        r_rotor_i = BEM.rotor_radius_for_power(P_i, v_i, design.n_lines)

        # Ring-anchored 70/30 blade split (2026-08-20, Rod): the blade attaches
        # to the TRPT ring at 70% outboard / 30% inboard of its span, so
        # blade_tip = +0.7·span (OUTBOARD offset) and blade_hub = −0.3·span
        # (INBOARD offset, negative).  The swept annulus is r_out = r_ring +
        # 0.7·span, r_in = r_ring − 0.3·span, A = π(r_out² − r_in²).
        # NOTE (2026-08-21): the identity A = 2π·r_ring·span holds ONLY for a
        # 50/50 split (ring at the annulus midpoint) — for 70/30 it understates
        # the area (Daisy: π(2.22²−1.22²) = 10.81 m² vs 2π·1.52·1.0 = 9.55 m²),
        # so the annulus formula π(r_out² − r_in²) is the only correct one.
        # Span magnitude preserved from the 0.25-hub era (0.75·r_rotor·λ) so the
        # blade size scale is unchanged; the convention is now consistent with
        # the expansion rotors (expansion_rotor.jl: expansion_annulus_area).
        span = 0.75 * r_rotor_i * blade_scale_i
        blade_tip = 0.7 * span
        blade_hub = -0.3 * span
        blade_chord = 0.113 * r_rotor_i * blade_scale_i

        push!(rotors, RotorSpecV10(
            pos, bank_i, blade_scale_i, v_i, r_rotor_i, blade_tip, blade_hub, blade_chord,
        ))
    end

    return (design=design, rotors=rotors, n_rings=n_rings, zs=zs, mask=mask, n_active=n_active,
            taper_start_z=taper_start_z, harvest_length=harvest_length, spacing_ok=spacing_ok)
end

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds
# ══════════════════════════════════════════════════════════════════════════════

function search_bounds_v10(
    p::SystemParams,
    beam_profile::BeamProfile;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    base_lo, base_hi = search_bounds_v5(
        p, beam_profile; max_ground_radius=max_ground_radius
    )

    # Tighten inherited v5 bounds for V10
    base_lo[1] = max(base_lo[1], 0.05)      # Do_top min: 0.05 m (was 0.01)
    base_lo[6] = max(base_lo[6], 0.5)        # r_bottom min: 0.5 m (was ~0.1)
    base_hi[8] = min(base_hi[8], 16.0)       # n_lines max: 16 (was 24)

    # V10 additional vars: rotor_mask, bank_top, bank_bottom, blade_scale_top, blade_scale_bottom
    v10_lo = [0.0, 0.0, 0.0, 0.1, 0.1]     # mask proxy, banks, lambdas (λ floor 0.1 per Rod 2026-07-24)
    v10_hi = [Float64(N_VALID_MASKS), 25.0, 25.0, 2.0, 2.0]

    return vcat(base_lo, v10_lo), vcat(base_hi, v10_hi)
end

# ══════════════════════════════════════════════════════════════════════════════
# V10 objective — 8 constraint gates
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v10(x, beam_profile, p; power_W, v_rated, ...)

Scalar cost function for the V10 DE optimiser.  Returns total airborne mass (kg)
if all 8 constraint gates pass, or a penalty if any gate fails.
"""
function objective_v10(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π / 6,
    v_peak::Float64=OPT_V_PEAK,
    fos_req::Float64=OPT_FOS_REQUIRED,
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    # ── Decode design ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x, beam_profile, p; max_ground_radius=max_ground_radius, power_W=power_W, v_rated=v_rated
    )
    design = result.design
    rotors = result.rotors
    n_rings = result.n_rings
    zs = result.zs
    n_active = result.n_active

    n_lines = design.n_lines
    P_per_rotor = n_active > 0 ? power_W / n_active : power_W

    # ── Gate 1: At least one active rotor ─────────────────────────────────
    if n_active == 0
        return 1_000_000.0  # no rotors = no power
    end

    # ── Ring geometry ────────────────────────────────────────────────────
    radii_in = copy(zs)
    for i in 1:n_rings
        radii_in[i] = design.r_hub - (design.r_hub - design.r_bottom) * (zs[i] / design.tether_length)
    end
    # Actually use ring_spacing_v4 for correct radii
    _, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    n_rings_tot = length(radii)
    L_seg = diff(zs)
    rho = p.rho
    elev_deg = rad2deg(elev_angle)

    # ── Build expansion rotor params for structural evaluation ────────────
    # Each active rotor becomes an ExpansionRotorParams for the existing evaluator
    hub_altitude = design.tether_length * sin(elev_angle)
    expansion_params = ExpansionRotorParams[]

    for rotor in rotors
        ri = rotor.ring_idx
        if ri > n_rings_tot || ri < 1
            continue
        end
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, 0.0, ri, 1.0,  # mass computed later
        )
        push!(expansion_params, er)
    end

    # ── Size reference rotor for equilibrium solve ──────────────────────
    # Use the first (top) rotor's wind speed as reference
    v_ref_rotor = isempty(rotors) ? v_rated : rotors[1].v_wind
    r_ref = BEM.rotor_radius_for_power(P_per_rotor, v_ref_rotor, n_lines)

    # ── Effective k_mppt scaled by blade area ──────────────────────────
    # k_mppt ∝ rotor swept area ∝ blade_scale².  A blade_scale=0.5 rotor has ¼
    # the swept area of blade_scale=1.0 and should expect ¼ the power.  Without
    # this scaling, the DE converges to blade_scale→0 to save blade mass
    # (∝ blade_scale³) while the equilibrium solver compensates with higher ω
    # — but the rotor lacks startup torque to reach that ω in the ODE.
    # Scaling k_mppt with blade_scale² inside the equilibrium solve aligns the
    # static objective with the dynamic reality.  (2026-08-20: renamed λ →
    # blade_scale; λ is reserved for tip-speed ratio.)
    λ_eff = rotors[1].blade_scale
    k_mppt_eff = p.k_mppt * λ_eff^2
    ctrl_scaled = ControlSpec(p.i_pto, k_mppt_eff, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
    p_scaled = override_params(p; k_mppt=k_mppt_eff)

    # ── Equilibrium solve ────────────────────────────────────────────────
    ω_eq, r_hub_rotor = solve_equilibrium_self_consistent(
        design, expansion_params, p_scaled, n_lines, radii, zs;
        P_per_rotor=P_per_rotor, v_wind=v_rated, elev_rad=elev_angle,
    )

    # ── Gate 7: Power balance — equilibrium must exist ────────────────────
    if ω_eq === nothing
        m_base = sum(er -> er.mass, expansion_params; init=0.0)
        return max(m_base, 1.0) + 1_000_000.0
    end

    # ── Gate 7 (continued): P_gen hard lower bound ─────────────────────────
    P_gen_eq = k_mppt_eff * ω_eq^3
    if P_gen_eq < 0.8 * power_W   # severely underpowered → infeasible
        m_base = sum(er -> er.mass, expansion_params; init=0.0)
        return max(m_base, 1.0) * min(power_W / max(P_gen_eq, 1.0), 100.0) + 1_000_000.0
    end

    # ── Per-ring thrust (hub-equivalent: ring 1 rotor thrust) ─────────────
    thrust_per_ring = zeros(Float64, n_rings_tot)
    # All rotors contribute thrust at their ring
    # For simplicity, use the reference rotor thrust at ring 1
    thrust_per_ring[1] = peak_hub_thrust(
        r_ref, elev_angle; v=v_rated, CT=KiteTurbineDynamics.OPT_CT_RATED
    )

    # ── Per-ring expansion forces ────────────────────────────────────────
    r_eff = copy(radii)
    F_radial_per_ring = zeros(Float64, n_rings_tot)
    tau_net_per_ring = zeros(Float64, n_rings_tot)
    cumulative_thrust = cumsum(thrust_per_ring)

    for er in expansion_params
        ri = er.ring_idx
        if ri > n_rings_tot || ri < 1
            continue
        end
        r_nom = radii[ri]
        T_above = ri > 1 ? cumulative_thrust[ri - 1] / n_lines : 0.0

        F_radial, F_axial, tau_net, r_new, _ = expansion_rotor_forces(
            er, rho, v_rated, ω_eq, elev_deg, r_nom, T_above, n_lines
        )

        r_eff[ri] = r_new
        F_radial_per_ring[ri] = F_radial
        tau_net_per_ring[ri] = tau_net
        thrust_per_ring[ri] += F_axial
    end

    cumulative_thrust = cumsum(thrust_per_ring)

    # ── Structural evaluation ────────────────────────────────────────────
    eval_result = evaluate_design(
        design;
        r_rotor=r_ref,
        elev_angle=elev_angle,
        v_peak=v_peak,
        fos_req=fos_req,
        omega_rotor=ω_eq,
        v_rated=v_rated,
        P_rated=power_W,
        max_ground_radius=max_ground_radius,
        r_eff_override=r_eff,
        F_radial_per_ring=F_radial_per_ring,
        thrust_per_ring=thrust_per_ring,
    )

    # ── Gate 2: Beam buckling FoS ────────────────────────────────────────
    # ── Gate 3: Torsional FoS ────────────────────────────────────────────
    if !eval_result.feasible
        fos_penalty = max(1.0, fos_req / max(eval_result.min_fos, 0.01))
        torsion_penalty = max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01))
        penalty_mult = min(fos_penalty * torsion_penalty, 10.0)
        return eval_result.mass_total_kg * penalty_mult + 1_000_000.0
    end

    # ── Gate 4: Tether tension FoS ───────────────────────────────────────
    T_per_line = cumulative_thrust[end] / n_lines
    tether_fos = TETHER_SWL / max(T_per_line, 1.0)
    if tether_fos < fos_req
        return eval_result.mass_total_kg * min(fos_req / max(tether_fos, 0.01), 10.0) + 1_000_000.0
    end

    # ── Gate 5: Torsional overtwist (Tulloch limit) ──────────────────────
    # Cumulative twist from each ring to ground
    # Simplified: max inter-ring twist from tau_net
    max_twist_abs = 0.0
    for ri in 2:n_rings_tot
        twist_ri = abs(tau_net_per_ring[ri]) * L_seg[ri-1] / (1e3 * radii[ri]^2)  # simplified GJ
        max_twist_abs = max(max_twist_abs, twist_ri)
    end
    if max_twist_abs >= 0.95π
        return eval_result.mass_total_kg * 10.0 + 1_000_000.0
    end

    # ── Gate 6: Slack guard ──────────────────────────────────────────────
    if any(thrust_per_ring .< 0.0)
        return eval_result.mass_total_kg * 5.0 + 1_000_000.0
    end

    # ── Gate 6b: Tension distribution — every segment must carry load ────
    # cumulative_thrust[ri] is the force above ring ri that the tethers
    # must bear.  A non-positive value means that segment has gone slack —
    # the TRPT cannot transmit torque from expansion rotors down to the
    # generator at the ground ring.
    min_tether_tension = minimum(cumulative_thrust) / n_lines
    if min_tether_tension <= 0.0
        return eval_result.mass_total_kg * max(10.0, abs(min_tether_tension) / 100.0 + 1.0) + 1_000_000.0
    end

    # ── Gate 8: Parasitic drag check (embedded in equilibrium solve) ─────
    # Already verified: ω_eq exists → power balance holds

    # ── Feasible: compute total mass ─────────────────────────────────────
    # Expansion rotor mass — span³ blade-mass law (2026-08-22): each
    # assembly = n_lines · M_BLADE_REF_KG · (decoded span)³, pricing the
    # blade volume (was the CFRP (0.3+0.1·tip)·λ³ sum, then λ³ — both wrong;
    # kept in sync with builders_util).
    m_expansion = 0.0
    for rotor in rotors
        span_r = rotor.blade_tip_radius - rotor.blade_hub_radius
        m_expansion += design.n_lines * M_BLADE_REF_KG * span_r^3
    end

    # Tether mass
    m_tether = design.n_lines * design.tether_length * (970.0 * π * (p.tether_diameter / 2)^2)

    total_mass = eval_result.mass_total_kg + m_expansion + m_tether

    # ── Power accuracy penalty ─────────────────────────────────────────
    power_ratio = P_gen_eq / power_W
    power_penalty = 1.0 + 2.0 * abs(power_ratio - 1.0)

    # ── Rotor usefulness penalty ───────────────────────────────────────
    # A rotor with λ→0 or bank→90° produces no useful work.  Penalize designs
    # where ALL rotors have negligible useful blade area (λ·cos(bank) < threshold).
    # This prevents the optimizer from using rotors as pure spreaders at zero thrust.
    if n_active > 0
        min_useful = minimum(r -> r.blade_scale * cosd(r.bank_angle_deg), rotors)
        if min_useful < 0.015
            power_penalty *= 2.0  # heavy penalty: rotors are decorative
        end
    end

    return total_mass * power_penalty
end
