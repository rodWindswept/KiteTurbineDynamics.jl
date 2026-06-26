#!/usr/bin/env julia
# scripts/interactive_dashboard.jl
# Canonical source of truth for KiteTurbineDynamics.jl.
# Normal mode: Opens interactive GLMakie dashboard.
# Headless mode: julia --project=. scripts/interactive_dashboard.jl --headless

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra, ArgParse, CSV, DataFrames, GLMakie

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--headless"
            help = "Run in headless batch mode for report generation"
            action = :store_true
        "--wind"
            help = "Wind speed for single run (m/s)"
            arg_type = Float64
            default = 11.0
        "--duration"
            help = "Simulation duration (s)"
            arg_type = Float64
            default = 10.0
        "--optimized"
            help = "Render the optimized TRPT geometry from trpt_opt/<label>/best_design.json"
            arg_type = String
            default = ""
        "--v5"
            help = "Use v5 optimized 8-line octagon geometry"
            action = :store_true
        "--v6"
            help = "Use V6.2 optimized 12-line dodecagon with expansion rotor"
            action = :store_true
        "--v62"
            help = "Use V6.2 campaign winner (12-line, 1 exp, 74 kg)"
            action = :store_true
        "--v63"
            help = "Use V6.3 campaign winner (7-line, 6 exp, 53 kg, λ=0.2)"
            action = :store_true
        "--v64"
            help = "Use V6.4 campaign winner (3-line, 12 exp, 24 kg, λ=0.02)"
            action = :store_true
        "--v65"
            help = "Use V6.5 campaign winner (3-line, 20 exp, 18 kg, λ=0.01)"
            action = :store_true
        "--v9"
            help = "Use V9.0 campaign winner (50kW, equilibrium solve)"
            action = :store_true
        "--v9-10kw"
            help = "Use V9.0 10kW campaign winner (equilibrium solve)"
            action = :store_true
        "--v10"
            help = "Use V10 campaign winner (unified rotors, full constraints)"
            action = :store_true
        "--v10-island51"
            help = "Use V10 Island 51 alt-basin design (2 rotors, 76.75 kg)"
            action = :store_true
        "--v10-tight"
            help = "Use V10 Tight winner (49.2 kg, 4 rotors, without lowest expansion)"
            action = :store_true
        "--v67"
            help = "Use V6.7 campaign winner (drag-constrained, streamlined Cd)"
            action = :store_true
        "--expansion"
            help = "Add expansion rotors at given bank angle (deg, default 20)"
            arg_type = Float64
            default = 0.0
        "--n-expansion"
            help = "Number of expansion rotors (default 3)"
            arg_type = Int
            default = 3
    end
    return parse_args(s)
end

