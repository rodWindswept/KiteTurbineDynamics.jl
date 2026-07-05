# src/objective_v6.jl
#
# V6.2: Expansion-rotor-augmented TRPT optimisation with widened bounds.
#
# Extends v6 (tension stiffening + variable-density ring spacing) with
# widened search bounds to unblock the constraint ceiling.
# Expansion blades use the SAME span and chord as the generating rotor —
# identical blade mould, banked downward toward the next ring.
#
# Blade span, chord, and count are inherited from the generating rotor:
#   blade_span  = BEM rotor radius  (same blade mould)
#   blade_chord = 0.113 × rotor_radius  (solidity-calibrated)
#   n_blades    = p.n_blades
#
# Reference: PLAN.md Phase 2.4 — v6 DE campaign

const TRPT_V6_DIM = 12

# ══════════════════════════════════════════════════════════════════════════════
# Design vector (12 DoF):
#   x[1]   Do_top           [m]    beam outer diameter at hub
#   x[2]   t_over_D         [-]    wall thickness ratio
#   x[3]   beam_aspect      [-]    elliptical b/a or airfoil t/c
#   x[4]   Do_scale_exp     [-]    Do(r) = Do_top · (r/r_hub)^exp
#   x[5]   r_hub            [m]    hub ring radius
#   x[6]   r_bottom         [m]    ground ring radius
#   x[7]   target_Lr        [-]    common L/r target
#   x[8]   n_lines          [int]  polygon sides (3-12)
#   x[9]   density_profile  [-]    ring density bias (-0.8..0.8, 0=uniform)
#   x[10]  n_expansion      [int]  number of expansion rotors (0-12)
#   x[11]  bank_angle_deg   [deg]  blade bank angle toward next ring (5-25)
#   x[12]  blade_scale      [-]    expansion blade span/chord scale (0.02-2.0)

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

    # Expansion rotor bounds (vars 10-12): n_expansion, bank_angle_deg, blade_scale
    exp_lo = [0.0, 5.0, 0.005]   # λ lowered to 0.005
    exp_hi = [20.0, 25.0, 2.0]   # n_exp widened to 20; bank safety cap 25° (pitch depower clearance)

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
    # Base v5 design (first 9 vars, knuckle mass now derived from beam geometry)
    design = design_from_vector_v5(
        x[1:9], beam_profile, p; max_ground_radius=max_ground_radius
    )

    # Expansion rotor parameters (vars 10-12)
    n_exp = round(Int, clamp(x[10], 0, 20))
    bank_deg = clamp(x[11], 5.0, 25.0)     # safety cap at 25° (pitch depower blade-tip clearance)
    blade_scale = clamp(x[12], 0.005, 2.0) # λ: span/chord/mass, widened to 0.005

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
    # 70/30 blade split: 70% outboard, 30% inboard of ring attachment
    blade_span = r_rotor_est * blade_scale
    blade_tip_radius = 0.7 * blade_span     # +70% outboard from ring
    blade_hub_radius = -0.3 * blade_span    # -30% inboard from ring (neg = inboard)
    blade_chord_est = 0.113 * r_rotor_est * blade_scale

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
            CL_blade=EXP_CL_DESIGN,
            CD0_blade=EXP_CD0_DESIGN,
            k_induced=EXP_K_INDUCED,
            bank_angle_deg=bank_deg,
            mass_per_rotor=(0.3 + 0.1 * blade_tip_radius) * blade_scale^3,
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
# Parasitic drag model
# ══════════════════════════════════════════════════════════════════════════════

