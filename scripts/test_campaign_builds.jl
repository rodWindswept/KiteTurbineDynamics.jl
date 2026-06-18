#!/usr/bin/env julia
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf

function parse_json(path)
    d = Dict{String,Any}()
    for line in eachline(path)
        m = match(r"\"(\w+)\":\s*(.+)", strip(line))
        if m !== nothing
            key = m.captures[1]
            val = strip(m.captures[2], [',', '"'])
            d[key] = try parse(Float64, val) catch; try parse(Int, val) catch; val end end
        end
    end
    d
end

function build_campaign(dir, label)
    design = parse_json(joinpath("scripts", "results", dir, "best_design.json"))
    n_lines = Int(design["n_lines"])
    n_exp = Int(design["n_expansion"])
    bank = design["bank_angle_deg"]
    r_blade = design["blade_tip_radius"]
    blade_s = get(design, "blade_scale", 1.0)

    p = params_v5_50kw()
    n_rings = Int(get(design, "n_rings", 9))
    geo = GeometrySpec(p.elevation_angle, p.lifter_elevation, p.rotor_radius,
                       p.tether_length, design["r_hub_m"], p.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(p.tether_diameter, p.e_modulus, p.m_ring, p.m_blade)
    aero = AeroSpec(p.rho, p.v_wind_ref, p.h_ref, p.cp)
    ctrl = ControlSpec(p.i_pto, p.k_mppt, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
    back = BackLineSpec(p.EA_back_line, p.c_back_line, p.back_anchor_fwd_x, p.backline_payout)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(pc)

    chord = 0.113 * r_blade / max(blade_s, 0.001)
    cfg = ExpansionStackConfig(;
        placement=:clustered, n_rings=sys.n_ring, n_expansion=n_exp,
        n_blades=n_lines,
        blade_tip_radius=r_blade, blade_hub_radius=0.25*r_blade, blade_chord=chord,
        CL_blade=1.0, CD0_blade=0.02, k_induced=0.05,
        bank_angle_deg=bank,
        mass_per_rotor=(0.3+0.1*r_blade)*blade_s^3,
        shaft_coupling=1.0)
    stack = build_expansion_stack(cfg)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=stack)

    @printf("%s: n=%d  n_exp=%d  bank=%.0f°  r_blade=%.2fm  λ=%.3f  rings=%d  nodes=%d\n",
            label, n_lines, n_exp, bank, r_blade, blade_s, sys.n_ring, sys.n_total)
    return sys, u0, pc
end

for (dir, label) in [
    ("v6_3_campaign_50kw", "V6.3"),
    ("v6_4_campaign_50kw", "V6.4"),
    ("v6_5_campaign_50kw", "V6.5"),
]
    build_campaign(dir, label)
end
println("\nAll campaign systems build successfully.")
