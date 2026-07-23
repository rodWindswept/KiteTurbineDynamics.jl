#!/usr/bin/env julia
# Memory diagnosis for full-protocol ODE on 12-gon at k=60.
# Profiles allocation per phase to locate the 38GB source.

using KiteTurbineDynamics, Printf, Base.GC

const X12 = [0.075,0.01,1.0,0.5,3.7,2.0,2.5,12.0,0.0,8.0,15.0,5.0,0.5,0.3,log10(60.0)]
const BEAM = KiteTurbineDynamics.PROFILE_ELLIPTICAL

function alloc_since_mb(start_num)
    end_num = Base.gc_alloc_count(Base.gc_num())
    return (end_num.allocd - start_num.allocd) / 1e6
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
    N = sys.n_total
    Nr = sys.n_ring

    # Phase 1: settle_to_operational_state (60s)
    println("Phase 1: settle_to_operational_state (60s, $(round(Int,60/dt)) steps)")
    GC.gc()
    sn1 = Base.gc_alloc_count(Base.gc_num())
    u_start = copy(u0)
    u = KiteTurbineDynamics.settle_to_operational_state(sys, u_start, pc, 60.0; wind_fn=wf)
    println("  done — $(round(alloc_since_mb(sn1))) MB")

    # Phase 2: kickstart (2s at negative k)
    println("Phase 2: kickstart (2s, $(round(Int,2/dt)) steps)")
    GC.gc()
    sn2 = Base.gc_alloc_count(Base.gc_num())
    orig_k = sys.k_mppt_ref[]
    sys.k_mppt_ref[] = -60.0
    ks = round(Int, 2.0 / dt)
    KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, ks, dt;
        lin_damp=0.05, spoke=spoke)
    sys.k_mppt_ref[] = orig_k
    println("  done — $(round(alloc_since_mb(sn2))) MB")

    # Phase 3: window (40s, 1Hz sampling, discard first 10s)
    println("Phase 3: measurement window (30s sampling, $(round(Int,40/dt)) steps)")
    total_n = round(Int, 40.0 / dt)
    se = round(Int, 1.0 / dt)
    dn = round(Int, 10.0 / dt)
    Ps = Float64[]; FoSs = Float64[]
    GC.gc()
    sn3 = Base.gc_alloc_count(Base.gc_num())
    cb_count = Ref(0)
    function cb(uc, tc, s)
        s < dn && return
        s % se != 0 && return
        cb_count[] += 1
        ef = KiteTurbineDynamics.capture_extended(uc, sys, pc, tc, wf, nothing;
            brake_engaged=false)
        push!(Ps, ef.base.P_kw)
        air = Float64[v for v in ef.ring_fos[2:end] if isfinite(v) && v > 0]
        push!(FoSs, isempty(air) ? Inf : minimum(air))
    end
    KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, total_n, dt;
        lin_damp=0.05, spoke=spoke, callback=cb)
    alloc_mb = alloc_since_mb(sn3)

    n = length(Ps)
    P_mean = n > 0 ? mean(Ps) : 0.0
    FoS_min = n > 0 && !all(isinf.(FoSs)) ? minimum(FoSs[isfinite.(FoSs)]) : Inf
    per_sample = n > 0 ? alloc_mb / n : 0.0

    println("  done — $(round(alloc_mb)) MB, $(cb_count[]) callbacks, $(per_sample:.1f) MB/sample")
    println()
    println("Window: P_mean=$(round(P_mean,digits=1))kW  FoS_min=$(round(FoS_min,digits=3))")
    println()
    if per_sample > 50
        println("FINDING: capture_extended in callback allocates >50 MB/sample.")
        println("  Running ring_element_analysis on $(N) nodes × 30 samples = $(round(alloc_mb)) MB")
        println("  FIX: if warmstart path is ≤2GB, the excess is ring_element_analysis")
        println("  inside capture_extended.  Option: compute FoS on sample subset only.")
    else
        println("FINDING: per-sample allocation ", round(Int, per_sample), " MB — reasonable.")
        println("  38GB likely comes from settle_to_operational_state accumulation.")
    end
end

main()