"""
    parasitic_drag_power(design, stack, p; omega, n_lines, radii, zs,
                         v_wind, elev_rad)
        -> (P_beam, P_tether, P_exp_blades, P_total)

Compute total parasitic aerodynamic drag power (W) at the design operating
point — the power that must be supplied by the rotors just to overcome
structural drag.  This power is dissipated as heat and is NOT available for
useful work (radial spreading, thrust).

# Components

- **P_beam**: ring beam drag.  Each intermediate ring has `n_lines` beam
  segments of outer dimension `Do(rr)`, chord length `L_beam = 2·rr·sin(π/n)`,
  tangential velocity `v_t = ω·rr`.  Cylindrical crossflow drag model with
  `Cd = TUBE_DRAG_CD` (1.2).  Hub ring (carries rotor) and ground ring (fixed)
  are excluded.

- **P_tether**: tether line drag.  Each inter-ring tether segment (diameter
  `d_tether`, length L_seg) at midpoint radius r_mid.  Cylindrical crossflow
  drag with `Cd = TETHER_DRAG_CD` (1.0).

- **P_exp_blades**: expansion blade profile drag.  Parasitic torque from the
  zero-lift and induced drag of each expansion blade annulus at its mean
  aerodynamic radius.

# Physics note

The ring beam drag is computed with a scalar midpoint approximation (velocity
at ring radius × beam area).  The full 3D treatment in `dynamics.jl` resolves
perpendicular velocity components and sums over beam segments per ring.  For
the optimisation loop (which evaluates ~10⁵ designs per minute), the scalar
approximation is adequate — it captures the dominant `(ω·r)³` scaling and
provides the correct ordering of designs.
"""
function parasitic_drag_power(
    design::TRPTDesignV4,
    stack::Vector{ExpansionRotorParams},
    p::SystemParams;
    omega::Float64,
    n_lines::Int,
    radii::Vector{Float64},
    zs::Vector{Float64},
    v_wind::Float64=11.0,
    elev_rad::Float64=π / 6,
)
    rho = p.rho
    d_tether = p.tether_diameter  # 3 mm Dyneema
    n_rings_tot = length(radii)
    v_axial = v_wind * cos(elev_rad)
    nu = 1.5e-5  # kinematic viscosity of air (m²/s)

    # ═══════════════════════════════════════════════════════════════════
    # 1. Ring beam drag power
    #
    # PHYSICS (2026-06-19): Ring beams are polygon CHORDS, not radial
    # spokes.  At the beam midpoint, tangential velocity v_t = ω·r is
    # exactly PARALLEL to the beam axis — flow sweeps lengthwise along
    # the beam, not across it.  The correct drag model has two components:
    #
    #   a) Skin friction from tangential flow (along beam):
    #      P_skin = n·½ρ·(wetted_perim·L)·Cf·v_t³
    #      Cf ≈ 0.027/Re^(1/7)  (turbulent boundary layer, 1/7th power law)
    #      Wetted perimeter ≈ π·Do·1.2 (elliptical section, AR≈1.26)
    #
    #   b) Crossflow pressure drag from axial wind (across beam):
    #      P_axial = n·½ρ·Cd_ellipse·Do·L·v_axial³
    #      Cd_ellipse ≈ 0.2–0.3 (streamlined elliptical section in crossflow)
    #
    # Both are negligible for current designs (<0.5 kW combined vs 50 kW
    # rated).  The old model (Cd=1.2 cylinder crossflow using Do×L with
    # v_t³) overestimated beam drag by ~1,450×.
    # ═══════════════════════════════════════════════════════════════════
    P_beam_total = 0.0
    for ri in 2:(n_rings_tot - 1)  # skip hub (ri=1) and ground (ri=end)
        rr = radii[ri]
        spec = beam_spec_at_ring(design, rr)
        Do = spec.Do
        L_beam = 2.0 * rr * sin(π / n_lines)
        v_t = omega * rr

        # Skin friction (tangential flow along beam)
        wetted_perim = π * Do * 1.2           # elliptical perimeter approx
        surface_area = wetted_perim * L_beam
        Re = v_t * L_beam / nu
        Cf = 0.027 / Re^(Float64(1) / 7)     # turbulent skin friction
        q = 0.5 * rho * v_t^2
        F_skin = q * surface_area * Cf
        P_skin = F_skin * v_t                # power = force × velocity

        # Axial crossflow (wind hits beam broadside)
        CD_AXIAL_CROSSFLOW = 0.3             # elliptical section in crossflow
        P_axial = 0.5 * rho * CD_AXIAL_CROSSFLOW * Do * L_beam * v_axial^3

        P_beam_total += n_lines * (P_skin + P_axial)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 2. Tether line drag power
    #
    # Tethers run approximately along the shaft axis, so tangential flow
    # IS crossflow — the cylinder-in-crossflow model applies.  Corrected
    # by TETHER_CURVATURE_FACTOR to account for tether curvature toward
    # the flow direction.
    #
    # Tallak Tveide's TetherDragODESolver (2023) gives
    # drag_coefficient_multiplier ≈ 0.25 for non-TRPT configurations.
    # TRPT tethers carry higher centrifugal loads → straighter → higher
    # factor.  Using 0.5 as a conservative TRPT estimate pending ODE
    # validation at TRPT operating conditions.
    # ═══════════════════════════════════════════════════════════════════
    tether_curvature_factor = 0.5  # TRPT estimate (non-TRPT: 0.25)

    P_tether_total = 0.0
    L_segs = diff(zs)
    for si in eachindex(L_segs)
        r_a = radii[si]
        r_b = radii[si + 1]
        r_mid = (r_a + r_b) / 2.0
        v_t_mid = omega * r_mid
        L_seg = L_segs[si]
        # Raw crossflow power: ½ρ·Cd·d·L·v³
        P_seg_raw = 0.5 * rho * TETHER_DRAG_CD * d_tether * L_seg * v_t_mid^3
        P_tether_total += n_lines * P_seg_raw * tether_curvature_factor
    end

    # ═══════════════════════════════════════════════════════════════════
    # 3. Expansion blade profile drag power
    #
    # Airfoil profile + induced drag, resolved to tangential direction.
    # Uses calibrated coefficients (EXP_CL_DESIGN, EXP_CD0_DESIGN,
    # EXP_K_INDUCED) from NACA 4412 data (Abbott & von Doenhoff 1959).
    # ═══════════════════════════════════════════════════════════════════
    P_exp_blade_total = 0.0
    for er in stack
        ri = er.ring_idx
        if ri > n_rings_tot || ri < 1
            continue
        end
        r_nom = radii[ri]
        bank_rad = deg2rad(er.bank_angle_deg)
        r_mean_annulus = (er.blade_hub_radius + er.blade_tip_radius) / 2.0
        r_mean = r_nom + r_mean_annulus * cos(bank_rad)
        blade_span = max(er.blade_tip_radius - er.blade_hub_radius, 0.0)

        v_app = sqrt(v_axial^2 + (omega * r_mean)^2)
        q = 0.5 * rho * v_app^2

        # Profile + induced drag: D_blade = q·chord·span·(CD0 + k·CL²)
        D_blade =
            q * er.blade_chord * blade_span *
            (er.CD0_blade + er.k_induced * er.CL_blade^2)
        phi = atan(v_axial, omega * r_mean)
        D_tangential = D_blade * cos(phi)

        tau_drag_exp = er.n_blades * D_tangential * r_mean
        P_exp_blade_total += tau_drag_exp * omega
    end

    P_total = P_beam_total + P_tether_total + P_exp_blade_total
    return (P_beam_total, P_tether_total, P_exp_blade_total, P_total)
