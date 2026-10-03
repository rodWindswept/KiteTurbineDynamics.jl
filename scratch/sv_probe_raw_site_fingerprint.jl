#!/usr/bin/env julia --project=.
#= sv_probe_raw_site_fingerprint.jl — @software-validator, 2026-10-02.

BASELINE / AFTER PIN for the wind-normal Betz ceiling change.

The ceiling edit (objective_evaluator.jl) must be INVISIBLE to the physics: the
shared helper `main_rotor_swept_area` stays raw for its four call sites
(ring_forces.jl:205 hub thrust, :220 disc POWER, :285 expansion T_est,
initialization.jl:1323 bridle preload).  `test_betz_ceiling_projection.jl`
testset 5 pins the HELPER's value, which is necessary but not sufficient: a
site-level edit (e.g. multiplying a projection at :220) leaves the helper
untouched and testset 5 still green.

This probe evaluates the actual site expressions and prints every input at
%.17g, so `diff before.txt after.txt` is empty iff the four sites are
bit-identical.  It also names which sites FIRE on each machine.

Usage:  scripts/ktd-julia scratch/sv_probe_raw_site_fingerprint.jl > /tmp/before.txt
=#

using KiteTurbineDynamics, Printf, LinearAlgebra

const KTD = KiteTurbineDynamics
const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))   # decode_winner, CLI-guarded

const KW = 5.0
const L18 = 18.8

# v13 machines + a rotor-count campaign winner, so the expansion branch
# (ring_forces.jl:285, and the per-rotor gate's expansion arm) is exercised —
# NEITHER machine in test_betz_ceiling_projection.jl has an expansion rotor.
const CASES = [
    "island3_bankderate" => "v13_5kw_masslift_len18.8_rotorcount_bankderate",
    "island1_bankderate" => "v13_5kw_masslift_len18.8_rotorcount",
    "rotorcount_void"    => "archive_void_20260825_rotorcount",
    "masslift_len18.8"   => "v13_5kw_masslift_len18.8",
]

read_genome(path) = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]

# Deterministic, unsheared wind: isolates the area terms from the wind model.
wind_fn(_pos, _t) = [11.0, 0.0, 0.0]

