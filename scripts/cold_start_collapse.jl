"""
Cold-Start Collapse Diagnostic
=================================
Tests whether the simulator correctly drops the hub under no-lift / low-wind
conditions (cold start from omega = 0, no artificial spin-up).

Scenarios:
  A) NoLift,     v = 5.0 m/s  — no kite, rotor starts at rest
  B) NoLift,     v = 3.0 m/s  — below any meaningful aerodynamic threshold
  C) SingleKite, v = 3.5 m/s  — kite present but below its 4 m/s design wind

Output: scripts/results/collapse/cold_start_collapse.csv
"""

using KiteTurbineDynamics, Printf, CSV, DataFrames

OUT_DIR = joinpath(@__DIR__, "results", "collapse")
mkpath(OUT_DIR)

p_base   = params_10kw()
sys, u0  = build_kite_turbine_system(p_base)
N        = sys.n_total
Nr       = sys.n_ring
hub_gid  = sys.ring_ids[Nr]

T_SIM    = 10.0    # hub falls ~1.2 m/s at cold start; 10s shows full collapse
# Empirically-determined stability limit for simulate() in the cold-start
# (zero orbital velocity) case: dt=5e-5 is stable, dt=7e-5 is not.
# The sweep scripts use dt=5e-3 which is stable during normal operation
# because orbital damping preserves the rope nodes' tangential velocities.
# In the cold-start case (omega≈0 everywhere) the orbital component is zero
# and effective damping is identical to the settle function, but the net
# rope force imbalance on the hub (≈1100 N) is still present and becomes
# numerically amplified at dt > 5e-5.
DT       = 5e-5
CHUNK    = 200           # steps per simulate call → 0.01 s wall resolution
N_CHUNKS = round(Int, T_SIM / (DT * CHUNK))

# ── Re-use make_params from the sweep script ─────────────────────────────────
function make_params(base::SystemParams; v_wind=base.v_wind_ref, k_mppt=base.k_mppt)
    SystemParams(
        base.rho, v_wind, base.h_ref,
        base.elevation_angle, base.lifter_elevation,
        base.rotor_radius, base.tether_length,
        base.trpt_hub_radius, base.trpt_rL_ratio,
        base.n_lines, base.tether_diameter, base.e_modulus,
        base.n_rings, base.m_ring,
        base.n_blades, base.m_blade,
        base.cp, base.i_pto,
        k_mppt,
        base.p_rated_w, base.β_min, base.β_max, base.β_rate_max, base.kp_elev,
        base.EA_back_line, base.c_back_line, base.back_anchor_fwd_x
    )
end

# ── Helpers ───────────────────────────────────────────────────────────────────
hub_x(u)     = u[3*(hub_gid-1)+1]
hub_z(u)     = u[3*(hub_gid-1)+3]
elev_deg(u)  = rad2deg(atan(hub_z(u), hub_x(u)))
omega_hub(u) = u[6N + Nr + Nr]
function total_twist_deg(u)
    a = @view u[6N+1 : 6N+Nr]
    rad2deg(sum(i -> mod(a[i+1]-a[i]+pi, 2pi)-pi, 1:Nr-1))
end

function approx_T_max(u, p)
    T = 0.0
    for s in 1:p.n_rings
        r_lo = s == 1 ? sys.ring_ids[1] : sys.ring_ids[s-1]
        r_hi = sys.ring_ids[s]
        p1 = @view u[3*(r_lo-1)+1 : 3*(r_lo-1)+3]
        p2 = @view u[3*(r_hi-1)+1 : 3*(r_hi-1)+3]
        L_cur  = sqrt(sum((p2 .- p1).^2))
        L_rest = p.tether_length / p.n_rings
        strain = max((L_cur - L_rest) / L_rest, 0.0)
        T = max(T, p.e_modulus * pi * (p.tether_diameter/2)^2 * strain)
    end
    T
end

function shear_wind(v)
    (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p_base.h_ref)^(1.0/7.0)
        [v * sh, 0.0, 0.0]
    end
end

rows = DataFrame(
    scenario=String[], t=Float64[],
    hub_x=Float64[], hub_z=Float64[], elev_deg=Float64[],
    omega_hub=Float64[], twist_deg=Float64[], T_max=Float64[]
)

function run_scenario!(label, v_wind, lift_dev)
    p   = make_params(p_base; v_wind=v_wind)
    wfn = shear_wind(v_wind)
    dev_str = lift_dev === nothing ? "NoLift" : string(typeof(lift_dev))
    println("\n── $label  (v=$(v_wind) m/s, device=$dev_str) ──")
    print("  settling… ")
    u = settle_to_equilibrium(sys, copy(u0), p; lift_device=lift_dev)
    @printf "done  hub=(%.2f, %.2f) m  elev=%.1f°\n" hub_x(u) hub_z(u) elev_deg(u)

    t = 0.0
    collapsed = false
    for chunk in 0:N_CHUNKS
        push!(rows, (label, t, hub_x(u), hub_z(u), elev_deg(u),
                     omega_hub(u), total_twist_deg(u), approx_T_max(u, p)))
        chunk == N_CHUNKS && break
        u = simulate(sys, u, p, wfn; n_steps=CHUNK, dt=DT, lift_device=lift_dev)
        t += DT * CHUNK
        # Early-exit on collapse (hub drops below 3 m) or blowup
        if hub_z(u) < 3.0
            push!(rows, (label, t, hub_x(u), hub_z(u), elev_deg(u),
                         omega_hub(u), total_twist_deg(u), approx_T_max(u, p)))
            println("  *** COLLAPSE at t=$(round(t,digits=2))s: hub_z=$(round(hub_z(u),digits=2))m ***")
            collapsed = true
            break
        end
        if !isfinite(hub_z(u))
            println("  *** BLOWUP at t=$(round(t,digits=2))s (non-finite hub_z) ***")
            collapsed = true
            break
        end
    end
    if !collapsed
        println("  t=$(round(t,digits=1))s: hub=($(round(hub_x(u),digits=2)), $(round(hub_z(u),digits=2)))m" *
                "  elev=$(round(elev_deg(u),digits=1))°" *
                "  ω=$(round(omega_hub(u),digits=3)) rad/s" *
                "  twist=$(round(total_twist_deg(u),digits=1))°")
    end
end

# ── Scenarios ─────────────────────────────────────────────────────────────────
run_scenario!("NoLift_v5",       5.0, nothing)
run_scenario!("NoLift_v3",       3.0, nothing)

kite = single_kite_sized(p_base, p_base.rho, 11.0)
run_scenario!("SingleKite_v3p5", 3.5, kite)

# ── Save ──────────────────────────────────────────────────────────────────────
csv_path = joinpath(OUT_DIR, "cold_start_collapse.csv")
CSV.write(csv_path, rows)
println("\nSaved: $csv_path  ($(nrow(rows)) rows)")

println("\n── Hub altitude summary ─────────────────────────────────────────────────")
@printf "%-22s  %8s  %8s  %8s  %s\n" "Scenario" "hub_z₀m" "hub_z₃₀m" "Δhub_z" "Status"
for scen in unique(rows.scenario)
    sub = rows[rows.scenario .== scen, :]
    z0  = sub.hub_z[1]
    zf  = sub.hub_z[end]
    dz  = zf - z0
    flag = abs(dz) > 0.5 ? (dz < 0 ? "DROPPING ↓" : "RISING ↑") : "stable ≈"
    @printf "%-22s  %8.2f  %8.2f  %8.2f  %s\n" scen z0 zf dz flag
end
