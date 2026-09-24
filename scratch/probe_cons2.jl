using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys,
        copy(u0),
        pc,
        60.0;
        lift_device=lift,
        wind_fn=wf,
        n_op=2_000,
        operational_polish=false,
    )
    ω = u[6N + Nr + 1]
    ef = KTD.capture_extended(u, sys, pc, 0.0, wf, lift)
    T_meas = ef.segment_tension
    hub_settled = pos(u, sys.rotor.node_id)
    # candidate reference A: the state the test passes (raw u0 hub)
    FA = design_axial_preload(sys, pc, lift, u0; omega_eq=ω, wind_fn=wf)
    # candidate reference B: evaluated at the settled hub
    FB = design_axial_preload(
        sys, pc, lift, u0; omega_eq=ω, wind_fn=wf, hub_pos=hub_settled
    )
    for (tag, F) in (("A: raw u0 hub", FA), ("B: settled hub", FB))
        intended = F ./ pc.n_lines
        @printf(
            "%-16s F_top=%8.2f  max rel err=%.6f\n",
            tag,
            F[end],
            maximum(abs.(T_meas .- intended) ./ intended)
        )
    end
    # C: trpt_matched_place at the settled hub, then compare its own T_s
    τ = sys.k_mppt_ref[]*ω^2
    pl = KTD.trpt_matched_place(sys, pc, FB, τ, ω, wf)
    @printf(
        "C: place(FB)  T_s[1]=%.2f  measured=%.2f  err=%.5f\n",
        pl.T_s[1],
        T_meas[1],
        abs(pl.T_s[1]-T_meas[1])/pl.T_s[1]
    )
end
main()
