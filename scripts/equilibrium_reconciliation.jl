#!/usr/bin/env julia
# scripts/equilibrium_reconciliation.jl
# Task 1 from figure-review: catalogue vs wind_sweep discrepancy
# Quick version: standard settle vs kickstart, single-duration capture

using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames, JSON3
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const DT    = ControlMapHunt.DT
const WIND  = 11.0
const SP    = SpokeParams(enabled=true)
const SIM_S = 15.0  # short post-settle — just enough to stabilise

# Only the three designs in the discrepancy report
const DESIGNS = [
    (blade=0.90, k=6.0, r_bot=1.30, label="0.90·k6 r1.30", cat_P=81, cat_ω=168, cat_FoS=11.3, ws_P=204, ws_ω=323, ws_FoS=6.4),
    (blade=0.95, k=4.0, r_bot=1.30, label="0.95·k4 r1.30", cat_P=199, cat_ω=257, cat_FoS=5.2, ws_P=163, ws_ω=288, ws_FoS=3.9),
    (blade=1.10, k=4.0, r_bot=1.30, label="1.10·k4 r1.30", cat_P=297, cat_ω=272, cat_FoS=2.3, ws_P=297, ws_ω=391, ws_FoS=5.3),
]

OUT_CSV = joinpath(@__DIR__, "..", "figures", "data", "equilibrium_090k6.csv")
OUT_MD  = joinpath(@__DIR__, "..", "docs", "outreach", "equilibrium-reconciliation.md")
mkpath(dirname(OUT_CSV))
mkpath(dirname(OUT_MD))

function sim_and_capture(sys, u_start, p, wf, k::Float64)
    """Run settle + 15s MPPT, return (P_kw, ω_rpm, FoS)."""
    u = copy(u_start)
    sys.k_mppt_ref[] = k
    N = sys.n_total; Nr = sys.n_ring

    n_steps = round(Int, SIM_S / DT)
    local result = (0.0, 0.0, Inf)

    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=SP,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing;
                    brake_engaged=sys.brake_engaged[])
                ω = ef.base.omega_hub * 60 / (2π)
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos = isempty(airborne) ? Inf : minimum(airborne)
                result = (ef.base.P_kw, ω, fos)
            end
        end)
    return result
end

function kickstart_settle(sys, u0, p, wf, k::Float64)
    """Settle to equilibrium, inject ω=30 rad/s, spin up, then re-engage generator."""
    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
    N = sys.n_total; Nr = sys.n_ring

    omega_kick = 30.0
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
    end
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]
            tang ./= norm(tang)
            v_orb = omega_kick * r
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= v_orb .* tang
        end
    end

    sys.k_mppt_ref[] = 0.0
    n_spin = round(Int, 10.0 / DT)
    run_canonical_sim!(u, sys, p, wf, n_spin, DT;
        lift_device=nothing, lin_damp=0.05, spoke=SP)

    return u
end

println("════════════════════════════════════════════════")
println("Equilibrium Reconciliation — quick version")
println("════════════════════════════════════════════════")

# Export P_aero(ω) and P_gen(ω) for 0.90·k6
println("\n── Exporting P_aero/P_gen curve ──")
fn = ControlMapHunt.v10_tight_builder(blade_scale=0.90)
sys, u0, p, _ = Base.invokelatest(fn)
rho, R, elev = p.rho, p.rotor_radius, p.elevation_angle

open(OUT_CSV, "w") do io
    println(io, "omega_rpm,P_aero_kW,P_gen_kW,net_kW")
    for ω_rpm in 0:5:450
        ω_rad = ω_rpm * 2π / 60
        λ = ω_rad * R / WIND
        cp = cp_at_tsr(λ)
        P_aero = 0.5 * rho * WIND^3 * (π*R^2) * cp * cos(elev)^2.65 / 1000.0
        P_gen = 6.0 * ω_rad^3 / 1000.0
        println(io, "$(ω_rpm),$(round(P_aero, digits=2)),$(round(P_gen, digits=2)),$(round(P_aero-P_gen, digits=2))")
    end
end
println("  → $OUT_CSV")

# Test each design
lines = String[]
push!(lines, "# Equilibrium Reconciliation")
push!(lines, "")
push!(lines, "**Script:** `scripts/equilibrium_reconciliation.jl`")
push!(lines, "**Wind:** $(WIND) m/s, $(SIM_S)s post-settle MPPT")
push!(lines, "")
push!(lines, "## Results")
push!(lines, "")
push!(lines, "| Design | Method | P (kW) | ω (rpm) | FoS | Matches |")
push!(lines, "|--------|--------|--------|---------|-----|---------|")

for d in DESIGNS
    println("\n── $(d.label) ──")
    fn = ControlMapHunt.v10_tight_builder(blade_scale=d.blade, r_bottom_scale=d.r_bot)
    sys, u0, p, _ = Base.invokelatest(fn)
    wf_func(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Method A: standard settle (low-ω)
    u_std = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf_func)
    P_s, ω_s, FoS_s = sim_and_capture(sys, u_std, p, wf_func, d.k)
    cat_match = abs(P_s - d.cat_P) < max(5.0, d.cat_P*0.1) ? "catalog" : ""
    ws_match = abs(P_s - d.ws_P) < max(5.0, d.ws_P*0.1) ? "wind_sweep" : ""
    @printf("  standard:  P=%.0f kW  ω=%.0f rpm  FoS=%.1f  %s %s\n", P_s, ω_s, FoS_s, cat_match, ws_match)
    push!(lines, @sprintf("| %s | standard | %.0f | %.0f | %.1f | %s %s |", d.label, P_s, ω_s, FoS_s, cat_match, ws_match))

    # Method B: kickstart (high-ω)
    u_ks = kickstart_settle(sys, u0, p, wf_func, d.k)
    P_k, ω_k, FoS_k = sim_and_capture(sys, u_ks, p, wf_func, d.k)
    cat_match = abs(P_k - d.cat_P) < max(5.0, d.cat_P*0.1) ? "catalog" : ""
    ws_match = abs(P_k - d.ws_P) < max(5.0, d.ws_P*0.1) ? "wind_sweep" : ""
    @printf("  kickstart: P=%.0f kW  ω=%.0f rpm  FoS=%.1f  %s %s\n", P_k, ω_k, FoS_k, cat_match, ws_match)
    push!(lines, @sprintf("| %s | kickstart | %.0f | %.0f | %.1f | %s %s |", d.label, P_k, ω_k, FoS_k, cat_match, ws_match))
end

# Provenance
push!(lines, "")
push!(lines, "## Provenance")
push!(lines, "")

cat_path = joinpath(dirname(@__DIR__), "scripts", "results", "control_maps", "catalog_corrected_geo.csv")
ks_path  = joinpath(dirname(@__DIR__), "scripts", "results", "control_maps", "kickstart_sweep.csv")
cat_rows = countlines(cat_path) - 1
ks_rows  = countlines(ks_path) - 1
push!(lines, "- catalog_corrected_geo.csv: $(cat_rows) rows")
push!(lines, "- kickstart_sweep.csv: $(ks_rows) rows")

git_hash = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
push!(lines, "- git HEAD: `$(git_hash)`")
push!(lines, "")

open(OUT_MD, "w") do io
    for l in lines
        println(io, l)
    end
end

println("\n── Wrote $(OUT_MD) ──")
println("Done.")
