# scratch/hermes_probe_lift_line.jl
#
# INDEPENDENT REVIEW PROBE (Hermes, 2026-09-14).  Not part of the DSH work.
#
# Question.  Handover 2026-09-14 section 6.4 concludes that the lift line's
# hard on/off switch is NOT the cause of the candidate's lift-chain collapse,
# because "the kite-to-sky-anchor distance is about 8.99 m against a threshold
# of 0.99 x 25 m = 24.75 m, so the lift line is switched off throughout the
# settle for both machines".
#
# Concern.  `scratch/diag_lift_line_switch.jl` computes that distance as
#
#     d = norm(pos(u, sys.kite.node_id) .- pos(u, sys.sky_anchor_id))
#
# but `KiteSpec` is built with `node_id = ring_ids[end]` (initialization.jl:170),
# i.e. the HUB RING.  There is no kite particle in the state vector; the live
# kite position is the mutable field `sys.kite_pos`, which `ring_forces.jl:491`
# is the one that the switch actually tests.  So the probe may have measured
# hub-to-sky-anchor (which IS the sky offset, 3.99 + 5.0 = 8.99 m) and labelled
# it as the lift-line length.
#
# This probe measures BOTH quantities, and measures whether the lift force is
# applied at all, by differencing the sky anchor's acceleration with and without
# the lift device on the same state.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const OLD_SEED = [2.4, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const NEW_SEED = [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

function build_for(x10)
    p = params_5kw_188()
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x,
        PROFILE_ELLIPTICAL,
        p;
        power_W=5000.0,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    cfg = ObjectiveConfig(;
        power_W=5000.0,
        v_rated=11.0,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        fos_target=2.5,
        fos_hard=2.5,
        min_wall_m=2e-3,
        t_over_D=0.055,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST,
    )
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"Sky-anchor acceleration with the lift device, minus without it (proves application)."
function lift_force_seen(u, sys, p, wf, lift)
    N = sys.n_total
    du_on = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_on, u, (sys, p, wf, lift), 0.0)
    du_off = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du_off, u, (sys, p, wf), 0.0)
    m = (sys.nodes[sys.sky_anchor_id]).mass
    g = sys.sky_anchor_id
    return m .* (
        du_on[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
        du_off[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
    )
end

println("\n=== does the lift line carry tension, and is the force applied? ===")
for (name, x10) in
    (("OLD (control, bank 0)", OLD_SEED), ("NEW (candidate, bank 11)", NEW_SEED))
    println("\n--- ", name)
    println(
        "  n_op | hub-to-sky | kite_pos-to-sky | line_length | 0.99*L | switch engages | |lift force|",
    )
    for n_op in (0, 500, 1000, 2000)
        sys, u0, pc, lift, wf = build_for(x10)
        N, Nr = sys.n_total, sys.n_ring
        u = settle_to_operational_state(
            sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
        )
        @assert all(isfinite, u) "non-finite state at n_op=$n_op"

        sky = pos(u, sys.sky_anchor_id)
        hub_to_sky = norm(pos(u, sys.kite.node_id) .- sky)   # what the old probe measured
        kite_to_sky = norm(sys.kite_pos .- sky)              # what ring_forces tests
        L = lift.line_length
        engaged = kite_to_sky >= 0.99 * L
        f = norm(lift_force_seen(u, sys, pc, wf, lift))
        println(
            "  ",
            lpad(n_op, 4),
            " | ",
            lpad(round(hub_to_sky; digits=4), 10),
            " | ",
            lpad(round(kite_to_sky; digits=4), 15),
            " | ",
            lpad(round(L; digits=2), 11),
            " | ",
            lpad(round(0.99 * L; digits=2), 6),
            " | ",
            lpad(engaged ? "YES" : "no", 14),
            " | ",
            round(f; digits=2),
        )
    end
end
println("\n=== done ===")
