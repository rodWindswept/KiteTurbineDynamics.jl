# scratch/probe_do_floor_margin.jl
#
# 2026-09-16.  Trade the tube-Do manufacturability floor against airborne mass.
#
# WHY.  Correcting the closed-form load model (HELIX_LOAD_FACTOR 0.32 -> 1.2)
# and adding MIN_RING_DO_M = 12 mm took the 5 s windowed FoS from 0.609 to
# 5.336 — far above the 2.5 floor — but airborne mass from 29.216 kg to
# 33.115 kg (+3.9 kg).  That is over the <1 kg budget, and the margin sweep
# showed the floor BINDS on all seven cylinder rings, so the floor (not the
# solve) is setting those sections.  This measures how much floor is actually
# needed: the solve already targets `fos_hard * margin` on the corrected load,
# so the floor only has to keep the section out of the wire regime.
#
# Reference mass 29.216 kg is the PRE-FIX machine at margin 1.3 (the 0.609 FoS
# baseline) — the last mass the design actually had.  It is not a valid design
# (FoS 0.61 against a 2.5 floor), so the delta is a price-of-validity, not a
# regression against a working point.
#
# Self-checking: asserts the built tether matches the params, that mass is
# finite and positive, and that every reported FoS is finite.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const X = seed_genome(KW)
const REFERENCE_M_AIR = 29.216          # pre-fix, margin 1.3, FoS 0.609
const FLOORS = (0.010, 0.012)
const WINDOWS = (20.0,)                 # the STRICTER window (A3)
const MARGIN = 1.3

function build_with_floor(M, floor_m)
    p = params_at_length(params_daisy(), L18, KW)
    cfg = ObjectiveConfig(;
        power_W=KW * 1000.0, v_rated=11.0, p_floor_kw=KW, p_ceiling_kw=KW,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p.tether_diameter)
    dec = KiteTurbineDynamics.design_from_vector_v10(
        KiteTurbineDynamics.canonical_v10(X), PROFILE_ELLIPTICAL, p;
        power_W=KW * 1000.0, cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sizing = size_beams_closed_form(dec, p, cfg;
        sizing_fos_margin=M, min_Do_m=floor_m)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter,
        base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    @assert pc.tether_diameter == p.tether_diameter "tether diameter not aligned"
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf, sizing
end

function measure(M, floor_m, t_win)
    sys, u0, pc, lift, wf, sizing = build_with_floor(M, floor_m)
    N, Nr = sys.n_total, sys.n_ring
    m_air = KiteTurbineDynamics.expansion_airborne_mass(sys, pc; include_lifter=false)
    @assert isfinite(m_air) && m_air > 0.0
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)

    u = settle_to_operational_state(sys, u0, pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=30_000)
    for _ in 1:2
        run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt;
            lift_device=lift, lin_damp=0.05)
    end

    fos_min = Inf
    worst = 0
    P_tail = Float64[]
    n = round(Int, t_win / dt)
    chunk = max(1, round(Int, n / 8))
    for k in 1:8
        run_canonical_sim!(u, sys, pc, wf, chunk, dt;
            lift_device=lift, lin_damp=0.05, breaks_enabled=true)
        fosv, idv = KiteTurbineDynamics.min_airborne_fos(
            KiteTurbineDynamics.capture_extended(u, sys, pc, k * chunk * dt, wf, lift).ring_fos)
        if fosv < fos_min
            fos_min = fosv
            worst = idv
        end
        w_gnd = u[6N + Nr + 1]
        tau, _ = get_generator_torque(u, sys, pc, k * chunk * dt, wf;
            brake_engaged=sys.brake_engaged[])
        push!(P_tail, tau * w_gnd / 1000.0)
        length(P_tail) > 5 && popfirst!(P_tail)
    end
    @assert isfinite(fos_min) "FoS not finite"
    P_end = sum(P_tail) / length(P_tail)
    return (; fos_min=fos_min, worst=worst, m_air=m_air, P_end=P_end,
            Do_min=minimum(sizing.Do_per_ring), Do_max=maximum(sizing.Do_per_ring),
            broken=sys.any_broken[])
end

println("=== tube-Do floor trade, margin = ", MARGIN, ", 5 kW seed, scaled tether ===")
println("  reference m_air (pre-fix) = ", REFERENCE_M_AIR, " kg")
println("  ", lpad("floor mm", 9), lpad("win s", 7), lpad("FoS_min", 9), lpad("worst", 7),
        lpad("Do min", 8), lpad("Do max", 8), lpad("m_air kg", 10),
        lpad("dm kg", 8), lpad("P_end", 8), "  broken")
for f in FLOORS
    for tw in WINDOWS
        r = measure(MARGIN, f, tw)
        println("  ", lpad(round(f * 1e3; digits=1), 9), lpad(tw, 7),
                lpad(round(r.fos_min; digits=3), 9), lpad(r.worst, 7),
                lpad(round(r.Do_min * 1e3; digits=2), 8),
                lpad(round(r.Do_max * 1e3; digits=2), 8),
                lpad(round(r.m_air; digits=3), 10),
                lpad(round(r.m_air - REFERENCE_M_AIR; digits=3), 8),
                lpad(round(r.P_end; digits=3), 8), "  ", r.broken)
    end
end
println("\n=== done ===")
