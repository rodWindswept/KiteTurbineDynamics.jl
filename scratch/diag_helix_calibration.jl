# scratch/diag_helix_calibration.jl
#
# 2026-09-16.  Trace the closed-form ring load model to its source.
#
# MEASURED DEFECT (scratch/diag_margin_fos_components.jl): the closed form feeds
# `N_comp = 115.25 N` to EVERY cylinder ring (2..8) while the FEA's actual beam
# axial force runs 427 -> 241 N.  cap ratio is exactly 1.000 (same CircularTube,
# same P_crit), so the whole 2.1-3.7x gap is the LOAD model.
#
# The cylinder term is `F_helix = HELIX_LOAD_FACTOR * T_line`, a FLAT scalar
# (0.32) whose comment says "measured on the 5 kW seed".  That seed has since
# been re-seeded (L/r 1.5).  This script reads the implied factor
#     k_i = N_ax_i * den / T_line_i        (den = 2 sin(pi/n_lines))
# per ring on the ACTUAL campaign seed, together with the local per-segment
# twist and transmitted torque, so the replacement term is derived from the
# record instead of guessed.
#
# Pre-flight (docs/agents/physics-topology.md §5): item 3 -- this constant is
# MEASURED, and the machine it was measured on has changed.  Item 6 -- check the
# closed form against an independently computed value (the FEA).  Item 8 --
# re-derive from the record, do not remember.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const X = seed_genome(KW)

println("=== seed_genome(5.0) = ", X)
println("    (canonical 10-D: x3=target_Lr, x4=n_lines, x6=rotor_count)")

function build_with_margin(M)
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
    sizing = size_beams_closed_form(dec, p, cfg; sizing_fos_margin=M)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter,
        base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf, sizing, dec, p
end

function sample_rings(sys, pc, wf, lift, u, dt; n_samp=10, span_s=5.0)
    n = round(Int, span_s / dt)
    chunk = max(1, round(Int, n / n_samp))
    first_ef = nothing
    Nacc = Float64[]
    Sacc = Float64[]
    Qacc = Float64[]
    for k in 1:n_samp
        run_canonical_sim!(u, sys, pc, wf, chunk, dt;
            lift_device=lift, lin_damp=0.05, breaks_enabled=true)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, k * chunk * dt, wf, lift)
        if first_ef === nothing
            first_ef = ef
            Nacc = zeros(length(ef.ring_Ncomp))
            Sacc = zeros(length(ef.segment_tension))
            Qacc = zeros(length(ef.segment_torque))
        end
        Nacc .+= ef.ring_Ncomp
        Sacc .+= ef.segment_tension
        Qacc .+= ef.segment_torque
    end
    return first_ef, Nacc ./ n_samp, Sacc ./ n_samp, Qacc ./ n_samp
end

sys, u0, pc, lift, wf, sizing, dec, p = build_with_margin(1.3)
n_lines = dec.design.n_lines
Nr = sys.n_ring
den = 2.0 * sin(π / n_lines)
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
println("\n  BUILT MACHINE: n_lines = ", n_lines, "   n_ring = ", Nr,
        "   den = 2 sin(pi/n_lines) = ", round(den; digits = 4))
println("  NOTE: seed_genome(5.0) == SEED_LR15_FROZEN (test_gate_v13.jl:86) exactly,",
        " so the frozen fixture IS this campaign seed (n_lines = 6, den = 1.0).")

u = settle_to_operational_state(sys, u0, pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=30_000)
for _ in 1:2
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt;
        lift_device=lift, lin_damp=0.05)
end
ef, Nmean, Tmean, Qmean = sample_rings(sys, pc, wf, lift, u, dt)

println("\n=== per-ring load trace (mean over a 5 s window) ===")
# Segment s joins ground-first rings s and s+1.  Airborne ring k (ground-first
# index k+1) is bounded by segments k and k+1; the closed form takes
# T_line = max(T_below, T_above), so mirror that here.
println("  ", lpad("ring", 5), lpad("Do(mm)", 8), lpad("N_FEA", 9), lpad("T_line", 9),
        lpad("k=N*den/T", 11), lpad("torque", 9), lpad("util_ax", 9),
        lpad("util_bd", 9), lpad("twist_deg", 10))
for k in eachindex(ef.ring_fos)
    i = k + 1
    Do = sizing.Do_per_ring[i] * 1e3
    Nk = Nmean[k]
    Tseg = Float64[]
    k <= length(Tmean) && push!(Tseg, Tmean[k])
    (k + 1) <= length(Tmean) && push!(Tseg, Tmean[k + 1])
    Tk = isempty(Tseg) ? NaN : maximum(Tseg)
    kk = (isfinite(Tk) && Tk > 1.0) ? Nk * den / Tk : NaN
    Qk = k <= length(Qmean) ? Qmean[k] : NaN
    tw = k <= length(ef.segment_twist_deg) ? ef.segment_twist_deg[k] : NaN
    @printf("  %5d %8.3f %9.2f %9.2f %11.4f %9.2f %9.4f %9.4f %10.3f\n",
        i, Do, Nk, Tk, kk, Qk, ef.ring_util_axial[k], ef.ring_util_bending[k], tw)
end
println("\n  CURRENT model: N_comp = HELIX_LOAD_FACTOR * T_line / den  (F_kink = 0 in cylinder)")
println("                 HELIX_LOAD_FACTOR = ", HELIX_LOAD_FACTOR,
        " -> N_comp = ", round(HELIX_LOAD_FACTOR / den; digits=4), " * T_line")
println("=== done ===")
