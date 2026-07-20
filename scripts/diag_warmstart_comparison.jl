#!/usr/bin/env julia
# scripts/diag_warmstart_comparison.jl
# Decision-rule diagnostic: compare warm-start vs full protocol on
# two reference designs. Outputs f_full, f_ws, ω for both.

using KiteTurbineDynamics, Printf

const SP = SpokeParams(enabled=false)
const P = params_v5_50kw()

function diag_one(label, x)
    println("=== $label ===")
    
    # Full protocol
    t0 = time()
    f_full = objective_v11(x, PROFILE_ELLIPTICAL, P; spoke=SP)
    t_full = time() - t0
    
    # Warm-start with k-bracket
    t0 = time()
    f_ws, k_ws, P_ws, FoS_ws, ω_ws, P_range, drift =
        warmstart_with_k_bracket(x, PROFILE_ELLIPTICAL, P; spoke=SP)
    t_ws = time() - t0
    
    # Also get ω from full protocol — need to capture it.
    # Re-run warm-start single-k to get ω_full for comparison.
    # We'll use the same k that the bracket picked.
    x_k = copy(x)
    x_k[15] = log10(k_ws)
    f_ws_single, P_s, FoS_s, ω_s, P_r, d = 
        objective_v11_warmstart(x_k, PROFILE_ELLIPTICAL, P; spoke=SP)
    
    # For full protocol ω, run a single-k eval and capture omega
    # (objective_v11 doesn't return ω, so we approximate from warm-start ω_eq)
    
    ratio = abs(f_full) > 1.0 && abs(f_ws) > 1.0 ? 
            max(abs(f_full), abs(f_ws)) / min(abs(f_full), abs(f_ws)) : 0.0
    
    @printf("  f_full   = %.2f  (%.0f s)\n", f_full, t_full)
    @printf("  f_ws     = %.2f  (%.0f s, k=%.0f)\n", f_ws, t_ws, k_ws)
    @printf("  P_ws     = %.1f kW  FoS_ws = %.2f\n", P_ws, FoS_ws)
    @printf("  ω_eq     = %.1f rad/s (%.0f rpm)\n", ω_ws, ω_ws * 60 / (2π))
    @printf("  P_range  = %.2f kW  drift = %s\n", P_range, drift)
    @printf("  ratio    = %.2f\n", ratio)
    println()
    
    return (f_full=f_full, f_ws=f_ws, k_ws=k_ws, ω_eq=ω_ws, P_ws=P_ws, 
            FoS_ws=FoS_ws, P_range=P_range, drift=drift, ratio=ratio)
end

function main()
    # Reference 1: 12-gon genome
    x12 = zeros(15)
    x12[1]=0.075; x12[2]=0.01; x12[3]=1.0; x12[4]=0.5; x12[5]=3.7
    x12[6]=2.0; x12[7]=2.5; x12[8]=12.0; x12[9]=0.0; x12[10]=8.0
    x12[11]=15.0; x12[12]=5.0; x12[13]=0.5; x12[14]=0.3; x12[15]=1.0

    r1 = diag_one("12-gon (k=10, blade_scale=0.5/0.3)", x12)
    
    # Reference 2: triangle-like
    x_tri = zeros(15)
    x_tri[1]=0.06; x_tri[2]=0.01; x_tri[3]=1.0; x_tri[4]=0.5
    x_tri[5]=2.99; x_tri[6]=1.5; x_tri[7]=2.99; x_tri[8]=3.0
    x_tri[9]=-0.11; x_tri[10]=1.0; x_tri[11]=25.0; x_tri[12]=4.0
    x_tri[13]=1.0; x_tri[14]=0.88; x_tri[15]=log10(2.0)

    r2 = diag_one("Triangle (k=2, blade_scale=1.0/0.88)", x_tri)
    
    # Decision rule
    println("=== DECISION ===")
    for (name, r) in [("12-gon", r1), ("Triangle", r2)]
        if r.ratio < 1.5
            verdict = "FIRE tonight, tighten test to ratio < $(round(r.ratio * 1.3, digits=1))"
        elseif r.ratio < 3.0
            verdict = "FIRE tonight + 5 dual-protocol anchors (~75 min extra)"
        else
            verdict = "DO NOT FIRE warm-start. Fallback: full-protocol anchors."
        end
        println("  $name: ratio=$(round(r.ratio, digits=2)) → $verdict")
    end
end

main()
