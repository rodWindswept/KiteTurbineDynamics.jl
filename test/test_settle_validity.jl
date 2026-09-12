# test/test_settle_validity.jl
#
# Settle-validity guard (2026-09-12, Rod): a settle is VALID only if it hands the
# ODE a state that is (a) at the operating point, (b) in force balance, and (c) has
# every tension line carrying load.  None of these were asserted before, which is
# how the lift chain came to be structurally disconnected with a green suite.
#
# Measured on the v13 campaign seed 2026-09-12 (scratch/settle_validity_baseline.jl):
#
#   V1  structural velocity (rotation removed)   0.0 m/s     -> PASS
#       rotation present, omega                   12.983466   -> PASS (> 0; the PTO
#       needs rotation, so omega == 0 would be a defect, not a clean start)
#   V2  hub axial residual                      -479.75 N    -> FAIL (target |f| < 50)
#       bearing axial residual                  +226.92 N    -> FAIL
#       sky axial residual                      +147.25 N    -> FAIL
#   V3  bridle total tension                       0.00 N    -> FAIL (lift chain
#       disconnected; the lift requirement is 431.31 N vertical)
#       cyan line tension                        230.59 N    (about half the load,
#       consistent with nothing reacting the other half)
#   V4  (ring torque residual -- not yet measured)
#   V5  twist drift over 1 s                       0.00      -> uninformative: the
#       twist is pinned while the structure oscillates, so this must NOT be used
#       as a smoothness proxy
#   V6  max node acceleration at t=0        10310.49 m/s^2    -> FAIL (about 1000 g)
#
# These are recorded as FAILING assertions, deliberately: the test is the durable
# record that the settle is not yet valid, and it prevents the defect from being
# quietly re-baselined.  When the lift chain and the force balance are fixed, the
# assertions start passing and this file becomes the regression guard.
#
# These are recorded with @test_broken, not @test, for two reasons: the suite
# convention is never to commit red (AGENTS.md), and @test_broken is the precise
# instrument here — it keeps the suite green while recording the defect, and it
# WARNS as soon as an assertion starts passing, which is exactly the signal that
# the fix has landed.  WHEN ONE STARTS PASSING, promote that line to @test.
#
# See docs/agents/physics-topology.md sections 3 and 5.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

function validity_params()
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

# The campaign seed, built exactly as test_settle_preload_consistency.jl does.
function validity_case()
    p = validity_params()
    x = seed_genome(5.0)
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
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
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"Total tension in the six bridles (lift bearing -> main rotor attachment vertices)."
function bridle_total_tension(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx,
                              p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

function axial_residuals(u, sys, p, wf, lift, N, sd)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    out = Dict{String,Float64}()
    for (nm, gid) in (("hub", sys.rotor.node_id), ("bearing", sys.bearing_id),
                      ("sky", sys.sky_anchor_id))
        m = (sys.nodes[gid]).mass
        out[nm] = dot(m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)], sd)
    end
    acc = maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    return out, acc
end

@testset "settle validity — hands the ODE a load-carrying, balanced state" begin
    sys, u0, p, lift, wf = validity_case()
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))

    # ── V1 rotation present and uniform (the PTO needs rotation) ──────────────
    om = u[(6N + Nr + 1):(6N + 2Nr)]
    @test minimum(om) > 0.0                       # not a 0-rpm handoff
    @test maximum(om) - minimum(om) < 1e-6        # rings co-rotating, no slip

    # ── V3 every line above the ground ring carries load ──────────────────────
    # The lift chain must carry the airborne assembly, so the bridles must be in
    # tension.  0.0 N means the lift never reaches the rotor: the failure mode
    # recorded three times in DECISIONS.md (1776-1779, 1806-1822, 2108-2120).
    bridle = bridle_total_tension(u, sys, p, N, Nr)
    lift_req = 1.5 * expansion_airborne_mass(sys, p; include_lifter=false) * 9.81
    @info "bridle total tension" bridle lift_requirement=lift_req
    @test_broken bridle > 0.25 * lift_req         # >= 25 % of the 1.5x-W requirement

    # ── V2 the airborne assembly is in force balance ──────────────────────────
    res, acc0 = axial_residuals(u, sys, p, wf, lift, N, sd)
    @info "axial residuals (N)" hub=res["hub"] bearing=res["bearing"] sky=res["sky"]
    @test_broken abs(res["hub"]) < 50.0
    @test_broken abs(res["bearing"]) < 50.0
    @test_broken abs(res["sky"]) < 50.0

    # ── V6 the handoff is smooth (no first-frame jerk) ────────────────────────
    @info "max node acceleration at t=0" acc0
    @test_broken acc0 < 10.0 * 9.81               # < 10 g
end
