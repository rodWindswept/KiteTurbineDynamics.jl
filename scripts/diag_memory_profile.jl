#!/usr/bin/env julia
# Memory diagnosis for full-protocol ODE on 12-gon at k=60.
# Simplified: report per-phase wall time and GC stats.

using KiteTurbineDynamics, Printf, Statistics

const X12 = [0.075,0.01,1.0,0.5,3.7,2.0,2.5,12.0,0.0,8.0,15.0,5.0,0.5,0.3,log10(60.0)]
const BEAM = KiteTurbineDynamics.PROFILE_ELLIPTICAL

function gc_delta(start_gc)
    end_gc = Base.gc_num()
    allocd = end_gc.allocd - start_gc.allocd
    gctime = end_gc.total_time + end_gc.pause - start_gc.total_time - start_gc.pause
    return allocd / 1e6, gctime / 1e9  # MB, seconds
end

function main()
    println("=== Memory Diagnosis: Full Protocol ODE — 12-gon, k=60 ===\n")

    p = KiteTurbineDynamics.params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    result = KiteTurbineDynamics.design_from_vector_v10(
        X12[1:14], BEAM, p; power_W=50000.0, v_rated=11.0)
    result.n_active == 0 && error("no active rings")
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, 60.0)

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    dt = KiteTurbineDynamics.V11_DT

    # Phase 1: settle_to_operational_state (60s)
    n_steps = round(Int, 60/dt)
    println("Phase 1: settle_to_operational_state (60s, $n_steps steps)")
    GC.gc()
    gc0 = Base.gc_num()
    t0 = time()
    u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
    t1 = time()
    alloc_mb, gc_s = gc_delta(gc0)
    @printf "  done in %.1fs — %.0f MB allocated (GC: %.1fs)\n" (t1-t0) alloc_mb gc_s

    # Phase 2: kickstart (2s at negative k)
    n_steps = round(Int, 2/dt)
    println("Phase 2: kickstart (2s, $n_steps steps)")
    GC.gc()
    gc0 = Base.gc_num()
    t0 = time()
    orig_k = sys.k_mppt_ref[]
    sys.k_mppt_ref[] = -60.0
    ks = round(Int, 2.0 / dt)
    KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, ks, dt; lin_damp=0.05, spoke=spoke)
    sys.k_mppt_ref[] = orig_k
    t1 = time()
    alloc_mb, gc_s = gc_delta(gc0)
    @printf "  done in %.1fs — %.0f MB allocated (GC: %.1fs)\n" (t1-t0) alloc_mb gc_s

    # Phase 3: measurement window (40s, sample last 30s at 1Hz)
    total_n = round(Int, 40.0 / dt)
    se = round(Int, 1.0 / dt)
    dn = round(Int, 10.0 / dt)
    println("Phase 3: window (40s, $(total_n) steps, $(30) samples)")
    Ps = Float64[]; FoSs = Float64[]
    GC.gc()
    gc0 = Base.gc_num()
    t0 = time()
    function cb(uc, tc, s)
        s < dn && return; s % se != 0 && return
        ef = KiteTurbineDynamics.capture_extended(uc, sys, pc, tc, wf, nothing; brake_engaged=false)
        push!(Ps, ef.base.P_kw)
        air = Float64[v for v in ef.ring_fos[2:end] if isfinite(v) && v > 0]
        push!(FoSs, isempty(air) ? Inf : minimum(air))
    end
    KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, total_n, dt; lin_damp=0.05, spoke=spoke, callback=cb)
    t1 = time()
    alloc_mb, gc_s = gc_delta(gc0)

    n = length(Ps)
    P_mean = n > 0 ? mean(Ps) : 0.0
    FoS_min = n > 0 && !all(isinf.(FoSs)) ? minimum(FoSs[isfinite.(FoSs)]) : Inf
    per_sample = n > 0 ? alloc_mb / n : 0.0

    @printf "  done in %.1fs — %.0f MB allocated (GC: %.1fs, %d samples, %.0f MB/sample)\n" (t1-t0) alloc_mb gc_s n per_sample
    println()
    @printf "Window: P_mean=%.1f kW  FoS_min=%.3f\n" P_mean FoS_min
    println()

    if per_sample > 100
        println("FINDING: >100 MB/sample in callback (capture_extended + ring_element_analysis)")
        println("  Window callback allocates $(round(Int, per_sample)) MB per 1Hz sample.")
        println("  For 3-phase ODE ~40 samples: this accounts for bulk of 38GB.")
        println("  FIX: compute FoS every N samples (e.g. 10), not every sample.")
    else
        println("FINDING: per-sample $(round(Int, per_sample)) MB — not the dominant allocator.")
        println("  The 38GB is from settle/kick steps accumulation, not the window callback.")
    end
end

main()
