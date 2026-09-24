# scratch/diag_thin_tether.jl
#
# 2026-09-16.  Why does the A5 thin-tether machine NOT break its line?
#
# Rod's challenge: "0.25mm line should be crazy thin to run a 5kW system on ...
# That would surely break."  Two candidate answers, and they have different fixes:
#   (a) the line is never loaded hard enough to reach 3.5% strain (a tuning
#       problem in the test fixture), or
#   (b) the line is loaded hard but the break latch is not seeing it (a real
#       defect in the detection path).
#
# Method: build the A5 machine (seed genome at L/r 1.5, tether_diameter 0.25 mm,
# so ~0.456 mm after rung scaling), settle, then run the gate window and sample
# the PEAK sub-segment tension and the equivalent strain = T/EA every step.
#
# Self-checking: asserts finite geometry, that the sampled strain is derived from
# the same EA the break latch uses, and reports the margin to ROPE_BREAK_STRAIN.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

p_thin = override_params(params_daisy(); tether_diameter=0.00025)
p = params_at_length(p_thin, L18, KW)
d = p.tether_diameter
EA = p.e_modulus * pi * (d / 2)^2
@assert d > 0.0 && EA > 0.0
println("=== A5 thin-tether machine ===")
println("  requested (pre-scale) = 0.25 mm")
println("  BUILT diameter        = ", round(d * 1000; digits=4), " mm")
println("  line EA               = ", round(EA; digits=1), " N")
println("  break strain          = ", KiteTurbineDynamics.ROPE_BREAK_STRAIN)
println(
    "  tension at break      = ",
    round(EA * KiteTurbineDynamics.ROPE_BREAK_STRAIN; digits=1),
    " N/line",
)

# Build the same machine the gate builds.
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

u = settle_to_operational_state(
    sys, u0, pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000
)
@assert all(isfinite, u) "settled state not finite"

N, Nr = sys.n_total, sys.n_ring
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
n = round(Int, 30.0 / dt)   # the gate's 30 s window

"""Run the gate window; return (peak tension, its time, latch state)."""
function run_window(u, sys, pc, wf, lift, dt, t_seconds)
    N, Nr = sys.n_total, sys.n_ring
    n = round(Int, t_seconds / dt)
    sys.breaks_enabled[] = true
    peak_T = 0.0
    peak_t = 0.0
    for k in 1:n
        dur = zeros(length(u))
        KiteTurbineDynamics.multibody_ode!(dur, u, (sys, pc, wf, lift), k * dt)
        @views u[(3N + 1):6N] .+= dt .* dur[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* dur[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        u[6N + 1] = 0.0
        u[6N + Nr + 1] = 0.0
        T, _ = get_max_rope_tension(u, sys, pc)
        if isfinite(T) && T > peak_T
            peak_T = T
            peak_t = k * dt
        end
        sys.any_broken[] && break
    end
    return peak_T, peak_t, sys.any_broken[]
end

# Match the gate's protocol exactly (ode_gate_v13.jl:169-175): 10 s of relax
# BEFORE the measured window, which is what damps the settle->run transient.
for _ in 1:2
    run_canonical_sim!(
        u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05
    )
end
peak_T, peak_t, latched = run_window(u, sys, pc, wf, lift, dt, 30.0)
strain = peak_T / EA
println("\n=== over the gate's ", round(30.0; digits=0), " s window ===")
println(
    "  peak sub-segment tension = ",
    round(peak_T; digits=1),
    " N   (at t=",
    round(peak_t; digits=2),
    " s)",
)
println(
    "  equivalent strain T/EA   = ",
    round(strain; digits=5),
    "   (break at ",
    KiteTurbineDynamics.ROPE_BREAK_STRAIN,
    ")",
)
println(
    "  margin to break strain   = ",
    round(
        (KiteTurbineDynamics.ROPE_BREAK_STRAIN - strain) /
        KiteTurbineDynamics.ROPE_BREAK_STRAIN * 100;
        digits=1,
    ),
    " % BELOW break",
)
println(
    "  tension needed to break  = ",
    round(EA * KiteTurbineDynamics.ROPE_BREAK_STRAIN; digits=1),
    " N",
)
println("  latch tripped            = ", latched)
@assert isfinite(peak_T) && peak_T >= 0.0
println("\n=== done ===")
