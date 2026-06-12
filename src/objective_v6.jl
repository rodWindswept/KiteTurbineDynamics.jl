# src/objective_v6.jl
#
# V6: Expansion-rotor-augmented TRPT optimisation.
#
# Extends v5 (BEM-coupled rotor radius) with expansion rotor design variables
# and an effective-radius model that captures the structural benefit of
# aerodynamic ring spreading.
#
# Design vector (13 DoF):
#   x[1]   Do_top           [m]    beam outer diameter at hub
#   x[2]   t_over_D         [-]    wall thickness ratio
#   x[3]   beam_aspect      [-]    elliptical b/a or airfoil t/c
#   x[4]   Do_scale_exp     [-]    Do(r) = Do_top · (r/r_hub)^exp
#   x[5]   r_hub            [m]    hub ring radius
#   x[6]   r_bottom         [m]    ground ring radius
#   x[7]   target_Lr        [-]    common L/r target
#   x[8]   knuckle_mass_kg  [kg]   per-vertex point mass
#   x[9]   n_lines          [int]  polygon sides (3-8)
#   x[10]  n_expansion      [int]  number of expansion rotors (0-6)
#   x[11]  bridle_angle_deg [deg]  expansion rotor bridle angle (5-30)
#   x[12]  blade_radius     [m]    expansion blade tip radius (0.3-2.5)
#   x[13]  blade_chord      [m]    expansion blade chord (0.02-0.15)
#
# Key physics: expansion rotors increase effective ring radius →
# lower tether tension → smaller beam diameters → less airborne mass.
# The DE optimiser discovers whether this feedback loop justifies the
# added mass of the expansion rotor assemblies.

const TRPT_V6_DIM = 13

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

    # Expansion rotor bounds (vars 10-13)
    exp_lo = [0.0, 5.0, 0.3, 0.02]
    exp_hi = [6.0, 30.0, 2.5, 0.15]

    return vcat(base_lo, exp_lo), vcat(base_hi, exp_hi)
end

# ══════════════════════════════════════════════════════════════════════════════
# Design vector → TRPTDesign + ExpansionStack
# ══════════════════════════════════════════════════════════════════════════════

function design_from_vector_v6(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    # Base v5 design (first 9 vars)
    design = design_from_vector_v5(
        x[1:9], beam_profile, p; max_ground_radius=max_ground_radius
    )

    # Expansion rotor parameters (vars 10-13)
    n_exp = round(Int, clamp(x[10], 0, 6))
    bridle_deg = clamp(x[11], 5.0, 30.0)
    blade_r = clamp(x[12], 0.3, 2.5)
    blade_c = clamp(x[13], 0.02, 0.15)

    # Build expansion stack config
    cfg = if n_exp > 0
        ExpansionStackConfig(;
            placement=:clustered,   # clustered near hub — most effective
            n_rings=20,           # will be adjusted by ring_spacing_v4
            n_expansion=n_exp,
            blade_radius=blade_r,
            hub_radius=0.15,
            blade_chord=blade_c,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bridle_angle_deg=bridle_deg,
            mass_per_rotor=0.3 + 0.1 * blade_r,  # mass scales with blade size
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

Estimate effective ring radii from expansion rotor spreading at the
design operating point.  Uses a simplified force balance — no ODE needed.

Returns a vector of effective radii (same length as ring count).

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
    zs, radii, n_rings = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr
    )
    r_eff = copy(radii)

    if isempty(stack)
        return r_eff
    end

    n_lines = design.n_lines
    rho = p.rho

    # Estimate tether tension from rotor thrust at design point
    r_rotor_use = r_rotor > 0.0 ? r_rotor : design.r_hub
    lambda_t = omega * r_rotor_use / max(v_wind, 0.1)
    thrust =
        0.5 * rho * v_wind^2 * π * r_rotor_use^2 * ct_at_tsr(lambda_t) * cosd(elev_deg)^2.0
    T_per_line = thrust / n_lines

    # Geometry factor for polygonal ring
    geom_factor = 2.0 * tan(π / n_lines)

    for er in stack
        ri = er.ring_idx
        if ri > length(r_eff) || ri < 1
            continue
        end
        r_nom = radii[ri]

        # Estimate L_seg from adjacent segments
        if ri < n_rings
            L_seg = zs[ri + 1] - zs[ri]
        else
            L_seg = zs[ri] - zs[ri - 1]
        end

        # Call the force model (v_wind varies with altitude — use hub wind as proxy)
        F_radial, _, _, r_new, _ = expansion_rotor_forces(
            er, rho, v_wind, omega, elev_deg, r_nom, T_per_line, n_lines
        )

        r_eff[ri] = r_new
    end

    return r_eff
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

    # Rotor sizing (BEM-coupled): must come before effective-radii estimate
    # so the correct operating point drives the tether-tension proxy.
    r_rotor = BEM.rotor_radius_for_power(power_W, v_rated, design.n_lines)
    omega = 4.1 * v_rated / r_rotor  # optimal TSR ≈ 4.1

    # Compute effective radii from expansion rotor aerodynamic spreading.
    # Larger r_eff → larger torsional capacity → lower structural mass.
    r_eff = estimate_effective_radii(
        design,
        stack,
        p;
        v_wind=v_rated,
        elev_deg=rad2deg(elev_angle),
        omega=omega,
        r_rotor=r_rotor,
    )

    eval_result = evaluate_design(
        design;
        r_rotor=r_rotor,
        elev_angle=elev_angle,
        v_peak=v_peak,
        fos_req=fos_req,
        omega_rotor=omega,
        v_rated=v_rated,
        P_rated=power_W,
        max_ground_radius=max_ground_radius,
        r_eff_override=r_eff,
    )

    if !eval_result.feasible
        # Soft penalty: scales with constraint violation so the optimiser
        # can follow the gradient toward feasibility.
        # Designs with FoS=1.7 (just below 1.8) are penalised far less
        # than designs with FoS=0.01.
        fos_penalty = max(1.0, fos_req / max(eval_result.min_fos, 0.01))
        torsion_penalty = max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01))
        penalty_mult = fos_penalty * torsion_penalty
        return eval_result.mass_total_kg * penalty_mult
    end

    # Add expansion rotor mass
    m_expansion = sum(er -> er.mass, stack; init=0.0)

    # Add tether mass
    m_tether =
        design.n_lines * design.tether_length * (970.0 * π * (p.tether_diameter / 2)^2)

    total_mass = eval_result.mass_total_kg + m_expansion + m_tether

    return total_mass
end
