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
#   V6  max node acceleration at t=0    measured 17_468 m/s^2  -> FAIL, but the
#       metric was measuring the WRONG THING.  See the V6 note in the body: 98.4 %
#       of it was the aero drag of nodes spinning at ~32 m/s, and the argmax was a
#       2.25 g rope node.  Corrected 2026-09-16 to the STATIC residual (node
#       translational velocities zeroed, omega retained), which read 284.5 m/s^2
#       (29 g) on RingNode 11 -- a real imbalance the static solver can remove.
#       CORRECTED AGAIN 2026-09-19 (Rod): the drag was removable after all — it was
#       UNBALANCED, not an already-balanced operating-point force — so the gate is
#       now the FULL handoff path on the structural nodes plus a force gate.  See
#       the V6 note in the body.
#
# NOW FULLY GREEN (2026-09-19).  Every assertion here is a plain `@test`; the last
# `@test_broken` was V6 and it was promoted when the Barnes dynamic-relaxation
# OPERATIONAL-equilibrium polish landed as the final pass of
# `settle_to_operational_state` (`src/initialization.jl`).  The file is now the
# durable regression guard for the settle's validity contract (a)/(b)/(c) from the
# header above, not a record of an open defect.
#
# The `@test_broken` convention this file used until then, retained because it is
# the right instrument whenever a new defect is found: it keeps the suite green
# while recording the defect exactly, and it WARNS the moment the assertion starts
# passing, which is the signal that the fix has landed and the line must be
# promoted to `@test`.
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

"""
Max node acceleration at the handoff, measured on the STATIC force path: node
TRANSLATIONAL velocities are zeroed so the rope material damper and the
aerodynamic drag vanish and only the unbalanced elastic/gravity/rotor forces
remain.  `omega` is RETAINED, so the rotor thrust and torque stay in the load
case (`ACTIVE.md` item 3 mandates exactly this force path).

WHY this is not the raw `multibody_ode!` reading.  Measured 2026-09-16
(`scratch/diag_acc0_velocity.jl`) on the settled state of `build_case(nothing,
nothing)`:

    (1) as-is (raw)                  17_468 m/s^2   argmax = RopeNode, 0.00225 kg
    (2) translational vel = 0           284.5 m/s^2    argmax = RingNode 11, 0.836 kg
    (3) all vel = 0 (incl. omega)       152.2 m/s^2    argmax = RingNode 11

The settled state carries `max |v| = 32.2 m/s`, `rms = 9.1 m/s`, which is the
legitimate rigid rotation (`omega·r ~ 13.45 · 2.4 ~ 32`); V1 already asserts the
non-rotational velocity is 0.0 m/s.  So 98.4 % of the raw reading is drag on
nodes that are correctly spinning, and a 39 N drag force on a 2.25 g rope node
reads as 1780 g.

CORRECTION 2026-09-19 (Rod).  The 2026-09-16 note on this function ended "NO
equilibrium solver can remove that: it is a correct operating-point force".  That
is FALSE, and this function is now a REFERENCE instrument only, not the acceptance
metric.  The drag was removable because it was UNBALANCED at the settled state,
not because it was an operating-point force already in balance: a dynamic
relaxation that includes the orbital velocity field removes 98.3 % of the
first-frame acceleration (17 468 -> 293 m/s^2) and balances the hub axially to
-2.67 N.  Relaxing WITHOUT drag instead produces a state that is 11x WORSE at the
hub (162 N) once the orbital velocity is applied at handoff.  See
`handoff_residuals` below and `scratch/probe_dr_variants.jl`.
"""
function static_acc0(u, sys, p, wf, lift, N)
    u_static = copy(u)
    u_static[(3N + 1):(6N)] .= 0.0      # zero linear node velocities; keep omega
    du = zeros(length(u_static))
    KiteTurbineDynamics.multibody_ode!(du, u_static, (sys, p, wf, lift), 0.0)
    return maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
end

