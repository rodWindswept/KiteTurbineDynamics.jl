# scratch/r7_settle_staged.jl — PROTOTYPE 2: staged settle↔ODE equilibrium.
#
# Prototype 1 (full-state damped Newton, scratch/r7_settle_newton.jl) stalled:
# force residual improved (2.6e3 -> 32 N) but the ring torque residual got
# WORSE (87 -> 225 N·m) and λ ran away, with the transmitted torque collapsing
# (bottom segments 188 -> 64 N·m). That is the signature of a step that lets the
# lines go slack: freeing every node position AND every twist at once walks the
# tension structure into a collapsed configuration.
#
# This staged version keeps the two sub-problems separate and each well-posed:
#   stage 1  positions-only Newton (all node positions free, twist frozen)
#   stage 2  triangular torque chain: bottom-up 1-D bisection of each segment's
#            dα on that ring's own angular residual, using the ODE kernel
#            (so expansion-rotor torque injection is handled by the kernel, not
#            re-derived), then repeat.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
N = sys.n_total
Nr = sys.n_ring
EA_rope = pc.e_modulus * π * (pc.tether_diameter / 2)^2

t0 = time()
u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=150_000)
t_old = time() - t0
ω_eq = u[6N + Nr + 1]
τ_gen = K_MPPT_5KW_HONEST * ω_eq^2

ground = sys.ring_ids[1]
free_nodes = [i for i in 1:N if i != ground]
np = 3 * length(free_nodes)
masses = [sys.nodes[i].mass for i in free_nodes]
Jring = [sys.nodes[sys.ring_ids[k]].inertia_z for k in 1:Nr]
ode_params = (sys, pc, wf, lift)
du = zeros(Float64, length(u))
nres = Ref(0)

@printf("N=%d Nr=%d  np=%d  ω_eq=%.4f  τ_gen=%.2f  old settle %.1fs\n",
    N, Nr, np, ω_eq, τ_gen, t_old)

function fill_velocities!(u)
    u[(3N + 1):6N] .= 0.0
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    set_orbital_velocities!(u, sys, pc)
    return u
end

function ode!(u)
    nres[] += 1
    fill_velocities!(u)
    fill!(du, 0.0)
    multibody_ode!(du, u, ode_params, 0.0)
    return du
end

# ── residual pieces ───────────────────────────────────────────────────────────
function force_residual!(R, z)
    k = 0
    for (a, i) in enumerate(free_nodes)
        u[(3 * (i - 1) + 1):(3 * i)] .= z[(k + 1):(k + 3)]
        k += 3
    end
    d = ode!(u)
    for (a, i) in enumerate(free_nodes)
        for q in 1:3
            R[3 * (a - 1) + q] = masses[a] * d[3N + 3 * (i - 1) + q]
        end
    end
    return R
end

function torque_residuals(u)
    d = ode!(u)
    return [Jring[r] * d[6N + Nr + r] for r in 1:Nr]
end

function pack_pos(u)
    z = Vector{Float64}(undef, np)
    k = 0
    for i in free_nodes
        z[(k + 1):(k + 3)] .= u[(3 * (i - 1) + 1):(3 * i)]
        k += 3
    end
    return z
end

