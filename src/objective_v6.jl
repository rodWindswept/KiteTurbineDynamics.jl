# src/objective_v6.jl
#
# V6.2: Expansion-rotor-augmented TRPT optimisation with widened bounds.
#
# Extends v6 (tension stiffening + variable-density ring spacing) with
# widened search bounds to unblock the constraint ceiling.
# Expansion blades use the SAME span and chord as the generating rotor —
# identical blade mould, banked downward toward the next ring.
#
# Design vector (12 DoF):
#   x[1]   Do_top           [m]    beam outer diameter at hub
#   x[2]   t_over_D         [-]    wall thickness ratio
#   x[3]   beam_aspect      [-]    elliptical b/a or airfoil t/c
#   x[4]   Do_scale_exp     [-]    Do(r) = Do_top · (r/r_hub)^exp
#   x[5]   r_hub            [m]    hub ring radius
#   x[6]   r_bottom         [m]    ground ring radius
#   x[7]   target_Lr        [-]    common L/r target
#   x[8]   knuckle_mass_kg  [kg]   per-vertex point mass
#   x[9]   n_lines          [int]  polygon sides (3-8)
#   x[10]  density_profile  [-]    ring density bias (-0.8..0.8, 0=uniform)
#   x[11]  n_expansion      [int]  number of expansion rotors (0-6)
#   x[12]  bank_angle_deg   [deg]  blade bank angle toward next ring (5-45)
#
# Blade span, chord, and count are inherited from the generating rotor:
#   blade_span  = BEM rotor radius  (same blade mould)
#   blade_chord = 0.113 × rotor_radius  (solidity-calibrated)
#   n_blades    = p.n_blades
#
# Reference: PLAN.md Phase 2.4 — v6 DE campaign

const TRPT_V6_DIM = 12

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds
# ══════════════════════════════════════════════════════════════════════════════

