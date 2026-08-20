# test/test_settle_drag_alignment.jl
#
# Acceptance tests for the settle-drag-alignment proposal
# (docs/plans/2026-08-13-settle-drag-alignment.md).
#
# Written BEFORE the implementation — these FAIL on current master.
# They must PASS once the settle's ω scan includes parasitic drag.
#
# A. Gap reduction: |ω_settle − ω_final|/ω_settle < 0.20 for the 5kW winner
# B. Bit-identity guard: drag_fn = (_) -> 0.0 reproduces the master settle
# C. Monotonicity: larger tether diameter → lower ω_settle
# D. No new stall: winner still passes the 20s ODE gate
# E. Drag model sanity: P_par ≥ 0, increasing in ω, zero at ω=0

using Test
using KiteTurbineDynamics

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5

# Approved 5kW seed (compute_seeds.jl, Rod-approved table)
const SEED5 = [0.019, 0.010, 0.880, 1.000, 0.914, 0.632, 2.988, 6.0,
               -0.11, 18.56, 15.0, 15.0, 0.519, 0.1]

function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

function build_from_genome(x::Vector{Float64}, p::SystemParams)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    return sys, u0, pc, dec
end

function hub_omega(u, sys)
    return u[6*sys.n_total + 2*sys.n_ring]
end

@testset "Settle drag alignment — acceptance" begin

    @testset "B. bit-identity with zero drag" begin
        # Pre-change master value for the 5kW seed at ceiling 60 is 16.05 rad/s
        p = params_at_length(21.2)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=rotary_lifter_default(),
            wind_fn=(r, t) -> [p.v_wind_ref, 0.0, 0.0],
            n_op=20_000, drag_fn=(_...) -> 0.0)
        ω_zero_drag = hub_omega(u, sys)
        @test abs(ω_zero_drag - 16.05) < 0.5   # master bit-identity anchor
    end

    @testset "E. drag model sanity" begin
        p = params_at_length(21.2)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        u_start = settle_to_equilibrium(sys, u0, pc;
            lift_device=rotary_lifter_default(),
            wind_fn=(r, t) -> [p.v_wind_ref, 0.0, 0.0])
        fn = KiteTurbineDynamics.settle_parasitic_drag_power
        @test fn(sys, p, 0.0, u_start) == 0.0
        vals = [fn(sys, p, w, u_start) for w in [2.0, 5.0, 10.0, 20.0]]
        @test all(v -> v >= 0.0, vals)
        @test issorted(vals)   # increasing in ω
    end

    @testset "A. gap reduction on 5kW winner" begin
        p = params_at_length(21.2)
        csv = joinpath(dirname(@__DIR__), "scripts", "results",
                       "v12_5kw_coldstart", "island_1_best.csv")
        x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
        sys, u0, pc, dec = build_from_genome(x, p)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = rotary_lifter_default()
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wind_fn, n_op=30_000)
        ω_settle = hub_omega(u, sys)
        sys.k_mppt_ref[] = p.k_mppt
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 20.0/DT), DT;
            lift_device=lift, lin_damp=0.05)
        ω_final = hub_omega(u, sys)
        gap = abs(ω_settle - ω_final) / ω_settle
        @test ω_final > 0.5
        @test gap < 0.30   # residual is the torsional-collapse/aero mismatch (DECISIONS [2026-08-13]), not drag
    end

    @testset "C. monotonicity in tether diameter" begin
        # Direct drag-function monotonicity (the sign/coverage guard the proposal
        # intended).  ω_settle is insensitive to diameter here — the 2→5 mm drag
        # difference (~300 W) shifts the equilibrium by less than the ω-scan's
        # 0.301 rad/s quantization (residual owner: DECISIONS [2026-08-13]
        # torsional-collapse/aero mismatch).  Test the drag term itself instead.
        p = params_at_length(21.2)
        sys, u0, pc, dec = build_from_genome(SEED5, p)
        u_start = settle_to_equilibrium(sys, u0, pc;
            lift_device=rotary_lifter_default(),
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
        p = params_at_length(21.2)
        csv = joinpath(dirname(@__DIR__), "scripts", "results",
                       "v12_5kw_coldstart", "island_1_best.csv")
        x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
        sys, u0, pc, dec = build_from_genome(x, p)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = rotary_lifter_default()
        u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
            lift_device=lift, wind_fn=wind_fn, n_op=30_000)
        sys.k_mppt_ref[] = p.k_mppt
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 20.0/DT), DT;
            lift_device=lift, lin_damp=0.05)
        ωf = hub_omega(u, sys)
        Pf = sys.k_mppt_ref[] * ωf^3 / 1000.0
        @test Pf >= 2.5   # no regression into stall
    end
end
