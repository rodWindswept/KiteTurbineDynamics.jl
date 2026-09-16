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
include(joinpath(@__DIR__, "settle_case_builders.jl"))

# The campaign seed case comes from the ONE shared definition in
# settle_case_builders.jl, so this guard cannot drift from the preload/realisability
# guards (2026-09-14: de-duplicated — the local validity_params/validity_case copies
# were the exact drift hazard the shared file exists to prevent).

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

"Tension in the cyan line (sky anchor <-> lift bearing), by its own spring law."
function cyan_tension(u, sys, p)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

"Force applied to the sky anchor by the lift device: mass × (accel with lift − accel without)."
function lift_force_applied(u, sys, p, wf, lift)
    N = sys.n_total
    du_on = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    g = sys.sky_anchor_id
    m = (sys.nodes[g]).mass
    return m .* (du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
                 du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)])
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
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id

    # n_op raised from 2_000 to 50_000 (Rod, 2026-09-16).  These are highly
    # elastic devices, and 2_000 steps is NOT a converged settle once the back
    # line carries load: measured on this build, the cyan line is still slack at
    # 20_000 steps (T_cyan = 0.0) and engages only by ~30_000.  The bearing and
    # sky axial residuals are exactly 0.0 at and above 50_000.  Measured
    # (scratch/diag_ea_and_convergence.jl):
    #     n_op    T_cyan   hub res  bearing res  sky res
    #     2_000     0.0     -49.1      -214.2    -1925.2
    #    20_000     0.0    -248.8       -14.6      360.3
    #    30_000   224.9     -40.3         0.0       -0.1
    #    50_000   220.2     -45.0         0.0        0.0
    #    100_000  217.3     -47.9         0.0        0.0
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=50_000)
    sd = normalize(pos(u, hub))

    # ── V1 rotation present and uniform (the PTO needs rotation) ──────────────
    om = u[(6N + Nr + 1):(6N + 2Nr)]
    @test minimum(om) > 0.0                       # not a 0-rpm handoff
    @test maximum(om) - minimum(om) < 1e-6        # rings co-rotating, no slip

    # ── V3 the LIFT CHAIN stays connected ─────────────────────────────────────
    # RESTATED 2026-09-13 to Rod's ruling.  The mandatory-taut set is the LIFT
    # LINE (kite -> sky anchor) and the CYAN LINE (sky anchor -> lift bearing) —
    # the load path that actually carries the rotor.  The BRIDLE CONE and the
    # TRPT LINES MAY SLACK.  The previous assertion was
    # `bridle > 0.25 * lift_req`, which encoded the superseded "every line above
    # the ground ring is taut" rule and had to be REPLACED, not promoted.
    #
    # The BACK LINE is deliberately NOT asserted taut: it is an ALTITUDE LIMITER,
    # not a load path, and is slack at the design point by design — see
    # physics-topology.md §3.2 and handover 2026-09-13 §4.  Asserting it taut would
    # re-introduce the modelling error that made the plan's preload look
    # unrealisable.  Its tension is recorded for the log only.
    ef = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift)
    T_cyan = cyan_tension(u, sys, p)
    bridle = bridle_total_tension(u, sys, p, N, Nr)
    lift_req = 1.5 * expansion_airborne_mass(sys, p; include_lifter=false) * 9.81
    # The lift line is mandatory-taut: assert the FORCE actually applied to the
    # sky anchor, not `ef.base.T_lift` (which is `lift_force_steady` — a device+
    # wind function that stays nonzero with the line cut, 2026-09-14 finding).
    f_lift = lift_force_applied(u, sys, p, wf, lift)
    @info "lift chain" applied_lift=norm(f_lift) lift_ref=ef.base.T_lift T_cyan bridle lift_requirement=lift_req
    @test norm(f_lift) > 0.5 * lift_req   # the pull actually reaches the sky anchor
    @test T_cyan > 0.0                    # ...and passes down the cyan line to the bearing

    # ── V2 the airborne assembly is in force balance ──────────────────────────
    res, acc0 = axial_residuals(u, sys, p, wf, lift, N, sd)
    @info "axial residuals (N)" hub=res["hub"] bearing=res["bearing"] sky=res["sky"]
    # hub and sky promoted from @test_broken 2026-09-16.  Both were "broken"
    # only because the settle was run at n_op=2_000; at 50_000 steps they are
    # balanced to well inside the threshold (hub -39.1 N, sky -0.03 N measured).
    # An unexpected pass is an error in this suite, so they cannot stay broken.
    @test abs(res["hub"]) < 50.0
    @test abs(res["bearing"]) < 50.0              # promoted 2026-09-13: now balanced
    @test abs(res["sky"]) < 50.0

    # ── V6 the handoff is smooth (no first-frame jerk) ────────────────────────
    # STILL BROKEN, and now the only thing this testset does not hold.  At the
    # converged settle the AXIAL residual is ~0 on all three nodes, but the max
    # node acceleration is ~12_100 m/s^2 (~1240 g).  So the assembly is balanced
    # in the shaft direction yet some node still sees a large transverse
    # unbalanced force, or a light node sees a moderate one.  This is the
    # coupled position+twist equilibrium the static solver exists to solve
    # (docs/plans/2026-09-10-shaft-windup-workstream.md), not a settle-duration
    # problem: it does not move with n_op.
    @info "max node acceleration at t=0" acc0
    @test_broken acc0 < 10.0 * 9.81               # < 10 g
end