end

# ══════════════════════════════════════════════════════════════════════════════
# Dynamic equilibrium ω solver
# ══════════════════════════════════════════════════════════════════════════════

"""
    solve_equilibrium_omega(design, stack, p, n_lines, radii, zs, r_hub_rotor;
        P_rated, v_wind, elev_rad, n_scan)

Find the stable equilibrium rotational speed ω_eq where the net shaft power
balance is zero:

    P_aero_total(ω) − P_parasitic(ω) − P_gen(ω) = 0

Returns ω_eq (rad/s) or `nothing` if no equilibrium exists (air brake at
all ω).  Selects the HIGHEST crossing — the stable attractor where a design
accelerates up from below and decelerates down from above.

# Algorithm

1. Coarse scan at `n_scan` logarithmically-spaced points from ω_min to ω_max
2. At each ω, compute P_net = P_aero_total(ω) − P_par(ω) − k_mppt·ω³
3. Find intervals where P_net changes sign (crossings exist)
4. Bisection refinement in each interval to 1% tolerance
5. Return the highest ω where P_net ≥ 0, or nothing if P_net < 0 everywhere

# Expansion rotor power at off-design ω

The expansion rotor lift torque τ_net(ω) is computed via the same
`expansion_rotor_forces()` function called at each scan ω.  This gives
self-consistent power contributions at any operating speed, not just
the design TSR=4.1 point.
"""
function solve_equilibrium_omega(
    design::TRPTDesignV4,
    stack::Vector{ExpansionRotorParams},
    p::SystemParams,
    n_lines::Int,
    radii::Vector{Float64},
    zs::Vector{Float64},
    r_hub_rotor::Float64;
    P_rated::Float64=50000.0,
    v_wind::Float64=11.0,
    elev_rad::Float64=π / 6,
    n_scan::Int=30,
)
    rho = p.rho
    k_mppt = p.k_mppt
    elev_deg = rad2deg(elev_rad)

    # Scan range: ω_min = 1 rpm, ω_max = 300 rpm
    ω_min = 1.0 * 2π / 60
    ω_max = 300.0 * 2π / 60

    # Logarithmic spacing — finer at low ω where crossings are more likely
    ω_scan = exp.(range(log(ω_min), log(ω_max); length=n_scan))
    P_net = zeros(n_scan)

    # Pre-compute thrust for expansion rotor force evaluation
    thrust_per_ring = zeros(Float64, length(radii))
    thrust_per_ring[1] = peak_hub_thrust(
        r_hub_rotor, elev_rad; v=v_wind, CT=KiteTurbineDynamics.OPT_CT_RATED
    )
    cumulative_thrust = cumsum(thrust_per_ring)

    for (j, ω) in enumerate(ω_scan)
        # Hub rotor aero power
        λ = clamp(ω * r_hub_rotor / v_wind, 0.0, 12.0)
        cp = BEM.cp_bem(n_lines, λ)
        P_aero_hub = 0.5 * rho * v_wind^3 * π * r_hub_rotor^2 * cp

        # Expansion rotor net power (with NaN guard for extreme ω)
        P_exp_net = 0.0
        for er in stack
            ri = er.ring_idx
            if ri > length(radii) || ri < 1
                continue
            end
            r_nom = radii[ri]
            # Guard: skip if geometry is degenerate
            if r_nom <= 0.0 || !isfinite(r_nom)
                continue
            end
            T_above = ri > 1 ? cumulative_thrust[ri - 1] / n_lines : 0.0
            try
                _, _, tau_net, _, _ = expansion_rotor_forces(
                    er, rho, v_wind, ω, elev_deg, r_nom, T_above, n_lines
                )
                if isfinite(tau_net)
                    P_exp_net += tau_net * ω
                end
            catch
                # Degenerate operating point (extreme ω, zero radius, etc.)
                continue
            end
        end

        P_aero_total = P_aero_hub + P_exp_net

        # Parasitic drag
        _, _, _, P_par = parasitic_drag_power(
            design, stack, p;
            omega=ω, n_lines=n_lines, radii=radii, zs=zs,
            v_wind=v_wind, elev_rad=elev_rad,
        )

        # Generator load (MPPT: P_gen = k_mppt × ω³)
        P_gen = k_mppt * ω^3

        P_net[j] = P_aero_total - P_par - P_gen
    end

    # Find the highest ω where P_net ≥ 0 (stable equilibrium)
    # P_net > 0 → system accelerates; P_net < 0 → decelerates.
    # The highest ω with P_net ≥ 0 is the stable attractor.
    best_idx = 0
    for j in 1:n_scan
        if P_net[j] >= 0.0
            best_idx = j
        end
    end

    if best_idx == 0 || best_idx == n_scan
        return nothing  # never positive, or positive at max ω (runaway)
    end

    # Bisection refinement between best_idx (P_net ≥ 0) and next point (P_net < 0)
    ω_lo = ω_scan[best_idx]
    ω_hi = ω_scan[best_idx + 1]
    for _ in 1:20
        ω_mid = (ω_lo + ω_hi) / 2.0
        λ = clamp(ω_mid * r_hub_rotor / v_wind, 0.0, 12.0)
        cp = BEM.cp_bem(n_lines, λ)
        P_aero_hub = 0.5 * rho * v_wind^3 * π * r_hub_rotor^2 * cp

        P_exp_net = 0.0
        for er in stack
            ri = er.ring_idx
            if ri > length(radii) || ri < 1
                continue
            end
            r_nom = radii[ri]
            if r_nom <= 0.0 || !isfinite(r_nom)
                continue
            end
            T_above = ri > 1 ? cumulative_thrust[ri - 1] / n_lines : 0.0
            try
                _, _, tau_net, _, _ = expansion_rotor_forces(
                    er, rho, v_wind, ω_mid, elev_deg, r_nom, T_above, n_lines
                )
                if isfinite(tau_net)
                    P_exp_net += tau_net * ω_mid
                end
            catch
                continue
            end
        end

        _, _, _, P_par = parasitic_drag_power(
            design, stack, p;
            omega=ω_mid, n_lines=n_lines, radii=radii, zs=zs,
            v_wind=v_wind, elev_rad=elev_rad,
        )

        P_net_mid = P_aero_hub + P_exp_net - P_par - k_mppt * ω_mid^3

        if P_net_mid >= 0.0
            ω_lo = ω_mid
        else
            ω_hi = ω_mid
        end
    end

    return (ω_lo + ω_hi) / 2.0