# ── TRPT sizing optimization visualization (Item B2, Step 7) ──────────────────
"""
    render_optimized_trpt(label)

Render the optimized TRPT geometry from scripts/results/trpt_opt/<label>/best_design.json
using GLMakie.  Shows:
  - Pentagon rings tapered along the TRPT axis
  - Beam members between adjacent ring vertices (color-coded by Do)
  - Knuckle point masses at each vertex (red spheres)
  - Baseline vs optimized side-by-side if baseline.csv present
  - FOS gauge + mass readout
"""
function render_optimized_trpt(label::AbstractString)
    @eval using GLMakie

    json_path  = joinpath(dirname(@__DIR__), "scripts", "results",
                           "trpt_opt", label, "best_design.json")
    isfile(json_path) || error("best_design.json not found at $json_path")

    # Hand-rolled minimal JSON parse (matches writer format in run_trpt_optimization.jl)
    design = parse_best_design_json(json_path)

    r_top   = design["r_hub_m"]
    r_bot   = r_top * design["taper_ratio"]
    n_int   = design["n_rings"]
    L_total = design["tether_length_m"]
    n_rings_total = n_int + 2
    radii   = [r_bot + (r_top - r_bot) * (i-1)/(n_rings_total-1) for i in 1:n_rings_total]
    L_seg   = L_total / (n_rings_total - 1)
    n_lines = design["n_lines"]
    Do_top  = design["Do_top_m"]
    Do_exp  = design["Do_scale_exp"]

    fig = Figure(size=(1600, 900), fontsize=16)
    ax  = Axis3(fig[1, 1], title="Optimized TRPT — $(design["config"]) / $(design["profile"])",
                 xlabel="x (m)", ylabel="y (m)", zlabel="z — axial (m)",
                 aspect=:data)

    # Ring vertices: pentagon at each height
    for (i, r) in enumerate(radii)
        z = (i - 1) * L_seg
        Do = Do_top * (r / r_top)^Do_exp
        # Pentagon vertices
        pts_x = Float64[];  pts_y = Float64[];  pts_z = Float64[]
        for j in 1:n_lines
            φ = 2π * (j - 1) / n_lines
            push!(pts_x, r * cos(φ));  push!(pts_y, r * sin(φ));  push!(pts_z, z)
        end
        # Close the polygon for visualization
        push!(pts_x, pts_x[1]);  push!(pts_y, pts_y[1]);  push!(pts_z, pts_z[1])
        # Color by Do (larger Do = warmer color)
        col = RGBf(min(1, Do / 0.08), 0.3, 1 - min(1, Do / 0.08))
        lines!(ax, pts_x, pts_y, pts_z; color=col, linewidth=max(1, Do * 200))
        # Knuckles: red spheres at each vertex
        scatter!(ax, pts_x[1:end-1], pts_y[1:end-1], pts_z[1:end-1];
                 color=:red, markersize=8)
    end

    # Longitudinal tether lines between rings (grey)
    for j in 1:n_lines
        line_x = Float64[];  line_y = Float64[];  line_z = Float64[]
        for (i, r) in enumerate(radii)
            z = (i - 1) * L_seg
            φ = 2π * (j - 1) / n_lines
            push!(line_x, r * cos(φ));  push!(line_y, r * sin(φ));  push!(line_z, z)
        end
        lines!(ax, line_x, line_y, line_z; color=(:grey, 0.5), linewidth=1)
    end

    # Side panel: summary text
    side = fig[1, 2] = GridLayout()
    Label(side[1, 1], "Item B2 — Optimization Result"; fontsize=20, tellwidth=false,
          font=:bold)
    summary = """
    Config:         $(design["config"])
    Profile:        $(design["profile"])
    Mass (total):   $(round(design["best_mass_kg"]; digits=3)) kg
    min FOS @25m/s: $(round(design["min_fos"]; digits=3))
    n_rings:        $(design["n_rings"])
    r_hub:          $(round(design["r_hub_m"]; digits=3)) m
    taper_ratio:    $(round(design["taper_ratio"]; digits=3))
    Do_top:         $(round(design["Do_top_m"] * 1000; digits=2)) mm
    t/D:            $(round(design["t_over_D"]; digits=4))
    aspect_ratio:   $(round(design["aspect_ratio"]; digits=3))
    Do scaling exp: $(round(design["Do_scale_exp"]; digits=3))
    knuckle mass:   $(round(design["knuckle_mass_kg"] * 1000; digits=1)) g × $(n_lines * n_rings_total) vertices
    """
    Label(side[2, 1], summary; fontsize=14, tellwidth=false,
           halign=:left, justification=:left)

    display(fig)
    println("Interactive dashboard open for optimized design '$label'. Ctrl+C to quit.")
    wait(fig.scene)
end

"""
    parse_best_design_json(path) → Dict

Minimal parser for the flat-JSON format written by run_trpt_optimization.jl.
Avoids a JSON3 dependency on the hot path.
"""
function parse_best_design_json(path::AbstractString)
    txt = read(path, String)
    out = Dict{String,Any}()
    # Pull top-level scalars and nested fields with a simple regex sweep
    for (k, v) in (
        ("config", raw"\"config\"\s*:\s*\"([^\"]+)\""),
        ("profile", raw"\"profile\"\s*:\s*\"([^\"]+)\""),
        ("best_mass_kg", raw"\"best_mass_kg\"\s*:\s*([-\d.eE+]+)"),
        ("min_fos", raw"\"min_fos\"\s*:\s*([-\d.eE+]+)"),
        ("Do_top_m", raw"\"Do_top_m\"\s*:\s*([-\d.eE+]+)"),
        ("t_over_D", raw"\"t_over_D\"\s*:\s*([-\d.eE+]+)"),
        ("aspect_ratio", raw"\"aspect_ratio\"\s*:\s*([-\d.eE+]+)"),
        ("Do_scale_exp", raw"\"Do_scale_exp\"\s*:\s*([-\d.eE+]+)"),
        ("r_hub_m", raw"\"r_hub_m\"\s*:\s*([-\d.eE+]+)"),
        ("taper_ratio", raw"\"taper_ratio\"\s*:\s*([-\d.eE+]+)"),
        ("n_rings", raw"\"n_rings\"\s*:\s*([-\d.eE+]+)"),
        ("tether_length_m", raw"\"tether_length_m\"\s*:\s*([-\d.eE+]+)"),
        ("n_lines", raw"\"n_lines\"\s*:\s*([-\d.eE+]+)"),
        ("knuckle_mass_kg", raw"\"knuckle_mass_kg\"\s*:\s*([-\d.eE+]+)"),
        # Campaign-format fields (V6.x)
        ("n_expansion", raw"\"n_expansion\"\s*:\s*([-\d.eE+]+)"),
        ("bank_angle_deg", raw"\"bank_angle_deg\"\s*:\s*([-\d.eE+]+)"),
        ("blade_tip_radius", raw"\"blade_tip_radius\"\s*:\s*([-\d.eE+]+)"),
        ("blade_scale", raw"\"blade_scale\"\s*:\s*([-\d.eE+]+)"),
        ("density_profile", raw"\"density_profile\"\s*:\s*([-\d.eE+]+)"),
        ("r_bottom_m", raw"\"r_bottom_m\"\s*:\s*([-\d.eE+]+)"),
        ("target_Lr", raw"\"target_Lr\"\s*:\s*([-\d.eE+]+)"),
    )
        m = match(Regex(v), txt)
        if m !== nothing
            out[k] = k in ("config","profile") ? String(m.captures[1]) :
                     k in ("n_rings", "n_lines") ? Int(round(parse(Float64, m.captures[1]))) :
                     parse(Float64, m.captures[1])
        end
    end
    return out
