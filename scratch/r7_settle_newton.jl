# scratch/r7_settle_newton.jl — PROTOTYPE of the coupled static equilibrium
# (method B: full-state damped Newton on the ODE's own residual).
#
# Proposal: docs/plans/2026-09-11-settle-ode-coherence.md
# Baseline (today's pinned settle): 3.05e3 N node force residual, 87.3 N·m ring
# torque residual, first-segment twist 6.58° vs the running 48.8°.
#
# This is a scratch prototype. It does NOT touch src/.
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

# ── 0. Today's settle (the warm start) ────────────────────────────────────────
t0 = time()
u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
    lift_device=lift, wind_fn=wf, n_op=150_000)
t_old = time() - t0
ω_eq = u[6N + Nr + 1]
τ_gen = K_MPPT_5KW_HONEST * ω_eq^2

ground = sys.ring_ids[1]
free_nodes = [i for i in 1:N if i != ground]
npos = 3 * length(free_nodes)
nz = npos + Nr
masses = [sys.nodes[i].mass for i in free_nodes]
Jring = [sys.nodes[sys.ring_ids[k]].inertia_z for k in 1:Nr]
ode_params = (sys, pc, wf, lift)
du = zeros(Float64, length(u))

@printf("N=%d Nr=%d  unknowns=%d  ω_eq=%.4f  τ_gen=%.2f  old settle %.1fs\n",
    N, Nr, nz, ω_eq, τ_gen, t_old)

# ── 1. Residual: mass/inertia-weighted force & torque residual ────────────────
function unpack!(u, z)
    k = 0
    for i in free_nodes
        u[(3 * (i - 1) + 1):(3 * i)] .= z[(k + 1):(k + 3)]
        k += 3
    end
    u[(6N + 1):(6N + Nr)] .= z[(k + 1):(k + Nr)]
    return u
end

nres = Ref(0)
function residual(z)
    nres[] += 1
    unpack!(u, z)
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    set_orbital_velocities!(u, sys, pc)
    fill!(du, 0.0)
    multibody_ode!(du, u, ode_params, 0.0)
    R = Vector{Float64}(undef, nz)
    k = 0
    for (a, i) in enumerate(free_nodes)
        m = masses[a]
        for d in 1:3
            R[k + d] = m * du[3N + 3 * (i - 1) + d]
        end
        k += 3
    end
    for r in 1:Nr
        R[k + r] = Jring[r] * du[6N + Nr + r]
    end
    return R
end

function pack(u)
    z = Vector{Float64}(undef, nz)
    k = 0
    for i in free_nodes
        z[(k + 1):(k + 3)] .= u[(3 * (i - 1) + 1):(3 * i)]
        k += 3
    end
    z[(k + 1):(k + Nr)] .= u[(6N + 1):(6N + Nr)]
    return z
end

# ── 2. Levenberg–Marquardt on the ODE residual ────────────────────────────────
# Rows are already force/torque (newtons). Columns are scaled by a per-unknown
# length so the normal-equation diagonal is O(1) across positions and angles.
function solve_newton(u; maxit=40, λ0=1e-2, tol=1e-3, verbose=true)
    z = pack(u)
    R = residual(z)
    R0 = norm(R, Inf)
    scale = [max(abs(z[j]), 1e-2) for j in 1:nz]
    column_scale = copy(scale)
    λ = λ0
    t_start = time()
    @printf("\n  it   ‖R‖∞ (N / N·m)     λ        step    res-evals\n")
    @printf("   0   %.6e            -          -      %d\n", R0, nres[])
    for it in 1:maxit
        J = Matrix{Float64}(undef, nz, nz)
        for j in 1:nz
            h = 1e-6 * column_scale[j]
            zp = copy(z)
            zp[j] += h
            J[:, j] = (residual(zp) .- R) ./ h
        end
        # column scaling: Js = J * diag(column_scale), solve in y = z/scale
        Js = J .* reshape(column_scale, 1, nz)
        g = Js' * R
        accepted = false
        for _ in 1:30
            A = Js' * Js + λ * I
            δy = try
                -(A \ g)
            catch
                fill(NaN, nz)
            end
            all(isfinite, δy) || (λ *= 10; continue)
            znew = z .+ column_scale .* δy
            Rnew = residual(znew)
            if norm(Rnew) < norm(R)
                stepnorm = norm(column_scale .* δy)
                z, R = znew, Rnew
                λ = max(λ / 3, 1e-12)
                accepted = true
                verbose && @printf("%4d   %.6e       %.1e   %.3e   %d\n",
                    it, norm(R, Inf), λ, stepnorm, nres[])
                break
            else
                λ *= 10
            end
        end
        accepted || (verbose && @printf("%4d   stalled (λ=%.1e)\n", it, λ); break)
        norm(R, Inf) < tol && (verbose && @printf("  converged: ‖R‖∞ = %.3e\n", norm(R, Inf)); break)
    end
    t_solve = time() - t_start
    return z, norm(R, Inf), t_solve
end

@printf("\n=== baseline residuals of today's settle ===\n")
Rz = residual(pack(u))
@printf("  max|F| = %.6e N     max|τ| = %.6e N·m\n", maximum(abs.(Rz[1:npos])), maximum(abs.(Rz[(npos + 1):end])))

@printf("\n=== Newton (method B) ===\n")
z, Rfin, t_solve = solve_newton(copy(u))

unpack!(u, z)
u[(3N + 1):6N] .= 0.0
u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
set_orbital_velocities!(u, sys, pc)

Rend = residual(z)
@printf("\n=== result ===\n")
@printf("  iterations wall time     = %.2f s   (%d residual evals)\n", t_solve, nres[])
@printf("  final max|F| residual    = %.6e N\n", maximum(abs.(Rend[1:npos])))
@printf("  final max|τ| residual    = %.6e N·m\n", maximum(abs.(Rend[(npos + 1):end])))

α = u[(6N + 1):(6N + Nr)]
dα = diff(α)
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
hub_pos = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
sd = norm(hub_pos) > 0.1 ? hub_pos ./ norm(hub_pos) : [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
laterals = Float64[]
for k in 1:Nr
    gid = sys.ring_ids[k]
    r = u[(3 * (gid - 1) + 1):(3 * gid)]
    push!(laterals, norm(r .- dot(r, sd) .* sd))
end
@printf("  cumulative Δα            = %.2f°\n", sum(dα) * 180 / π)
@printf("  per-seg twist (deg)      = %s\n", join(round.(dα .* 180 ./ π, digits=2), ", "))
@printf("  segment torque (N·m)     = %s\n", join(round.(ef.segment_torque, digits=0), ", "))
@printf("  ring lateral offsets (m) = %s\n", join(round.(laterals, digits=4), ", "))
@printf("  hub lateral offset       = %.4f m\n", laterals[end])
@printf("  per-seg twist ratio max  = %.4f\n", maximum(dα) / (π / 2))