"""
Handoff residuals on the FULL force path the ODE integrates, with the node
velocities exactly as `settle_to_operational_state` returns them (rope nodes at
their orbital velocity, ring/bearing/sky translational velocities zero, `omega`
retained).  Returns `(acc_all, acc_struct, max_force)`:

    `acc_all`    largest per-node acceleration (m/s^2).  Near the equilibrium
                 floor this is a MASS ARTEFACT: the argmax is always the lightest
                 discretised cable node (2.25 g), so a 0.7 N residual reads as
                 ~300 m/s^2.  Reported, deliberately not gated on.
    `acc_struct` largest acceleration on the STRUCTURAL nodes — ring nodes plus
                 the bearing and the sky anchor — where an acceleration is
                 physically meaningful.  This is V6's primary gate.
    `max_force`  largest unbalanced node force (N), over every node.  Mass-robust
                 and therefore the right whole-network gate.

Both gates catch the pre-polish defect (measured on the campaign seed at
`n_op = 300_000`: `acc_struct` 791.3 m/s^2 / 661.9 N unpolished vs 7.53 m/s^2 /
89.6 N polished — `scratch/probe_wired_A.jl`).
"""
function handoff_residuals(u, sys, p, wf, lift, N)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    acc = [norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    force = [sys.nodes[g].mass * acc[g] for g in 1:N]
    structural = [
        g for g in 1:N if
        sys.nodes[g] isa RingNode || g == sys.bearing_id || g == sys.sky_anchor_id
    ]
    return maximum(acc), maximum(acc[g] for g in structural), maximum(force)
end

@testset "settle validity — hands the ODE a load-carrying, balanced state" begin
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id

    # n_op raised 2_000 -> 50_000 -> 300_000 (Rod, 2026-09-16).  These are highly
    # elastic devices and the horizon is NOT universal: it must be long enough for
    # the build under test.  Two measurements, on two different campaign seeds:
    #
    #   L/r 2.0 seed (12 rings), scratch/diag_ea_and_convergence.jl
    #     n_op    T_cyan   hub res  bearing res  sky res
    #     2_000      0.0     -49.1      -214.2    -1925.2
    #     20_000     0.0    -248.8       -14.6      360.3
    #     30_000   224.9     -40.3         0.0       -0.1
    #     50_000   220.2     -45.0         0.0        0.0
    #     100_000  217.3     -47.9         0.0        0.0
    #
    #   L/r 1.5 seed (13 rings), scratch/tmp_hub_conv.jl
    #     n_op     hub res  bearing res  sky res
    #     50_000     66.9       0.003      0.036
    #     150_000    52.33      0.001      0.018
    #     300_000    43.54      0.0        0.003
    #     600_000    41.71      0.0        0.0
    #
    # The 13-ring seed equilibrates more slowly and its hub residual has a floor
    # near 42 N, so 50_000 (where the 12-ring seed reads 45.0 N) reads 66.9 N here
    # and fails the 50 N bar.  300_000 gives real margin (43.5 N) at triple the
    # runtime.  The residual is the handoff imbalance the static solver exists to
    # remove; this horizon is a workaround, not a fix.
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000)
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

    # ── V6 the handoff is in balance under the forces the ODE integrates ──────
    #
    # Metric history, because this assertion has now been redefined twice and both
    # times for a measured reason — see the `static_acc0` correction above.
    #
    #   2026-09-12: `acc0` read straight off `multibody_ode!`     17 468 m/s^2
    #   2026-09-16: corrected to the DRAG-FREE static residual      284.5 m/s^2
    #               (the "98.4 % of it is legitimate spinning drag" correction)
    #   2026-09-19: corrected again to the FULL handoff path — the drag is
    #               removable, because it was unbalanced, not an operating-point
    #               force already in balance.
    #
    # The settle now ends with an OPERATIONAL-equilibrium polish
    # (`_polish_operational_equilibrium!` in `src/initialization.jl`): Barnes
    # kinetic-damping dynamic relaxation of the node positions under the FULL
    # handoff force field, including the steady-state spinning-cable drag.
    #
    # WHY the drag-free metric was retired.  It zeroes the translational
    # velocities, which removes the very forces the state must balance, so it
    # rewards a state that is NOT the one the ODE integrates.  Measured on the
    # same settled state, both variants converged, 20 000 iterations
    # (`scratch/probe_dr_variants.jl`):
    #
    #   variant                     drag-free acc0   HANDOFF acc0    V2 hub axial
    #   -------------------------   --------------   -------------   ------------
    #   no polish                      284.5 (29.0 g)  17468 (1781 g)     +14.5 N
    #   drag-free DR (the old plan)     71.4 ( 7.3 g)  18610 (worse)     +162.3 N
    #   drag-included DR (landed)    17681 (1802 g)      293 (29.9 g)      -2.65 N
    #
    # V6 therefore gates on the STRUCTURAL nodes, where an acceleration is
    # meaningful (~0.77 g measured), and on the largest unbalanced FORCE anywhere,
    # which is mass-robust.  `acc_all` is reported but NOT gated: near the floor its
    # argmax is always the lightest 2.25 g cable node, so a ~0.7 N residual reads as
    # ~300 m/s^2 — the same mass artefact the 2026-09-16 entry diagnosed.
    acc_all, acc_struct, max_force = handoff_residuals(u, sys, p, wf, lift, N)
    @info "handoff residual at t=0" acc_all acc_struct max_force acc0_raw=acc0
    @test acc_struct < 10.0 * 9.81    # < 10 g on the structure (measured 7.53 m/s^2)
    @test max_force < 200.0           # N, largest unbalanced node force (measured 89.6 N)
end
