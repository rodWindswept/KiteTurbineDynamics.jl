using KiteTurbineDynamics, LinearAlgebra, Printf
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function handoff(u, sys, p, wf, lift)
    N = sys.n_total
    du = zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    acc=[norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    force=[sys.nodes[g].mass*acc[g] for g in 1:N]
    sg=[
        g for
        g in 1:N if sys.nodes[g] isa RingNode || g==sys.bearing_id || g==sys.sky_anchor_id
    ]
    return maximum(acc[g] for g in sg), maximum(force)
end
function run_case(label)
    include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
    include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    d = KTD.lift_chain_design(sys, p, lift, pos(u0, sys.rotor.node_id); omega_eq=12.983466)
    @printf(
        "\n[%s] T_design=%.3f  design: T_cyan=%.2f T_back=%.2f T_top=%.2f back_taut=%s\n",
        label,
        KTD.BACK_LINE_T_DESIGN_N,
        d.T_cyan,
        d.T_back,
        d.T_top,
        d.back_taut
    )
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    a, f = handoff(u, sys, p, wf, lift)
    bx = p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
    sky = pos(u, sys.sky_anchor_id)
    bd = hypot(sky[1]-bx, sky[3])
    @printf(
        "[%s] settled: acc_struct=%.2f max_force=%.2f  b_dist=%.5f T_back_law=%.2f\n",
        label,
        a,
        f,
        bd,
        KTD.back_line_tension(bd, 13.92547, 0.0, p.EA_back_line)
    )
end
# Copy src with only the T_design constant changed, then load it.
function with_tdesign(Td)
    dir = mktempdir()
    for f in readdir(joinpath(@__DIR__, "..", "src"))
        endswith(f, ".jl") || continue
        txt = read(joinpath(@__DIR__, "..", "src", f), String)
        if f == "initialization.jl"
            txt = replace(
                txt,
                "const BACK_LINE_T_DESIGN_N = 320.0" => "const BACK_LINE_T_DESIGN_N = $Td",
            )
        end
        write(joinpath(dir, f), txt)
    end
    write(
        joinpath(dir, "KiteTurbineDynamics.jl"),
        replace(
            read(joinpath(@__DIR__, "..", "src", "KiteTurbineDynamics.jl"), String),
            "\"src/" => "\"",
        ),
    )
    return dir
end
dir = with_tdesign(2.2696)
pushfirst!(LOAD_PATH, dir)
@eval Main using KiteTurbineDynamics
run_case("T_design = 2.2696 (old placeholder), NEW 2x2 split")
