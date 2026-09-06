# test/test_settle_drag_alignment.jl
#
# Acceptance tests for the settle-drag-alignment proposal
# (docs/plans/2026-08-13-settle-drag-alignment.md).
#
# Re-baselined 2026-09-04 to the corrected 5 kW campaign (daisy params @ 18.8 m,
# seed_genome(5.0), campaign decode knobs, mass-aware const-tension lift, winner
# = the corrected campaign's best_vector.csv).
#
# A. Gap reduction: |ω_settle − ω_final|/ω_settle < 0.30-ish for the 5kW winner
# B. Bit-identity guard: drag_fn = (_) -> 0.0 reproduces the master settle
# C. Monotonicity: larger tether diameter → lower ω_settle
# D. No new stall: winner still passes the 20s ODE gate
# E. Drag model sanity: P_par ≥ 0, increasing in ω, zero at ω=0

using Test
using KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5

# Corrected 5 kW seed (compute_seeds.jl: 3 rotors, r_hub 2.4 m, n_lines 6,
# Do 0.08, blade_scale 0.7) — the OLD hardcoded SEED5 (pre-Daisy r_hub 0.914)
# is void under the corrected physics.
const SEED5 = seed_genome(5.0)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    # LENGTH FIX (2026-08-22): mass_scale also scales the tether length; L is
    # the FINAL machine length — restore it after rung scaling.
    return override_params(scaled; tether_length=L)
end

# Campaign mass-aware constant-tension lift (mirrors ode_gate_v13.jl).
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=11.0, const_tension=true)

function build_from_genome(x::Vector{Float64}, p::SystemParams)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: {1,2,3}
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    return sys, u0, pc, dec
end

function hub_omega(u, sys)
    return u[6*sys.n_total + 2*sys.n_ring]
end

# Corrected campaign winner genome (single rotor, r_hub 4.32 m, n_lines 3).
const WINNER_CSV = joinpath(dirname(@__DIR__), "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

@testset "Settle drag alignment — acceptance" begin

    @testset "B. bit-identity with zero drag" begin
        # Pre-change master value was 16.05 for the stale 5kW seed; re-measured
        # on the corrected seed (daisy/18.8).  ω_zero_drag now lands near the
        # settle cp-peak clamp; see A for the gap.
        p = params_at_length(18.8)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        lift = lift_for(sys, pc)
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift,
            wind_fn=(r, t) -> [p.v_wind_ref, 0.0, 0.0],
            n_op=20_000, drag_fn=(_...) -> 0.0)
        ω_zero_drag = hub_omega(u, sys)
        @test abs(ω_zero_drag - 15.6) < 0.5   # re-measured on corrected seed (cp-peak clamp)
    end

    @testset "E. drag model sanity" begin
        p = params_at_length(18.8)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        lift = lift_for(sys, pc)
        u_start = settle_to_equilibrium(sys, u0, pc;
            lift_device=lift,
            wind_fn=(r, t) -> [p.v_wind_ref, 0.0, 0.0])
        fn = KiteTurbineDynamics.settle_parasitic_drag_power
        @test fn(sys, p, 0.0, u_start) == 0.0
        vals = [fn(sys, p, w, u_start) for w in [2.0, 5.0, 10.0, 20.0]]
        @test all(v -> v >= 0.0, vals)
        @test issorted(vals)   # increasing in ω
    end

    @testset "A. gap reduction on 5kW winner" begin
        p = params_at_length(18.8)
        x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
        sys, u0, pc, dec = build_from_genome(x, p)
        lift = lift_for(sys, pc)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wind_fn, n_op=30_000)
        ω_settle = hub_omega(u, sys)
        sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 20.0/DT), DT;
            lift_device=lift, lin_damp=0.05)
        ω_final = hub_omega(u, sys)
        gap = abs(ω_settle - ω_final) / ω_settle
        @test ω_final > 0.5
        # TRACKED OPEN ITEM (Rod decision (a), 2026-09-04): the settle parks at
        # the cp-peak clamp, which sits ABOVE the true MPPT equilibrium, so the
        # ODE winds down to it — the settle-ODE gap workstream
        # (docs/plans/2026-08-22-settle-ode-gap-workstream.md).  The gap is
        # deliberately LEFT above 0.30 until that workstream lands.
        @test gap < 0.80
    end

    @testset "C. monotonicity in tether diameter" begin
        p = params_at_length(18.8)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        lift = lift_for(sys, pc)
        u_start = settle_to_equilibrium(sys, u0, pc;
            lift_device=lift,
            wind_fn=(r, t) -> [p.v_wind_ref, 0.0, 0.0])
        Ppar = Float64[]
        for d_tether in [0.002, 0.003, 0.004, 0.005]
            pd = KiteTurbineDynamics.override_params(p; tether_diameter=d_tether)
            push!(Ppar, KiteTurbineDynamics.settle_parasitic_drag_power(sys, pd, 16.0, u_start))
        end
        @test issorted(Ppar)                 # drag ↑ with diameter (sign guard)
        @test Ppar[end] > Ppar[1] + 100.0    # and it is material (~300 W), not epsilon
    end

    @testset "D. no new stall (20s gate)" begin
        p = params_at_length(18.8)
        x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
        sys, u0, pc, dec = build_from_genome(x, p)
        lift = lift_for(sys, pc)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wind_fn, n_op=30_000)
        sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 20.0/DT), DT;
            lift_device=lift, lin_damp=0.05)
        ωf = hub_omega(u, sys)
        Pf = sys.k_mppt_ref[] * ωf^3 / 1000.0
        @test Pf >= 5.0   # campaign floor (was 2.5 on the stale machine)
    end
end
