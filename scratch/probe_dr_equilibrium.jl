# scratch/probe_dr_equilibrium.jl
#
# 2026-09-19.  The static-to-static comparison the prototype never made, plus the
# two questions steps 1-2 turn on:
#
#   A. Does the post-DR `update_kite_pos!` re-projection disturb the equilibrium?
#      (The prototype never called it, so its "after" state had a lift line whose
#      length was whatever the anchor drift left it.)
#   B. Does the DR equilibrium tension still clear the torsional realisability
#      floor?  The matched-place placed F_ax; DR relaxes to the true equilibrium,
#      which `probe_dr_wired.jl` measured 33 % away.  Direction matters.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

"Static node residuals: translational velocities zeroed, omega retained."
function static_residuals(u, sys, p, wf, lift, N)
    us = copy(u)
    @views us[(3N + 1):(6N)] .= 0.0
    du = zeros(length(us))
    KiteTurbineDynamics.multibody_ode!(du, us, (sys, p, wf, lift), 0.0)
    out = Dict{String,Float64}()
    for (nm, gid) in (("hub", sys.rotor.node_id), ("bearing", sys.bearing_id),
                      ("sky", sys.sky_anchor_id))
        m = sys.nodes[gid].mass
        out[nm] = norm(@views m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)])
    end
    out["acc0"] = maximum(norm(@views du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    return out
end

function report(tag, u, sys, p, wf, lift)
    N = sys.n_total
    r = static_residuals(u, sys, p, wf, lift, N)
    sa = @views u[(3 * (sys.sky_anchor_id - 1) + 1):(3 * sys.sky_anchor_id)]
    ld = norm(sys.kite_pos .- sa)
    f_on = lift_force_applied(u, sys, p, wf, lift)
    @printf("  [%-26s] acc0 %8.3f m/s2 (%6.3f g)  hub %8.3f  bear %7.3f  sky %7.3f N  lift_line %.4f m  |F_lift| %.2f N\n",
        tag, r["acc0"], r["acc0"] / 9.81, r["hub"], r["bearing"], r["sky"], ld, norm(f_on))
    return r
end

function lift_force_applied(u, sys, p, wf, lift)
    N = sys.n_total
    du_on = zeros(length(u)); KiteTurbineDynamics.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off = zeros(length(u)); KiteTurbineDynamics.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    g = sys.sky_anchor_id
    m = sys.nodes[g].mass
    return m .* (@views du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
                 du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)])
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== campaign seed, n_op = 300_000, DR 20_000 iters ===")

    # Settle with the polish OFF, then drive the internal pass by hand so states
    # A (post-DR) and B (post-reprojection) can both be measured.
    u = settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000, static_polish=false)
    report("0 settled, polish OFF", u, sys, p, wf, lift)

    ode_params = (sys, p, wf, lift)
    t_dr = @elapsed KiteTurbineDynamics._polish_static_equilibrium!(
        u, sys, ode_params; dt=2.0e-4, max_iters=20_000)
    @printf("  DR 20_000 iters: %.1f s\n", t_dr)
    rA = report("A post-DR, pre-reproject", u, sys, p, wf, lift)

    update_kite_pos!(sys, u, lift, p, 0.0)
    rB = report("B post-reprojection", u, sys, p, wf, lift)

    # ── Equilibrium tension vs intended preload ───────────────────────────
    ω = u[6N + Nr + 1]
    F_ax_design = design_axial_preload(sys, p, lift, u0; omega_eq=ω, wind_fn=wf)
    ef = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift)
    T_eq = ef.segment_tension
    T_in = F_ax_design ./ p.n_lines
    @printf("\n  %-4s %12s %12s %9s\n", "seg", "intended N", "equil N", "eq/in")
    for s in 1:(Nr - 1)
        @printf("  %-4d %12.3f %12.3f %9.4f\n", s, T_in[s], T_eq[s], T_eq[s] / T_in[s])
    end

    # Realisability demand at the ACTUAL equilibrium tension.
    τ_eq = sys.k_mppt_ref[] * ω^2
    pe = trpt_matched_place(sys, p, T_eq .* p.n_lines, τ_eq, ω, wf;
        raise_on_unrealisable=false)
    pd = trpt_matched_place(sys, p, F_ax_design, τ_eq, ω, wf;
        raise_on_unrealisable=false)
    @printf("\n  τ_eq = %.3f N·m   (k=%.6g, ω=%.6f)\n", τ_eq, sys.k_mppt_ref[], ω)
    @printf("  %-4s %12s %12s %12s\n", "seg", "demand@eq", "demand@design", "τ_carry")
    for s in 1:(Nr - 1)
        @printf("  %-4d %12.4f %12.4f %12.2f\n", s, pe.demand[s], pd.demand[s], pe.τ_carry[s])
    end
    @printf("\n  max demand @ equilibrium tension = %.4f   @ design tension = %.4f   (cliff 1.0, margin target %.4f)\n",
        maximum(pe.demand), maximum(pd.demand), 1.0 / TRPT_REALISABILITY_TENSION_MARGIN)

    println("=== done ===")
end

main()