function fingerprint(label::String, dir::String)
    csv = joinpath(ROOT, "scripts", "results", dir, "best_vector.csv")
    println("="^78)
    @printf("MACHINE %-20s  %s\n", label, isfile(csv) ? dir : "MISSING: $dir")
    isfile(csv) || return
    x = read_genome(csv)
    d = decode_winner(x; L=L18, KW=KW)
    sys, u0, _pc = KTD.build_system_from_v10(
        d.dec, 1.0, d.k_mp; tether_diameter=d.p.tether_diameter, base_params=d.p,
    )
    p = d.p
    N = sys.n_total
    Nr = sys.n_ring
    @printf("  n_total=%d  n_ring=%d  n_expansion_rotors=%d\n",
        N, Nr, length(sys.expansion_rotors))

    # ── The scalar every one of the four sites multiplies ───────────────────
    A_raw = KTD.main_rotor_swept_area(sys)
    @printf("  SITE-INPUT main_rotor_swept_area(sys) = %.17g\n", A_raw)
    @printf("  SITE-INPUT radius             = %.17g\n", sys.rotor.radius)
    @printf("  SITE-INPUT blade_hub_radius   = %.17g\n", sys.rotor.blade_hub_radius)
    @printf("  SITE-INPUT bank_angle_deg     = %.17g\n", sys.rotor.bank_angle_deg)
    @printf("  SITE-INPUT elevation_angle    = %.17g\n", p.elevation_angle)

    u = copy(u0)
    # The builder returns a COLD state (omega block all zero) — ct_at_tsr(0) = 0
    # would zero every site term and the pin would be vacuous.  Pin the ring
    # rates at a representative operating speed (the measured island-3 point is
    # 13.4 rad/s; 11.0 exercises the same ct/cp branch), with the geometry from
    # the builder untouched.
    omega_pin = 11.0
    u[(6N + Nr + 1):(6N + 2Nr)] .= omega_pin
    omega = u[(6N + Nr + 1):(6N + 2Nr)]
    @printf("  SITE-INPUT omega[hub_ri]      = %.17g\n",
        omega[(sys.nodes[sys.rotor.node_id]::RingNode).ring_idx])

    hub_gid = sys.rotor.node_id
    hub_pos = u[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    v_hub_mag = 11.0 * sys.rotor.wind_factor
    elev_live = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
    @printf("  SITE-INPUT elev_live(atan)    = %.17g\n", elev_live)

    lifter = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)

    forces = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    KTD.compute_ring_forces!(forces, torques, u, omega, sys, p, wind_fn, 0.0, lifter, nothing)

    # ring_forces.jl:205 hub thrust term (cos(elev)^2.0, deliberately NO bank)
    lam = abs(omega[(sys.nodes[hub_gid]::RingNode).ring_idx]) * sys.rotor.radius / v_hub_mag
    thrust_205 = 0.5 * p.rho * v_hub_mag^2 * A_raw * KTD.ct_at_tsr(lam) * cos(elev_live)^2.0
    @printf("  SITE :205 thrust_term       = %.17g\n", thrust_205)
    @printf("  SITE :205 ct_at_tsr         = %.17g\n", KTD.ct_at_tsr(lam))

    # ring_forces.jl:220 disc POWER term (cos(elev)^2.65 * cosd(bank)^2.65)
    cp = KTD.cp_at_tsr(lam)
    P_220 = 0.5 * p.rho * v_hub_mag^3 * A_raw * cp *
            cos(elev_live)^2.65 * cosd(sys.rotor.bank_angle_deg)^2.65
    @printf("  SITE :220 cp_at_tsr         = %.17g\n", cp)
    @printf("  SITE :220 P_aero            = %.17g\n", P_220)
    @printf("  SITE :220 cosd(bank)^2.65   = %.17g\n",
        cosd(sys.rotor.bank_angle_deg)^2.65)

    # ring_forces.jl:285 expansion T_est (fires only with expansion rotors)
    T_est_285 = 0.5 * p.rho * v_hub_mag^2 * A_raw * KTD.ct_at_tsr(lam) * cos(elev_live)^2.0
    @printf("  SITE :285 T_est (raw term)  = %.17g   [%s]\n", T_est_285,
        isempty(sys.expansion_rotors) ? "NOT EXERCISED" : "EXERCISED")

    # initialization.jl:1323 bridle-preload cut
    T_1323 = 0.5 * p.rho * v_hub_mag^2 * A_raw * KTD.ct_at_tsr(lam) * cos(p.elevation_angle)^2
    @printf("  SITE init:1323 T_thrust     = %.17g\n", T_1323)

    # ── End-to-end: the force/torque/load-path output of the four sites ─────
    fmax = 0.0
    for f in forces
        fmax = max(fmax, norm(f))
    end
    @printf("  OUT forces_norm_max         = %.17g\n", fmax)
    s = 0.0
    for f in forces
        for k in 1:3
            s += abs(f[k])
        end
    end
    @printf("  OUT forces_abs_sum          = %.17g\n", s)
    for (i, tau) in enumerate(torques)
        @printf("  OUT torques[%d]              = %.17g\n", i, tau)
    end

    # ── Sensitivity demonstration (no src mutation): what each pinned value
    # becomes if the shared helper is projected in-helper — the exact
    # regression testset 5 guards.  A pin that cannot see this delta is
    # vacuous; these are the deltas to expect in the after-diff.
    cb = cosd(sys.rotor.bank_angle_deg)
    @printf("  SENS if helper gained cosd(bank):\n")
    @printf("       :205  %.17g -> %.17g   (ratio %.17g)\n", thrust_205, thrust_205 * cb, cb)
    @printf("       :220  %.17g -> %.17g   (ratio %.17g)\n", P_220, P_220 * cb, cb)
    @printf("       :285  %.17g -> %.17g   (ratio %.17g)\n", T_est_285, T_est_285 * cb, cb)
    @printf("       :1323 %.17g -> %.17g   (ratio %.17g)\n", T_1323, T_1323 * cb, cb)
    @printf("       forces_norm_max %.17g -> %.17g\n", fmax, fmax * cb)

    lc = try
        KTD.lift_chain_design(sys, p, lifter, hub_pos; omega_eq=omega[1])
    catch e
        @warn "lift_chain_design raised" exception = (e, catch_backtrace())
        nothing
    end
    if lc === nothing
        println("  OUT lift_chain_design       = nothing")
    else
        @printf("  OUT lift_chain_design_len   = %d\n", length(lc))
        for (i, v) in enumerate(lc)
            if v isa AbstractVector
                @printf("  OUT lift_chain[%d]           = vec(norm %.17g, sum %.17g)\n",
                    i, norm(v), sum(v))
            else
                @printf("  OUT lift_chain[%d]           = %.17g\n", i, Float64(v))
            end
        end
    end
end

println("sv_probe_raw_site_fingerprint — $(length(CASES)) machines")
for (label, dir) in CASES
    fingerprint(label, dir)
end
println("="^78)
@printf("julia %s ; KiteTurbineDynamics at %s\n", VERSION,
    read(`git -C $ROOT rev-parse --short HEAD`, String))
