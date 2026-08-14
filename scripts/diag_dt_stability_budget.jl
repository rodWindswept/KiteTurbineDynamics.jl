#!/usr/bin/env julia
# scripts/diag_dt_stability_budget.jl
#
# What pins V11_DT?
#
# `run_canonical_sim!` is semi-implicit (symplectic) Euler: velocity from du,
# then position from the NEW velocity; ring twist likewise; and the MPPT k·ω²
# term is already implicit on the ground ring.  So the step size is set by the
# stiffest *explicit* term left in the loop.  Two candidates per rope node:
#
#   spring  k = EA/L0     → dt < 2·sqrt(m/k)      (symplectic Euler)
#   damper  c = c_damp    → dt < 2·m/c            (explicit viscous term)
#
# initialization.jl:97 sets  c = 2·zeta·sqrt(k·m)  with  zeta = 1.5, so for a
# node carrying two sub-segments the two bounds are in fixed ratio:
#
#   dt_spring / dt_damp = 4·zeta / sqrt(2)
#
# i.e. dt_crit is inversely proportional to zeta once the damper binds
# (zeta > sqrt(2)/4 = 0.354).  This script measures that.
#
# Part 1  Per-node lumped audit reporting the EFFECTIVE damping ratio
#         zeta_eff = c_node / (2·sqrt(k_node·m)), which exposes how far each
#         node type sits from critical.
# Part 2  Damping sweep: scale c_damp by lambda (equivalent to zeta → 1.5·lambda),
#         find the divergence threshold dt_crit for each, and test the predicted
#         dt_crit ∝ 1/zeta proportionality.
# Part 3  Cost of reducing zeta: rope-tension ringing at each damping level,
#         all at the SAME dt, so the comparison is about physics not step size.
#
# Read-only: builds its own systems, writes one CSV. Nothing in src/ is changed.

using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra, Random

const KTD = KiteTurbineDynamics
const DT0 = KTD.V11_DT          # 4e-5
const ZETA_SRC = 1.5            # initialization.jl:97 — the value under test

# 12-gon reference genome (same as diag_dt_refinement.jl, for continuity).
# NOTE: this genome no longer spins up under current physics — fine here,
# because every measurement below is a STABILITY probe about a settled state,
# not a power/accuracy comparison.
const X12 = [
    0.075, 0.01, 1.0, 0.5, 3.7, 2.0, 2.5, 12.0, 0.0,
    8.0, 15.0, 5.0, 0.5, 0.3, log10(60.0),
]

const K_MPPT   = 60.0
const SPOKE    = KTD.SpokeParams(enabled=false)
const SETTLE_S = 60.0

