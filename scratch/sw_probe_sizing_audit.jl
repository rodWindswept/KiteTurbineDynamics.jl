# scratch/sw_probe_sizing_audit.jl — software-worker, 2026-10-02
#
# Audits the campaign record for the silent sizing-solve failure identified in
# trpt_optimization.jl:325 (a failed/non-finite `solve_equilibrium_self_consistent`
# is converted to ω_num = 0.0 and the machine is sized at max-thrust anyway).
#
# Question: how many of the ~933 recorded candidates actually hit that fallback,
# and did it inflate their mass / affect their status in the record?
#
# Method: re-run the SIZING ONLY (decode + size_beams_closed_form, no settle, no
# ODE) over every genome in the three island telemetry files, reproducing the
# runner's exact decode (round x[4]→n_lines 3..16, x[6]→rotor 1..3) and cfg.
# `size_beams_closed_form` stores the clamped ω_num in BeamSizing.omega_eq, so
# omega_eq == 0.0 flags the fallback.  This is bit-comparable to what the
# campaign actually did: the code has not changed since it finished this morning.
#
# USAGE: scripts/ktd-julia scratch/sw_probe_sizing_audit.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const LENGTH = 18.8

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p = params_at_length(LENGTH)

cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=11.0, p_floor_kw=KW, fos_target=2.5, fos_hard=2.5,
    min_wall_m=2e-3, rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
)

function size_one(x::Vector{Float64})
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    dec = design_from_vector_v10(
        xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    sizing = KTD.size_beams_closed_form(dec, p, cfg)
    return sizing.omega_eq
end

const RES = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate")

function run_audit()
    n_rows = 0
    n_failed = 0
    failed = Tuple{Int,Int,Int,Float64,Float64,Float64,String}[]  # island,gen,idx,blade,omega,fitness,status
    for island in 1:3
        f = joinpath(RES, "island_$island", "telemetry.csv")
        lines = readlines(f)
        for ln in lines
            startswith(ln, "#") && continue
            startswith(ln, "island,gen,") && continue  # header
            parts = split(strip(ln), ",")
            length(parts) >= 31 || continue
            n_rows += 1
            x = [parse(Float64, parts[j]) for j in 22:31]
            gen = parse(Int, parts[2])
            idx = parse(Int, parts[3])
            fitness = parse(Float64, parts[4])
            status = parts[5]
            blade = parse(Float64, parts[19])   # blade_scale_top (x[9])
            omega = size_one(x)
            if !isfinite(omega) || omega <= 0.0
                n_failed += 1
                push!(failed, (island, gen, idx, blade, omega, fitness, status))
            end
        end
    end
    return n_rows, n_failed, failed
end

n_rows, n_failed, failed = run_audit()

println("=== sizing-solve audit (decode + size_beams_closed_form only) ===")
println("rows scanned: $n_rows")
println("failed solve (omega_eq <= 0 or non-finite): $n_failed  (",
    round(100 * n_failed / n_rows, digits=1), "%)")
println()
println("failed candidates (island, gen, idx, blade_scale_top, omega_eq, fitness, status):")
for r in failed
    @printf("  island %d  gen %3d  idx %2d  blade %.4f  omega %.4f  fitness %s  status %s\n",
        r[1], r[2], r[3], r[4], r[5], r[6], r[7])
end

# Winner's own sizing (bank-derate best_vector.csv)
win = joinpath(RES, "best_vector.csv")
wv = [parse(Float64, s) for s in split(strip(read(win, String)), ",")]
womega = size_one(wv)
println()
@printf("winner (bank-derate best_vector.csv) omega_eq = %.6f  -> %s\n",
    womega, (isfinite(womega) && womega > 0.0) ? "solve OK" : "FAILED SOLVE")