function search_bounds_v6(
    p::SystemParams,
    beam_profile::BeamProfile;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    # Base v5 bounds (returns (lo, hi) vectors)
    base_lo, base_hi = search_bounds_v5(
        p, beam_profile; max_ground_radius=max_ground_radius
    )

    # Expansion rotor bounds (vars 11-12): n_expansion, bank_angle_deg
    exp_lo = [0.0, 5.0]
    exp_hi = [6.0, 45.0]

    return vcat(base_lo, exp_lo), vcat(base_hi, exp_hi)
end

# ══════════════════════════════════════════════════════════════════════════════
# Design vector → TRPTDesign + ExpansionStack
# ══════════════════════════════════════════════════════════════════════════════

"""
    design_from_vector_v6(x, beam_profile, p; max_ground_radius, power_W, v_rated)

Decode a v6 design vector into a TRPTDesignV4 and expansion rotor stack.
Blade geometry (span, chord, count) is derived from the generating rotor.
"""
function design_from_vector_v6(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
    power_W::Float64=10000.0,
    v_rated::Float64=11.0,
)
    # Base v5 design (first 10 vars, now includes density_profile)
    design = design_from_vector_v5(
        x[1:10], beam_profile, p; max_ground_radius=max_ground_radius
    )

    # Expansion rotor parameters (vars 11-12)
    n_exp = round(Int, clamp(x[11], 0, 6))
    bank_deg = clamp(x[12], 5.0, 45.0)

    # Derive blade geometry from BEM rotor radius (network model: each
    # rotor is sized for P/n_rotors, so the blade tip matches the rotor).
    # Compute actual ring count for stack placement.
    zs, _, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    n_rings_actual = length(zs)

    # BEM rotor radius for this power level (will be refined in objective_v6
    # with network power sharing, but this gives a reasonable blade size).
    r_rotor_est = BEM.rotor_radius_for_power(power_W, v_rated, design.n_lines)
    blade_tip_radius = r_rotor_est
    blade_hub_radius = 0.25 * r_rotor_est
    blade_chord_est = 0.113 * r_rotor_est

    # Build expansion stack config
    cfg = if n_exp > 0
        ExpansionStackConfig(;
            placement=:clustered,
            n_rings=n_rings_actual,
            n_expansion=n_exp,
            n_blades=p.n_blades,
            blade_tip_radius=blade_tip_radius,
            blade_hub_radius=blade_hub_radius,
            blade_chord=blade_chord_est,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bank_angle_deg=bank_deg,
            mass_per_rotor=0.3 + 0.1 * blade_tip_radius,
            shaft_coupling=1.0,
        )
    else
        nothing
    end

    stack = cfg !== nothing ? build_expansion_stack(cfg) : ExpansionRotorParams[]

    return (design=design, stack=stack, cfg=cfg)
end

# ══════════════════════════════════════════════════════════════════════════════
# Effective radius estimate (steady-state, no ODE)
# ══════════════════════════════════════════════════════════════════════════════

"""
    estimate_effective_radii(design, stack, p; v_wind, omega, elev_deg, r_rotor)
        -> (r_eff, F_radial_per_ring)

Estimate effective ring radii and per-ring radial expansion forces at the
design operating point.  Uses a simplified force balance — no ODE needed.

Returns:
- `r_eff`: vector of effective radii (same length as ring count), used for
  torsional collapse lever-arm calculation.
- `F_radial_per_ring`: vector of radial spreading forces per ring (N).  Zero
  for rings without expansion rotors.  Injected into the structural solver
  as a load term that directly reduces ring compression — force-first
  modelling per Rod (2026-06-13).

`r_rotor` is the generating rotor radius used for thrust estimation.
When zero (default) falls back to `design.r_hub` as a proxy.
"""
function estimate_effective_radii(
    design::TRPTDesignV4,
    stack::Vector{ExpansionRotorParams},
    p::SystemParams;
    v_wind::Float64=11.0,
    omega::Float64=9.5,
    elev_deg::Float64=20.0,
    r_rotor::Float64=0.0,
)
    zs, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    r_eff = copy(radii)
    F_radial_per_ring = zeros(Float64, length(radii))
    tau_net_per_ring = zeros(Float64, length(radii))
    F_axial_per_ring = zeros(Float64, length(radii))

    if isempty(stack)
        return (r_eff, F_radial_per_ring, tau_net_per_ring, F_axial_per_ring)
    end

    n_lines = design.n_lines
    rho = p.rho

    # Estimate tether tension from rotor thrust at design point
    r_rotor_use = r_rotor > 0.0 ? r_rotor : design.r_hub
    lambda_t = omega * r_rotor_use / max(v_wind, 0.1)
    thrust = 0.5 * rho * v_wind^2 * π * r_rotor_use^2 * ct_at_tsr(lambda_t) * cosd(elev_deg)^2.0
    T_per_line = thrust / n_lines

    for er in stack
        ri = er.ring_idx
        if ri > length(r_eff) || ri < 1
            continue
        end
        r_nom = radii[ri]

        # Estimate L_seg from adjacent segments
        if ri < length(radii)
            L_seg = zs[ri + 1] - zs[ri]
        else
            L_seg = zs[ri] - zs[ri - 1]
        end

        F_radial, F_axial, tau_net, r_new, _ = expansion_rotor_forces(
            er, rho, v_wind, omega, elev_deg, r_nom, T_per_line, n_lines
        )

        r_eff[ri] = r_new
        F_radial_per_ring[ri] = F_radial
        tau_net_per_ring[ri] = tau_net
        F_axial_per_ring[ri] = F_axial
    end

    return (r_eff, F_radial_per_ring, tau_net_per_ring, F_axial_per_ring)
end

# ══════════════════════════════════════════════════════════════════════════════
# v6 objective
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v6(x, beam_profile, p; power_W, v_rated, ...)

Scalar cost function for the v6 expansion-rotor DE optimiser.

Returns total airborne mass (kg) if feasible, or a high penalty if
constraints are violated.
"""
function objective_v6(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=10000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π/6,
    v_peak::Float64=OPT_V_PEAK,
    fos_req::Float64=OPT_FOS_REQUIRED,
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    result = design_from_vector_v6(x, beam_profile, p; max_ground_radius=max_ground_radius)
    design = result.design
    stack = result.stack

    # ── Network rotor sizing: each rotor contributes equally ──────────────
    # In AWE, smaller wings have better power-to-weight ratios.  The network
    # of N rotors (1 hub + n_expansion) shares the total power equally.
    # Each ring's BEM rotor is sized for P_per_rotor, not the full budget.
    n_rotors_total = 1 + length(stack)   # hub + expansion rotors
    P_per_rotor = power_W / n_rotors_total

    # Size hub rotor for its share of the power
    r_hub_rotor = BEM.rotor_radius_for_power(P_per_rotor, v_rated, design.n_lines)
    omega = 4.1 * v_rated / r_hub_rotor

    # Build ring geometry
    zs, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    n_rings_tot = length(radii)
    L_seg = diff(zs)
    n_lines = design.n_lines

    # ── Per-ring thrust from hub rotor ────────────────────────────────────
    thrust_per_ring = zeros(Float64, n_rings_tot)
    thrust_per_ring[1] = peak_hub_thrust(
        r_hub_rotor, elev_angle; v=v_rated, CT=KiteTurbineDynamics.OPT_CT_RATED
    )

    # ── Per-ring expansion forces (direct computation with correct tension) ──
    r_eff = copy(radii)
    F_radial_per_ring = zeros(Float64, n_rings_tot)
    tau_net_per_ring = zeros(Float64, n_rings_tot)
    rho = p.rho
    cumulative_thrust = cumsum(thrust_per_ring)

    for er in stack
        ri = er.ring_idx
        if ri > n_rings_tot || ri < 1
            continue
        end
        r_nom = radii[ri]
        # Tension at this ring: cumulative thrust from rings ABOVE (1..ri-1)
        T_above = ri > 1 ? cumulative_thrust[ri - 1] / n_lines : 0.0

        F_radial, F_axial, tau_net, r_new, _ = expansion_rotor_forces(
            er, rho, v_rated, omega, rad2deg(elev_angle),
            r_nom, T_above, n_lines
        )

        r_eff[ri] = r_new
        F_radial_per_ring[ri] = F_radial
        tau_net_per_ring[ri] = tau_net
        thrust_per_ring[ri] += F_axial   # add expansion thrust to ring's load
    end

    # Recompute cumulative thrust after adding expansion contributions
    cumulative_thrust = cumsum(thrust_per_ring)

    # Evaluate structural design with distributed loading
    eval_result = evaluate_design(
        design;
        r_rotor=r_hub_rotor,
        elev_angle=elev_angle,
        v_peak=v_peak,
        fos_req=fos_req,
        omega_rotor=omega,
        v_rated=v_rated,
        P_rated=power_W,
        max_ground_radius=max_ground_radius,
        r_eff_override=r_eff,
        F_radial_per_ring=F_radial_per_ring,
        thrust_per_ring=thrust_per_ring,
    )

    if !eval_result.feasible
        fos_penalty = max(1.0, fos_req / max(eval_result.min_fos, 0.01))
        torsion_penalty = max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01))
        # Clamp penalty to 10× so infeasible designs retain a cost gradient
        # rather than flattening the search space (all candidates → 1e9).
        penalty_mult = min(fos_penalty * torsion_penalty, 10.0)
        # +1e6 absolute barrier: feasible designs weigh 24–3,000 kg;
        # infeasible penalties are now 1,000,100–1,000,300 kg, so ANY feasible
        # design beats ANY infeasible design regardless of mass.
        return eval_result.mass_total_kg * penalty_mult + 1_000_000.0
    end

    # Add expansion rotor mass
    m_expansion = sum(er -> er.mass, stack; init=0.0)

    # Add tether mass
    m_tether =
        design.n_lines * design.tether_length * (970.0 * π * (p.tether_diameter / 2)^2)

    total_mass = eval_result.mass_total_kg + m_expansion + m_tether

    return total_mass
end
