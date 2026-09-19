# scratch/diag_margin_fos_components.jl
#
# 2026-09-16.  WHY does the SIZING_FOS_MARGIN sweep move the windowed FoS so
# little?  The probe reads FoS_min ~0.61/0.68/0.67 for margins 1.3/1.5/1.7 —
# a +31 % sizing target buys +12 % FoS.  Hypothesis: the closed-form
# `solve_ring_Do` enforces a pure AXIAL buckling criterion
# (P_crit >= fos_req * N), while the measured acceptance FoS is the COMBINED
# utilisation  FoS = 1/(N/N_crit + M/M_el).  If bending dominates the sum, the
# margin is not a lever on the measured quantity at all.
#
# This prints, per airborne ring, the axial and bending shares at the worst
# sample of a 5 s window, so the mechanism is read off the record rather than
# assumed.  Same build/settle protocol as the probe, so the numbers are
# directly comparable to its 0.609 at M = 1.3.

using KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const X = seed_genome(KW)
const M = 1.3          # the baseline margin; the probe's 0.609 row

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
    return sys, u0, pc, lift, wf, sizing
end

sys, u0, pc, lift, wf, sizing = build_with_margin(M)
N, Nr = sys.n_total, sys.n_ring
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
println("dt = ", dt, "  n_ring = ", Nr)

u = settle_to_operational_state(sys, u0, pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=30_000)
for _ in 1:2
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt;
        lift_device=lift, lin_damp=0.05)
end

# ── Component report at the worst sample of a 5 s window ────────────────────
# NOTE: every loop lives in a FUNCTION.  A bare top-level `for` soft-scopes its
# assignments, so `best_fos`/`best_ef` stay undefined outside it (Julia soft
# scope; the same trap documented in test_physics_path_ode.jl).
function sweep_window(u, sys, pc, wf, lift, dt)
    n = round(Int, 5.0 / dt)
    chunk = max(1, round(Int, n / 8))
    best_fos = Inf
    best_ef = nothing
    for k in 1:8
        run_canonical_sim!(u, sys, pc, wf, chunk, dt;
            lift_device=lift, lin_damp=0.05, breaks_enabled=true)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, k * chunk * dt, wf, lift)
        f, _ = KiteTurbineDynamics.min_airborne_fos(ef.ring_fos)
        if f < best_fos
            best_fos = f
            best_ef = ef
        end
    end
    return best_fos, best_ef
end

best_fos, ef = sweep_window(u, sys, pc, wf, lift, dt)
println("\n=== worst-sample FoS breakdown, M = ", M, " ===")
println("  min_airborne_fos = ", round(best_fos; digits = 4))
println("  ring_fos length  = ", length(ef.ring_fos),
        "   util_a len = ", length(ef.ring_util_axial),
        "   util_b len = ", length(ef.ring_util_bending))
println("  ", lpad("ring", 5), lpad("FoS", 10), lpad("util_axial", 12),
        lpad("util_bend", 12), lpad("sum", 12), lpad("bend frac", 11))
for i in eachindex(ef.ring_fos)
    a = i <= length(ef.ring_util_axial) ? ef.ring_util_axial[i] : NaN
    b = i <= length(ef.ring_util_bending) ? ef.ring_util_bending[i] : NaN
    s = a + b
    frac = (isfinite(s) && s > 0) ? b / s : NaN
    println("  ", lpad(i, 5), lpad(round(ef.ring_fos[i]; digits=4), 10),
            lpad(round(a; digits=4), 12), lpad(round(b; digits=4), 12),
            lpad(round(s; digits=4), 12), lpad(round(frac; digits=4), 11))
end

# Closed-form sizing vs measured acceptance FoS, with the LOAD and CAPACITY
# terms separated.  `fos_per_ring` = P_crit_sizing / N_comp_sizing is the AXIAL
# (Euler buckling) FoS the sizing targeted.  The acceptance FoS is the combined
# interaction from the FEA.  Printing N and P_crit from BOTH sides says whether
# the ~3.7x gap is a LOAD-model error (N_comp != N_ax) or a CAPACITY error
# (P_crit != N_crit) — the two need completely different fixes, so measure it
# rather than assume it.
#
# INDEX ALIGNMENT: `ef.ring_fos` is AIRBORNE-only (`ring_ids[2:end]`, see
# ring_element_analysis.jl:650), while `sizing.Do_per_ring` is ground-first with
# all rings.  So ef index k corresponds to sizing index k+1.  The earlier version
# of this script compared them at the same index and was off by one ring.
println("\n=== closed-form sizing vs FEA, LOAD and CAPACITY split (M = ", M, ") ===")
println("  sizing target fos_req = cfg.fos_hard * M = ", sizing.fos_req * M)
println("  ", lpad("ring", 5), lpad("Do(mm)", 8), lpad("N_siz", 9), lpad("N_fea", 9),
        lpad("Pcr_siz", 10), lpad("Pcr_fea", 10), lpad("cap r", 7),
        lpad("load r", 7), lpad("fos_siz", 9), lpad("fos_fea", 9))
wall_of(Do) = max(KiteTurbineDynamics.MIN_TUBE_WALL_M, sizing.t_over_D * Do)
for k in eachindex(ef.ring_fos)
    i = k + 1                     # airborne k -> ground-first sizing index
    Do = sizing.Do_per_ring[i]
    Ns = sizing.N_comp_per_ring[i]
    Ps = sizing.fos_per_ring[i] > 0 && isfinite(sizing.fos_per_ring[i]) ?
         sizing.fos_per_ring[i] * Ns : Inf
    Nf = k <= length(ef.ring_Ncomp) ? ef.ring_Ncomp[k] : NaN
    Pf = k <= length(ef.ring_Pcrit) ? ef.ring_Pcrit[k] : NaN
    capr = (Ps > 0 && isfinite(Ps) && isfinite(Pf) && Pf > 0) ? Ps / Pf : NaN
    loadr = (Ns > 0 && isfinite(Nf) && Nf > 0) ? Nf / Ns : NaN
    println("  ", lpad(i, 5), lpad(round(Do * 1e3; digits=3), 8),
            lpad(round(Ns; digits=2), 9), lpad(round(Nf; digits=2), 9),
            lpad(round(Ps; digits=1), 10), lpad(round(Pf; digits=1), 10),
            lpad(round(capr; digits=3), 7), lpad(round(loadr; digits=3), 7),
            lpad(round(sizing.fos_per_ring[i]; digits=3), 9),
            lpad(round(ef.ring_fos[k]; digits=3), 9))
end
println("\n  cap  r = P_crit_sizing / P_crit_FEA   (1.0 => same capacity model)")
println("  load r = N_FEA        / N_sizing      (1.0 => same load model)")
println("  MIN wall clamp = ", KiteTurbineDynamics.MIN_TUBE_WALL_M * 1e3, " mm")
println("\nP_end-ish: omega_gnd = ", u[6N + Nr + 1])
println("=== done ===")