end

# ── Build system from V10 campaign (raw vector + design_from_vector_v10) ──
function build_from_campaign_v10(campaign_dir::String, label::String; vector_file::String="best_vector.csv")
    vec_path = joinpath(dirname(@__DIR__), "scripts", "results", campaign_dir, vector_file)
    if !isfile(vec_path)
        error("best_vector.csv not found — run campaign first")
    end
    x_raw = parse.(Float64, split(readline(vec_path), ","))
    x = copy(x_raw)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))

    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw(); max_ground_radius=5.0, power_W=50000.0)
    design = result.design
    rotors = result.rotors
    n_lines = design.n_lines
    n_rings = result.n_rings

    # Build expansion params from rotor specs
    # Rotor ring indices from design_from_vector_v10 use intermediate
    # ring numbering (1..n_rings).  The system builder adds ground ring
    # at position 1 and hub ring at position n_rings+2, so we remap:
    #   intermediate ring i → system ring i+1
    #   intermediate ring n_rings (hub proxy) → system ring n_rings+2
    expansion_params = ExpansionRotorParams[]
    sys_n_rings_total = n_rings + 2
    for rotor in rotors
        mass_est = (0.3 + 0.1 * rotor.blade_tip_radius) * rotor.blade_scale^3
        # Remap from intermediate to system ring numbering
        sys_ring = rotor.ring_idx == n_rings ? sys_n_rings_total : rotor.ring_idx + 1
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, mass_est, sys_ring, 1.0,
        )
        push!(expansion_params, er)
    end

    # Build system params
    p_base = params_v5_50kw()
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0,
                       design.tether_length, design.r_hub, p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(p_base.tether_diameter, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    # Scale k_mppt by blade area (λ²) to match objective_v10
    λ_eff = isempty(rotors) ? 1.0 : rotors[1].blade_scale
    k_mppt_eff = p_base.k_mppt * λ_eff^2
    ctrl = ControlSpec(p_base.i_pto, k_mppt_eff, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    p_campaign = SystemParams(geo, mat, aero, ctrl, back)

    sys, u0 = build_kite_turbine_system(p_campaign; expansion_rotors=expansion_params)

    n_active = length(rotors)
    bank_str = isempty(rotors) ? "none" : "$(round(rotors[1].bank_angle_deg,digits=1)) deg"
    println("$label: n_lines=$n_lines  n_rotors=$n_active  rings=$n_rings  bank=$bank_str")
    println("  r_hub=$(round(design.r_hub,digits=2)) m  r_bottom=$(round(design.r_bottom,digits=2)) m")
    return sys, u0, p_campaign, label
end

# ── Build V10 Tight winner, drop lowest expansion rotor ──
function build_v10_tight_no_lowest()
    import JSON3
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    isfile(best_path) || error("best_design.json not found")
    best = JSON3.read(read(best_path, String))
    x = Float64[
        best.r_hub_m, best.r_bottom_m, best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, 1.0
    ]
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw(); 
                                     max_ground_radius=5.0, power_W=50000.0)
    rotors = sort(result.rotors, by=r -> r.ring_idx, rev=true)
    if length(rotors) > 1
        dropped = popfirst!(rotors)
        println("Dropped lowest expansion rotor at ring $(dropped.ring_idx)")
    end
    n_exp = length(rotors)
    n_lines = result.design.n_lines
    n_rings = result.n_rings
    expansion_params = ExpansionParams[]
    for rotor in rotors
        sr = rotor.ring_idx == n_rings ? n_rings + 2 : rotor.ring_idx + 1
        push!(expansion_params, ExpansionParams(
            ring_index=sr, n_blades=n_lines,
            blade_scale=rotor.blade_scale, bank_angle_deg=rotor.bank_angle_deg))
    end
    p_base = params_v5_50kw()
    geo = GeometrySpec(n_lines, n_rings, n_exp, result.design.r_bottom,
                       result.design.tether_length, result.design.r_hub, p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(p_base.tether_diameter, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    le = isempty(rotors) ? 1.0 : rotors[1].blade_scale
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    println("V10 Tight no-lowest: n_lines=$n_lines n_rotors=$n_exp rings=$n_rings mass=$(round(best.best_mass_kg,digits=2))kg")
    return sys, u0, pc, "V10 Tight ($n_exp rotors)"
end

# ── Build system from campaign best_design.json ──────────────────────────
function build_from_campaign(campaign_dir::String, label::String; params_fn=params_v5_50kw)
    json_path = joinpath(dirname(@__DIR__), "scripts", "results", campaign_dir, "best_design.json")
    if !isfile(json_path)
        error("best_design.json not found at $json_path — run campaign first")
    end
    design = parse_best_design_json(json_path)

    n_lines = Int(design["n_lines"])
    n_exp   = Int(design["n_expansion"])
    bank    = design["bank_angle_deg"]
    r_blade = design["blade_tip_radius"]
    blade_s = get(design, "blade_scale", 1.0)

    # Build system params from the appropriate param set
    p_base = params_fn()
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, p_base.rotor_radius,
                       design["tether_length_m"], design["r_hub_m"], p_base.trpt_rL_ratio,
                       n_lines, design["n_rings"], n_lines)  # n_blades = n_lines
    mat = MaterialSpec(p_base.tether_diameter, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    ctrl = ControlSpec(p_base.i_pto, p_base.k_mppt, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    p_campaign = SystemParams(geo, mat, aero, ctrl, back)

    # Override tether_length to match campaign design
    p_campaign = SystemParams(
        GeometrySpec(p_campaign.elevation_angle, p_campaign.lifter_elevation, p_campaign.rotor_radius,
                     design["tether_length_m"], design["r_hub_m"], p_campaign.trpt_rL_ratio,
                     n_lines, design["n_rings"], n_lines),
        mat, aero, ctrl, back
    )

    sys, u0 = build_kite_turbine_system(p_campaign)

    # Build expansion stack from campaign parameters
    # r_blade is already scaled (r_rotor_est * blade_scale), so chord = 0.113 * r_blade
    chord = 0.113 * r_blade
    cfg = ExpansionStackConfig(;
        placement=:clustered, n_rings=sys.n_ring, n_expansion=n_exp,
        n_blades=n_lines,
        blade_tip_radius=r_blade,
        blade_hub_radius=0.25 * r_blade,
        blade_chord=chord,
        CL_blade=EXP_CL_DESIGN, CD0_blade=EXP_CD0_DESIGN, k_induced=EXP_K_INDUCED,
        bank_angle_deg=bank,
        mass_per_rotor=(0.3 + 0.1 * r_blade) * blade_s^3,
        shaft_coupling=1.0,
    )
    stack = build_expansion_stack(cfg)
    sys, u0 = build_kite_turbine_system(p_campaign; expansion_rotors=stack)

    println("$label: n_lines=$n_lines  n_exp=$n_exp  bank=$(round(bank;digits=1)) deg  blade_r=$(round(r_blade;digits=2))m  lambda=$(round(blade_s;digits=3))")
    println("  rings=$(sys.n_ring)  total_nodes=$(sys.n_total)")
    return sys, u0, p_campaign, label
end

function main()
    args = parse_commandline()

    # ── Optimized-geometry mode (Item B2, Step 7) ─────────────────────────────
    if !isempty(args["optimized"])
        render_optimized_trpt(args["optimized"])
        return
    end

    # Determine initial config from CLI flags
    current_config = args["v10-tight"] ? "V10 Tight (no lowest expansion)" :
                     args["v10-island51"] ? "V10 Island 51 alt-basin" :
                     args["v10"] ? "V10 unified rotors" :
                     args["v9"] && !args["v9-10kw"] ? "V9.0 50kW equilibrium" :
                     args["v9-10kw"] ? "V9.0 10kW equilibrium" :
                     args["v67"] ? "V6.7 drag-constrained" :
                     args["v65"] ? "V6.5 3-line triangle" :
                     args["v64"] ? "V6.4 3-line triangle" :
                     args["v63"] ? "V6.3 7-line heptagon" :
                     args["v6"] || args["v62"] ? "V6.2 12-line dodecagon" :
                     args["v5"] ? "v5 Optimized 8-line" : "Canonical 5-line"
    v_target       = args["wind"]

    while true
        # ── Build system for current configuration ──────────────────────────
        if current_config == "V10 Tight (no lowest expansion)"
            # Load V10 Tight winner from best_design.json, drop lowest expansion rotor
            sys, u0, p, label = build_v10_tight_no_lowest()
        elseif current_config == "V10 Island 51 alt-basin"
            sys, u0, p, label = build_from_campaign_v10("v10_campaign_50kw", "V10 Island 51"; 
                                                         vector_file="best_vector_island51.csv")
        elseif current_config == "V10 unified rotors"
            sys, u0, p, label = build_from_campaign_v10("v10_campaign_50kw", "V10")
        elseif current_config == "V9.0 50kW equilibrium"
            sys, u0, p, label = build_from_campaign("v9_0_campaign_50kw", "V9.0 50kW")
        elseif current_config == "V9.0 10kW equilibrium"
            sys, u0, p, label = build_from_campaign("v9_0_campaign_10kw", "V9.0 10kW"; params_fn=params_10kw)
        elseif current_config == "V6.7 drag-constrained"
            sys, u0, p, label = build_from_campaign("v6_7_campaign_50kw", "V6.7 drag-constrained")
        elseif current_config == "V6.5 3-line triangle"
            sys, u0, p, label = build_from_campaign("v6_5_campaign_50kw", "V6.5 triangle")
        elseif current_config == "V6.4 3-line triangle"
            sys, u0, p, label = build_from_campaign("v6_4_campaign_50kw", "V6.4 triangle")
        elseif current_config == "V6.3 7-line heptagon"
            sys, u0, p, label = build_from_campaign("v6_3_campaign_50kw", "V6.3 heptagon")
        elseif current_config == "V6.2 12-line dodecagon"
            # V6.2 optimum: params_v6_50kw() with geometry from best_design.json
            p    = params_v6_50kw()
            sys, u0 = build_kite_turbine_system(p)
            label  = "V6.2 dodecagon"
            println("$label: $(p.n_lines) lines, $(sys.n_ring) rings, $(sys.n_total) nodes")
            # Add V6.2 expansion rotor: n_exp=1, bank=45°, at hub ring (ring_idx=1)
            r_rotor = 10.591991451982997  # from best_design.json
            cfg = ExpansionStackConfig(;
                placement=:clustered, n_rings=sys.n_ring, n_expansion=1,
                n_blades=p.n_blades,
                blade_tip_radius=r_rotor,
                blade_hub_radius=0.25 * r_rotor,
                blade_chord=0.113 * r_rotor,
                CL_blade=1.0, CD0_blade=0.02, k_induced=0.05,
                bank_angle_deg=45.0, mass_per_rotor=0.5, shaft_coupling=1.0,
            )
            stack = build_expansion_stack(cfg)
            sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)
            println("  V6.2 expansion: 1 rotor, bank=45°, blade_r=$(round(r_rotor;digits=1)) m")
        elseif current_config == "v5 Optimized 8-line"
            p    = params_v5_10kw()
            sys, u0 = build_kite_turbine_system_v5(p, 2.0, 0.336)
            label  = "v5 octagon"
        elseif current_config == "v5-safe 8-line"
            p    = params_v5_safe_10kw()
            sys, u0 = build_kite_turbine_system_v5(p, 1.61, 1.49)
            label  = "v5-safe octagon"
        else
            p    = params_10kw()
            sys, u0 = build_kite_turbine_system(p)
            label  = "canonical 5-line"
        end
        println("$label: $(p.n_lines) lines, $(sys.n_ring) rings, $(sys.n_total) nodes")
        # Expansion rotors (if requested)
        if args["expansion"] > 0.0
            bank_deg = args["expansion"]
            n_exp = args["n-expansion"]
            r_rotor = BEM.rotor_radius_for_power(10000.0, 11.0, p.n_lines)
            cfg = ExpansionStackConfig(;
                placement=:clustered, n_rings=sys.n_ring, n_expansion=n_exp,
                n_blades=p.n_blades,
                blade_tip_radius=r_rotor,
                blade_hub_radius=0.25 * r_rotor,
                blade_chord=0.113 * r_rotor,
                CL_blade=1.0, CD0_blade=0.02, k_induced=0.05,
                bank_angle_deg=bank_deg, mass_per_rotor=0.5, shaft_coupling=1.0,
            )
            stack = build_expansion_stack(cfg)
            sys, u0 = build_kite_turbine_system(p; expansion_rotors=stack)
            println("  Expansion: $n_exp rotors, bank=$bank_deg deg, blade_r=$(round(r_rotor;digits=1)) m")
        end
        # Custom wind function
        wind_fn = (pos, t) -> begin
            z  = max(pos[3], 1.0)
            sh = (z / p.h_ref)^(1.0/7.0)
            [v_target * sh, 0.0, 0.0]
        end

        println("Initializing at rated power equilibrium (ω=9.5)...")
        default_lift = rotary_lifter_default()
        u_start = settle_to_operational_state(sys, u0, p, 9.5; lift_device=default_lift, wind_fn=wind_fn)

        N  = sys.n_total
        Nr = sys.n_ring

        DT         = 4e-5
        LIN_DAMP   = 0.05
        SAVE_EVERY = 500
        # v5 has shorter ground-end segments → higher stiffness → needs smaller dt
        if current_config == "v5 Optimized 8-line"
            DT = 1e-5
            SAVE_EVERY = 2000  # keep ~same frames per simulated second
        end
        n_steps = round(Int, args["duration"] / DT)

        if args["headless"]
            # ── HEADLESS MODE ──
            println("Running headless simulation: $(args["duration"])s at $(v_target)m/s...")
            u = copy(u_start)
            results = DataFrame(t=Float64[], hub_z=Float64[], omega_hub=Float64[], P_kw=Float64[])
            run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
                lift_device = default_lift,
                lin_damp = LIN_DAMP,
                callback = (u_curr, t_curr, step) -> begin
                    if step % SAVE_EVERY == 0
                        sf = capture_frame(u_curr, sys, p, t_curr, wind_fn, default_lift; brake_engaged=sys.brake_engaged[])
                        push!(results, (sf.t, sf.hub_z, sf.omega_hub, sf.P_kw))
                    end
                end
            )
            out_path = "scripts/results/canonical_output_v$(v_target).csv"
            CSV.write(out_path, results)
            println("Done. Results saved to $out_path")
            break  # headless: one config, no switching
        else
            # ── INTERACTIVE MODE ──
            @eval using GLMakie

            n_frames = n_steps ÷ SAVE_EVERY
            frames   = Vector{Vector{Float64}}(undef, n_frames)
            times    = Vector{Float64}(undef, n_frames)
            u        = copy(u_start)

            println("Simulating $(args["duration"])s ($n_steps steps → $n_frames frames)...")
            let fi = 1
                run_canonical_sim!(u, sys, p, wind_fn, n_steps, DT;
                    lift_device = default_lift,
                    lin_damp = LIN_DAMP,
                    callback = (u_current, t_current, step) -> begin
                        if step % SAVE_EVERY == 0 && fi <= n_frames
                            frames[fi] = copy(u_current)
                            times[fi]  = t_current
                            fi += 1
                        end
                    end
                )
            end

            println("Building dashboard...")
            fig, cockpit_fig, config_changed = build_dashboard(sys, p, frames; times=times,
                                  u_settled=u_start, wind_fn=wind_fn,
                                  config_name=current_config)
            main_screen = GLMakie.Screen()
            display(main_screen, fig)
            cp_screen = GLMakie.Screen()
            display(cp_screen, cockpit_fig)  # cockpit on top
            println("Dashboard open — $(current_config). Use 'Switch Configuration' to change.")

            # Wait for window close or config switch request
            while isopen(fig.scene) && config_changed[] === nothing
                sleep(0.25)
            end

            # Check if a config switch was requested
            new_config = config_changed[]
            if new_config === nothing
                break  # User closed the window normally
            else
                current_config = new_config
                println("⟳  Switching to $(new_config)...")
                # Loop continues: rebuild system, re-run sim, re-open dashboard
            end
        end
    end
end

main()