wind_fn_for(p) = (pos, t) -> [11.0 * (max(pos[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]

function build(x; k_mppt=K_MPPT)
    p = params_v5_50kw()
    result = design_from_vector_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    result.n_active == 0 && error("genome decodes to zero active rotors")
    sys, u0, pc = KTD.build_system_from_v10(result, 1.0, k_mppt)
    return (; p, result, sys, u0, pc)
end

"""Set sub-segment damping to `scale` × the as-built value.  `sub_segs` is a
Vector field of an immutable struct — element assignment is legal."""
function set_damping!(sys, orig, scale)
    for i in eachindex(orig)
        ss = orig[i]
        sys.sub_segs[i] = KTD.RopeSubSegment(
            ss.end_a, ss.end_b, ss.length_0, ss.EA, ss.c_damp * scale, ss.diameter,
        )
    end
    return sys
end

# ══════════════════════════════════════════════════════════════════════════════
# Part 1 — per-node audit with effective damping ratio
# ══════════════════════════════════════════════════════════════════════════════

function analytic_audit(sys)
    N = sys.n_total
    k_tot = zeros(N); c_tot = zeros(N); n_att = zeros(Int, N)
    for ss in sys.sub_segs
        k = ss.EA / ss.length_0
        for e in (ss.end_a, ss.end_b)
            id = e.node_id
            (1 <= id <= N) || continue
            k_tot[id] += k; c_tot[id] += ss.c_damp; n_att[id] += 1
        end
    end

    rows = NamedTuple[]
    for i in 1:N
        nd = sys.nodes[i]; m = nd.mass
        (isfinite(m) && m > 0 && m < 1e20) || continue   # skip fixed anchors (m=1e30)
        (n_att[i] == 0 || k_tot[i] <= 0) && continue
        dt_spring = 2.0 * sqrt(m / k_tot[i])
        dt_damp   = c_tot[i] > 0 ? 2.0 * m / c_tot[i] : Inf
        zeta_eff  = c_tot[i] / (2 * sqrt(k_tot[i] * m))
        push!(rows, (; id=i, kind=typeof(nd).name.name, mass=m, n_att=n_att[i],
                     k=k_tot[i], c=c_tot[i], zeta_eff, dt_spring, dt_damp,
                     dt_bind=min(dt_spring, dt_damp),
                     binder = dt_damp < dt_spring ? "damper" : "spring"))
    end
    sort!(rows, by = r -> r.dt_bind)
    return rows
end

function report_audit(rows)
    println("\n── Part 1: per-node lumped audit ───────────────────────────────")
    @printf("  free nodes audited: %d      (dt_spring=2*sqrt(m/k)  dt_damp=2m/c)\n\n",
            length(rows))
    @printf("  %-6s %-11s %10s %5s %10s %11s %11s %s\n",
            "node", "kind", "mass[kg]", "natt", "zeta_eff", "dt_spring", "dt_damp", "binds")
    for r in first(rows, 5)
        @printf("  %-6d %-11s %10.5g %5d %10.3f %11.3e %11.3e %s\n",
                r.id, String(r.kind), r.mass, r.n_att, r.zeta_eff,
                r.dt_spring, r.dt_damp, r.binder)
    end

    # Per node-type summary — bridle/cyan lines use separately hard-coded c_damp.
    println("\n  effective damping ratio by node type:")
    kinds = unique(r.kind for r in rows)
    for kd in kinds
        sel = [r for r in rows if r.kind == kd]
        zs = [r.zeta_eff for r in sel]
        @printf("    %-12s n=%4d   zeta_eff: min=%.3f  median=%.3f  max=%.3f\n",
                String(kd), length(sel), minimum(zs), median(zs), maximum(zs))
    end

    worst = rows[1]
    n_damp = count(r -> r.binder == "damper", rows)
    @printf("\n  worst node dt = %.3e   (V11_DT = %.3e, margin x%.2f)\n",
            worst.dt_bind, DT0, worst.dt_bind / DT0)
    @printf("  binding term: %s on %d/%d nodes\n", worst.binder, n_damp, length(rows))
    @printf("  predicted dt_spring/dt_damp for a 2-attachment rope node = 4*zeta/sqrt(2) = %.3f\n",
            4 * ZETA_SRC / sqrt(2))
    @printf("  measured                                                  = %.3f\n",
            worst.dt_spring / worst.dt_damp)
    return worst
end

# ══════════════════════════════════════════════════════════════════════════════
# Part 2 — damping sweep → dt_crit proportionality
# ══════════════════════════════════════════════════════════════════════════════

snapshot(sys) = (tilt = deepcopy(sys.ring_tilt_axis), brake = sys.brake_engaged[],
                 k = sys.k_mppt_ref[], kite = copy(sys.kite_pos))

function restore!(sys, s)
    for i in eachindex(sys.ring_tilt_axis)
        sys.ring_tilt_axis[i] .= s.tilt[i]
    end
    sys.brake_engaged[] = s.brake
    sys.k_mppt_ref[] = s.k
    sys.kite_pos .= s.kite
    return nothing
end

const PROBE_S  = 0.5      # sim seconds per stability probe
const VEL_CAP  = 1e4      # m/s — any node above this is a blow-up, not physics

"""Does the integrator survive PROBE_S seconds at this dt from the settled state?"""
function survives(u, sys, p, wf, dt; lin_damp)
    s = snapshot(sys)
    uc = copy(u)
    N = sys.n_total
    ok = true
    try
        run_canonical_sim!(uc, sys, p, wf, round(Int, PROBE_S / dt), dt;
                           lift_device=nothing, lin_damp=lin_damp, spoke=SPOKE)
    catch
        ok = false
    end
    restore!(sys, s)
    ok || return false
    all(isfinite, uc) || return false
    return maximum(abs, @view uc[(3N + 1):6N]) < VEL_CAP
end

"""Largest dt on a geometric ladder that still survives."""
function dt_threshold(u, sys, p, wf; lin_damp, lo=0.25, hi=64.0, per_octave=4)
    n = round(Int, per_octave * log2(hi / lo))
    last_ok = NaN
    for i in 0:n
        f = lo * (hi / lo)^(i / n)
        if survives(u, sys, p, wf, DT0 * f; lin_damp=lin_damp)
            last_ok = DT0 * f
        else
            return (last_ok, DT0 * f)      # (last surviving, first failing)
        end
    end
    return (last_ok, Inf)
end

# ══════════════════════════════════════════════════════════════════════════════
# Part 3 — what reducing zeta costs: rope-tension ringing at fixed dt
# ══════════════════════════════════════════════════════════════════════════════

const RING_S = 2.0

function ringing(u, sys, p, wf, dt; lin_damp)
    s = snapshot(sys)
    uc = copy(u)
    Ts = Float64[]
    every = max(round(Int, 0.005 / dt), 1)
    cb = function (uu, tt, st)
        st % every == 0 || return
        try
            T, _ = get_max_rope_tension(uu, sys, p)
            isfinite(T) && push!(Ts, T)
        catch
        end
    end
    ok = true
    try
        run_canonical_sim!(uc, sys, p, wf, round(Int, RING_S / dt), dt;
                           lift_device=nothing, lin_damp=lin_damp, spoke=SPOKE,
                           callback=cb)
    catch
        ok = false
    end
    restore!(sys, s)
    (!ok || length(Ts) < 10) && return (NaN, NaN)
    return (mean(Ts), std(Ts) / max(mean(Ts), 1e-9))
end

# ══════════════════════════════════════════════════════════════════════════════

function main()
    println("=== dt stability budget — what pins V11_DT? ===")
    @printf("V11_DT = %.4e s      initialization.jl:97  zeta = %.2f\n", DT0, ZETA_SRC)

    b = build(X12)
    @printf("\nreference design: %d-gon, %d rings, %d nodes, %d states, %d sub-segs\n",
            b.result.design.n_lines, b.result.n_rings, b.sys.n_total,
            length(b.u0), length(b.sys.sub_segs))

    rows  = analytic_audit(b.sys)
    worst = report_audit(rows)

    wf = wind_fn_for(b.p)
    @printf("\n  settling to operational state (%.0f s)... ", SETTLE_S); flush(stdout)
    t0 = time()
    u = KTD.settle_to_operational_state(b.sys, copy(b.u0), b.pc, SETTLE_S; wind_fn=wf)
    @printf("done in %.1f s\n", time() - t0)
    (u === nothing || any(!isfinite, u)) && (println("  settle failed"); return)

    orig = copy(b.sys.sub_segs)

    println("\n── Part 2: damping sweep → dt_crit proportionality ─────────────")
    println("  probe: $(PROBE_S) s from settled state; dt ladder 0.25–64 x DT0, 4/octave\n")
    @printf("  %-8s %-8s %-12s %-12s %-11s %s\n",
            "c-scale", "zeta", "dt_last_ok", "dt_first_bad", "vs DT0", "pred 1/zeta")
    sweep = NamedTuple[]
    for λ in [1.0, 0.5, 0.25, 0.1, 0.033]
        set_damping!(b.sys, orig, λ)
        ζ = ZETA_SRC * λ
        ok, bad = dt_threshold(u, b.sys, b.pc, wf; lin_damp=0.05)
        push!(sweep, (; λ, ζ, ok, bad))
        @printf("  %-8.3g %-8.3f %-12.3e %-12.3e x%-10.2f %s\n",
                λ, ζ, ok, bad, ok / DT0,
                isempty(sweep) ? "" : @sprintf("x%.2f", sweep[1].ok / DT0 / λ))
    end
    set_damping!(b.sys, orig, 1.0)

    println("\n  proportionality test (dt_crit should scale as 1/zeta while damper binds):")
    base = sweep[1]
    for s in sweep
        pred = base.ok / s.λ
        @printf("    zeta=%-6.3f  measured=%.3e  predicted=%.3e  ratio=%.2f\n",
                s.ζ, s.ok, pred, s.ok / pred)
    end
    @printf("  spring bound (damper-independent floor) = %.3e\n", worst.dt_spring)

    println("\n── Part 3: cost of reducing zeta — ringing at fixed dt=DT0 ────")
    @printf("  %-8s %-8s %14s %14s\n", "c-scale", "zeta", "T_mean[N]", "T_cv (std/mean)")
    ring = NamedTuple[]
    for λ in [1.0, 0.5, 0.25, 0.1, 0.033]
        set_damping!(b.sys, orig, λ)
        m, cv = ringing(u, b.sys, b.pc, wf, DT0; lin_damp=0.05)
        push!(ring, (; λ, ζ = ZETA_SRC * λ, m, cv))
        @printf("  %-8.3g %-8.3f %14.2f %14.4f\n", λ, ZETA_SRC * λ, m, cv)
    end
    set_damping!(b.sys, orig, 1.0)

    out = joinpath(@__DIR__, "results", "dt_stability_budget.csv")
    mkpath(dirname(out))
    open(out, "w") do io
        println(io, "section,zeta,c_scale,dt_last_ok,dt_first_bad,T_mean,T_cv")
        println(io, "analytic_worst,$(ZETA_SRC),1.0,$(worst.dt_bind),,,")
        println(io, "analytic_spring_floor,$(ZETA_SRC),1.0,$(worst.dt_spring),,,")
        for s in sweep
            println(io, "sweep,$(s.ζ),$(s.λ),$(s.ok),$(s.bad),,")
        end
        for r in ring
            println(io, "ringing,$(r.ζ),$(r.λ),,,$(r.m),$(r.cv)")
        end
    end
    println("\n  Saved: $out")
end

main()