end

# ══════════════════════════════════════════════════════════════════════════════
# Self-consistent equilibrium: iterate rotor sizing + equilibrium ω
# ══════════════════════════════════════════════════════════════════════════════

"""
    solve_equilibrium_self_consistent(design, stack, p, n_lines, radii, zs;
        P_per_rotor, v_wind, elev_rad, max_iter)

Find the self-consistent equilibrium where the hub rotor is sized for the
actual operating ω, not the assumed TSR=4.1.

Iterates:
1. Start with rotor sized for TSR=4.1 (BEM.rotor_radius_for_power)
2. Find ω_eq via solve_equilibrium_omega()
3. Re-size rotor so it produces P_per_rotor at ω_eq
4. Repeat until ω_eq converges (Δω/ω < 1%)

Returns (ω_eq, r_hub_rotor) or (nothing, NaN) if no equilibrium.
"""
function solve_equilibrium_self_consistent(
    design::TRPTDesignV4,
    stack::Vector{ExpansionRotorParams},
    p::SystemParams,
    n_lines::Int,
    radii::Vector{Float64},
    zs::Vector{Float64};
    P_per_rotor::Float64=50000.0,
    v_wind::Float64=11.0,
    elev_rad::Float64=π / 6,
    max_iter::Int=8,
)
    rho = p.rho

    # Initial rotor size from static BEM (TSR=4.1)
    r_hub_rotor = BEM.rotor_radius_for_power(P_per_rotor, v_wind, n_lines)
    omega = 4.1 * v_wind / r_hub_rotor

    for iter in 1:max_iter
        # Find equilibrium ω with current rotor size
        omega_new = solve_equilibrium_omega(
            design, stack, p, n_lines, radii, zs, r_hub_rotor;
            P_rated=P_per_rotor * (1 + length(stack)),  # total system power
            v_wind=v_wind, elev_rad=elev_rad,
        )

        if omega_new === nothing
            return (nothing, NaN)  # air brake
        end

        # Re-size rotor for this ω: find R s.t. ½ρv³πR²·Cp(ωR/v) = P_per_rotor
        lambda_target = omega_new * r_hub_rotor / v_wind
        cp_target = BEM.cp_bem(n_lines, lambda_target)

        if cp_target <= 0.0
            # Can't produce power at this TSR — rotor would be infinite
            return (nothing, NaN)
        end

        R_new = sqrt(P_per_rotor / (0.5 * rho * v_wind^3 * π * cp_target))

        # Check convergence
        if abs(omega_new - omega) / max(omega, 0.01) < 0.01 &&
           abs(R_new - r_hub_rotor) / max(r_hub_rotor, 0.01) < 0.01
            return (omega_new, R_new)
        end

        omega = omega_new
        r_hub_rotor = R_new
    end

    return (omega, r_hub_rotor)