# ── stage 1: positions-only damped Newton (LM) ────────────────────────────────
function solve_positions!(u; maxit=25, tol=1e-3, verbose=false)
    z = pack_pos(u)
    R = force_residual!(Vector{Float64}(undef, np), z)
    scale = [max(abs(z[j]), 1e-2) for j in 1:np]
    λ = 1e-3
    for it in 1:maxit
        J = Matrix{Float64}(undef, np, np)
        for j in 1:np
            h = 1e-6 * scale[j]
            zp = copy(z)
            zp[j] += h
            J[:, j] = (force_residual!(Vector{Float64}(undef, np), zp) .- R) ./ h
        end
        Js = J .* reshape(scale, 1, np)
        g = Js' * R
        for _ in 1:25
            δy = try
                -((Js' * Js + λ * I) \ g)
            catch
                fill(NaN, np)
            end
            all(isfinite, δy) || (λ *= 10; continue)
            zn = z .+ scale .* δy
            Rn = force_residual!(Vector{Float64}(undef, np), zn)
            if norm(Rn) < norm(R)
                z, R = zn, Rn
                λ = max(λ / 3, 1e-12)
                break
            end
            λ *= 10
        end
        verbose && @printf("   pos it %2d  ‖F‖∞=%.4e  λ=%.1e\n", it, norm(R, Inf), λ)
        norm(R, Inf) < tol && break
    end
    k = 0
    for i in free_nodes
        u[(3 * (i - 1) + 1):(3 * i)] .= z[(k + 1):(k + 3)]
        k += 3
    end
    return norm(R, Inf)
end

# ── stage 2: triangular torque chain, bottom-up bisection per segment ─────────
function solve_twist!(u; tol=1e-3, maxsweep=12, hi0=π / 2)
    αbase = [u[6N + r] for r in 1:Nr]
    for sweep in 1:maxsweep
        worst = 0.0
        for s in 1:(Nr - 1)
            ra, rb = sys.ring_ids[s], sys.ring_ids[s + 1]
            rbi = (sys.nodes[rb]::RingNode).ring_idx
            base = αbase[rbi]
            f = Δ -> begin
                u[6N + rbi] = base + Δ
                τ = torque_residuals(u)
                τ[rbi]
            end
            # bisect: monotone increasing in Δ over [0, hi]
            lo, hi = 0.0, hi0
            flo = f(lo)
            if flo > 0
                u[6N + rbi] = base
                αbase[rbi] = base
                worst = max(worst, abs(flo))
                continue   # already over-torqued at zero twist — leave slacked
            end
            fhi = f(hi)
            if fhi < 0
                # cannot reach balance within the twist cap
                u[6N + rbi] = base + hi
                αbase[rbi] = base + hi
                worst = max(worst, abs(fhi))
                continue
            end
            for _ in 1:50
                mid = (lo + hi) / 2
                (f(mid) < 0) ? (lo = mid) : (hi = mid)
            end
            Δ = (lo + hi) / 2
            u[6N + rbi] = base + Δ
            worst = max(worst, abs(f(Δ)))
            αbase[rbi] = base + Δ
        end
        rmax = maximum(abs.(torque_residuals(u)))
        worst = max(worst, rmax)
        @printf("   twist sweep %2d   max|τ_res| = %.4e N·m   cumulative Δα = %.2f°\n",
            sweep, rmax, (αbase[end] - αbase[1]) * 180 / π)
        rmax < tol && break
    end
    return nothing
end

# ring_idx lookup (ring_ids index == ring_idx for these systems)
rb_ring_idx(gid) = (sys.nodes[gid]::RingNode).ring_idx

# ── baseline ──────────────────────────────────────────────────────────────────
let Rt = torque_residuals(u)
    @printf("\n=== baseline (today's settle) ===\n")
    @printf("  max|τ_res| per ring (N·m) = %s\n", join(round.(Rt, digits=3), ", "))
    @printf("  segment torque (N·m)      = %s\n",
        join(round.(KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift).segment_torque, digits=0), ", "))
    @printf("  min segment tension (N)   = %.1f\n",
        minimum(KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift).segment_tension))
end

@printf("\n=== stage 1: positions-only Newton ===\n")
α_saved = [u[6N + r] for r in 1:Nr]
t1 = time()
fres = solve_positions!(u; maxit=25, tol=1e-3, verbose=true)
@printf("  ‖F‖∞ = %.4e N   (%.1f s, %d evals)\n", fres, time() - t1, nres[])
let
    d = ode!(u)
    worst, wi = 0.0, 0
    for (a, i) in enumerate(free_nodes)
        fm = masses[a] * norm(d[(3N + 3 * (i - 1) + 1):(3N + 3 * i)])
        fm > worst && (worst = fm; wi = i)
    end
    @printf("  worst node: id=%d type=%s  |F|=%.4e N\n", wi, typeof(sys.nodes[wi]), worst)
end

@printf("\n=== stage 2: torque chain ===\n")
t2 = time()
solve_twist!(u; tol=1e-3, maxsweep=12)
@printf("  (%.1f s, %d evals)\n", time() - t2, nres[])

@printf("\n=== outer iteration: re-relax positions after twist ===\n")
for outer in 1:4
    fres = solve_positions!(u; maxit=15, tol=1e-3)
    Rt = torque_residuals(u)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    @printf("  outer %d: ‖F‖∞ = %.4e N   max|τ_res| = %.4e N·m   min T = %.1f N\n",
        outer, fres, maximum(abs.(Rt)),
        minimum(ef.segment_tension))
    (fres < 1e-3 && maximum(abs.(Rt)) < 1e-3) && break
    solve_twist!(u; tol=1e-3, maxsweep=6)
end

# ── report ────────────────────────────────────────────────────────────────────
Rt = torque_residuals(u)
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
α = [u[6N + r] for r in 1:Nr]
dα = diff(α)
hub_pos = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
sd = norm(hub_pos) > 0.1 ? hub_pos ./ norm(hub_pos) : [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
laterals = Float64[]
for k in 1:Nr
    gid = sys.ring_ids[k]
    r = u[(3 * (gid - 1) + 1):3 * gid]
    push!(laterals, norm(r .- dot(r, sd) .* sd))
end
@printf("\n=== final ===\n")
@printf("  max|τ_res| per ring (N·m) = %s\n", join(round.(Rt, digits=4), ", "))
@printf("  ‖F‖∞                      = %.4e N\n", fres)
@printf("  cumulative Δα             = %.2f°\n", sum(dα) * 180 / π)
@printf("  per-seg twist (deg)       = %s\n", join(round.(dα .* 180 ./ π, digits=2), ", "))
@printf("  segment torque (N·m)      = %s\n", join(round.(ef.segment_torque, digits=0), ", "))
@printf("  segment tension (N)       = %s\n", join(round.(ef.segment_tension, digits=1), ", "))
@printf("  ring lateral offsets (m)  = %s\n", join(round.(laterals, digits=4), ", "))
@printf("  total evals = %d\n", nres[])
