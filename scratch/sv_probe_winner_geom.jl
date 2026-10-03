# sv_probe_winner_geom.jl — why the betz reconciliation pins no longer match at the tip
using KiteTurbineDynamics
const KTD = KiteTurbineDynamics
const ROOT = pwd()
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))

read_genome(path) = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]
csv = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
x = read_genome(csv)

function geom(d)
    sys, _u, _pc = KTD.build_system_from_v10(d.dec, 1.0, d.k_mp;
        tether_diameter=d.p.tether_diameter, base_params=d.p)
    r = sys.rotor
    return (r_out=r.radius, r_in=r.blade_hub_radius, span=r.radius - r.blade_hub_radius,
            A=pi * (r.radius^2 - r.blade_hub_radius^2), v=d.p.v_wind_ref, h=d.p.h_ref)
end

d = decode_winner(x; L=18.8, KW=5.0)
g = geom(d)
println("TIP (D1 site wind):   v_wind_ref=", g.v, "  h_ref=", g.h)
println("  r_out=", g.r_out, "  r_in=", g.r_in, "  span=", g.span, "  A_axial=", g.A)
println("  (test pins: r_out 4.7786452387 / r_in 3.4301130937 / A 34.7767221889)")

# Pre-D1 decoder wind at the 5 kW hub (DECISIONS Defect-D): 8.7051 m/s.
p_old = KTD.override_params(params_daisy(); v_wind_ref=8.7051)
pa = params_at_length(p_old, 18.8, 5.0)
println("override survived params_at_length? v_wind_ref=", pa.v_wind_ref)
d2 = decode_winner(x; L=18.8, KW=5.0, p2=p_old)
g2 = geom(d2)
println("PRE-D1 wind:  v_wind_ref=", g2.v)
println("  r_out=", g2.r_out, "  r_in=", g2.r_in, "  span=", g2.span, "  A_axial=", g2.A)