end

# ══════════════════════════════════════════════════════════════════════════════
# v6 objective
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v6(x, beam_profile, p; power_W, v_rated, ...)

Scalar cost function for the v6 expansion-rotor DE optimiser.

Returns total airborne mass (kg) if feasible, or a high penalty if
constraints are violated.  Includes a parasitic drag feasibility check:
designs whose structural drag exceeds the hub rotor's aerodynamic shaft power
are rejected as dynamically impossible.
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
    # ══════════════════════════════════════════════════════════════════
    # Dynamic equilibrium solve — find the actual operating ω
    #
    # This must come BEFORE structural evaluation because:
    #   1. The system never operates at the design TSR=4.1 ω — it settles
    #      at ω_eq where torques balance.
    #   2. Structural loads at ω_eq differ from loads at ω_design.
    #   3. Checking structure at ω_design rejects designs that would
    #      survive at their actual (lower) operating ω.
    #
    #   Uses self-consistent iteration: rotor size → ω_eq → re-size →
    #   repeat until converged.  This closes GitHub issue #4.
    # ══════════════════════════════════════════════════════════════════
    ω_eq, r_hub_rotor_sc = solve_equilibrium_self_consistent(
        design, stack, p, n_lines, radii, zs;
        P_per_rotor=P_per_rotor, v_wind=v_rated, elev_rad=elev_angle,
    )

    if ω_eq === nothing
        # Air brake: P_par > P_aero at every ω.  Massive penalty.
        m_exp = sum(er -> er.mass, stack; init=0.0)
        return m_exp + 1_000_000.0
    end

    # Use the self-consistent rotor radius for structural eval
    r_hub_rotor = r_hub_rotor_sc

    # Check power output at equilibrium
    P_gen_eq = p.k_mppt * ω_eq^3
    if P_gen_eq < power_W
        # Equilibrium exists but below rated power.
        # Gradient: designs closer to 50 kW are preferred.
        m_exp = sum(er -> er.mass, stack; init=0.0)
        return max(m_exp, 1.0) * min(power_W / max(P_gen_eq, 1.0), 100.0) + 1_000_000.0
    end

    # ── Evaluate structure at the ACTUAL operating ω ────────────────────
    eval_result = evaluate_design(
        design;
        r_rotor=r_hub_rotor,
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

    if !eval_result.feasible
        fos_penalty = max(1.0, fos_req / max(eval_result.min_fos, 0.01))
        torsion_penalty = max(1.0, 1.5 / max(eval_result.min_torsional_fos, 0.01))
        penalty_mult = min(fos_penalty * torsion_penalty, 10.0)
        return eval_result.mass_total_kg * penalty_mult + 1_000_000.0
    end

    # ── Feasible: return total mass ────────────────────────────────────
    m_expansion = sum(er -> er.mass, stack; init=0.0)
    m_tether = design.n_lines * design.tether_length * (970.0 * π * (p.tether_diameter / 2)^2)
    return eval_result.mass_total_kg + m_expansion + m_tether
end
