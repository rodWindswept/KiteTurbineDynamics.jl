# scratch/diag_a5_strain.jl
#
# 2026-09-16.  THE decisive measurement for A5: what does the break latch's OWN
# quantity actually read on the thin-tether machine?
#
# A5 expects the 0.25 mm (built ~0.456 mm) tether to break.  Measured:
#     tension at break (EA x 0.035) = 572.7 N/line
#     get_max_rope_tension in the window = 809 - 852 N
# yet the latch never trips.  Two candidates:
#   (a) geometric strain is genuinely below 0.035 while tension is above the break
#       tension -> the break CRITERION and the LOAD MODEL disagree.  A real defect.
#   (b) geometric strain is above 0.035 and the latch does not fire -> plain bug.
#
# This probe reproduces the latch's own computation EXACTLY, with no re-derivation:
# it passes `breaks_enabled = true` so `compute_rope_forces!` itself accumulates
# `seg_pathlen`/`seg_restlen`, then reads them straight back out of the arrays the
# latch uses.  No separate strain formula, so there is no second implementation to
# get wrong (the 2026-09-16 mistake).
#
# Protocol mirrors the gate: settle n_op=30_000, 10 s of relax, then the window.
#
# Self-checking: asserts the arrays are the latch's own, that pathlen >= restlen
# where sampled, and that the reported break tension is EA * ROPE_BREAK_STRAIN.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

"""Build the A5 machine: campaign seed at the requested tether diameter."""
function build_thin(diameter_in)
    p_thin = override_params(params_daisy(); tether_diameter=diameter_in)
    p = params_at_length(p_thin, L18, KW)
    x = seed_genome(KW)
    dec = KiteTurbineDynamics.design_from_vector_v10(
        KiteTurbineDynamics.canonical_v10(x),
        PROFILE_ELLIPTICAL,
        p;
        power_W=5000.0,
        v_rated=11.0,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    cfg = ObjectiveConfig(;
        power_W=5000.0,
        v_rated=11.0,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        fos_target=2.5,
        fos_hard=2.5,
        min_wall_m=2e-3,
        t_over_D=0.055,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST,
    )
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf, p
end

function report(diameter_in)
    sys, u0, pc, lift, wf, p = build_thin(diameter_in)
    d = p.tether_diameter
    EA = p.e_modulus * pi * (d / 2)^2
    Tbreak = EA * KiteTurbineDynamics.ROPE_BREAK_STRAIN

    u = settle_to_operational_state(
        sys, u0, pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000
    )
    @assert all(isfinite, u)
    N, Nr = sys.n_total, sys.n_ring
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)

    # Gate protocol: 10 s relax before the measured window.
    for _ in 1:2
        run_canonical_sim!(
            u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05
        )
    end

    println(
        "\n=== requested ",
        diameter_in * 1000,
        " mm  ->  built ",
        round(d * 1000; digits=4),
        " mm ===",
    )
    println(
        "  EA = ",
        round(EA; digits=1),
        " N   break tension = ",
        round(Tbreak; digits=1),
        " N   break strain = ",
        KiteTurbineDynamics.ROPE_BREAK_STRAIN,
    )

    # Observe the latch's OWN internal quantity via the temporary debug Refs in
    # rope_forces.jl.  No re-implementation: `compute_rope_forces!` writes these
    # where it evaluates the threshold.
    KiteTurbineDynamics.rope_break_debug_reset!()
    sys.any_broken[] = false
    println(
        "  ",
        lpad("t s", 8),
        lpad("T_max N", 10),
        lpad("latch strain", 13),
        lpad("seg", 5),
        lpad("pathlen", 10),
        lpad("restlen", 10),
        lpad("break T N", 11),
        "   latch",
    )

    for k in 1:round(Int, 30.0 / dt)
        du = zeros(length(u))
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, pc, wf, lift), k * dt)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        u[6N + 1] = 0.0
        u[6N + Nr + 1] = 0.0

        if k % 50_000 == 0 || k == 1
            T, _ = get_max_rope_tension(u, sys, pc)
            strain = KiteTurbineDynamics.ROPE_BREAK_DEBUG_MAX[]
            seg = KiteTurbineDynamics.ROPE_BREAK_DEBUG_SEG[]
            pl = KiteTurbineDynamics.ROPE_BREAK_DEBUG_PATH[]
            rl = KiteTurbineDynamics.ROPE_BREAK_DEBUG_REST[]
            println(
                "  ",
                lpad(round(k * dt; digits=2), 8),
                lpad(round(T; digits=1), 10),
                lpad(round(strain; digits=6), 13),
                lpad(seg, 5),
                lpad(round(pl; digits=5), 10),
                lpad(round(rl; digits=5), 10),
                lpad(round(EA * strain; digits=1), 11),
                "   ",
                sys.any_broken[],
            )
            @assert isfinite(strain) && strain >= 0.0
        end
        sys.any_broken[] && break
    end
    println(
        "  peak latch strain over the window = ",
        round(KiteTurbineDynamics.ROPE_BREAK_DEBUG_MAX[]; digits=6),
        "   threshold = ",
        KiteTurbineDynamics.ROPE_BREAK_STRAIN,
    )
    println("  final latch = ", sys.any_broken[])
    return sys.any_broken[]
end

report(0.00025)
println("\n=== done ===")
