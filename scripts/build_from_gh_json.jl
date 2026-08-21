# scripts/build_from_gh_json.jl
#
# KTD.jl importer for Grasshopper design exports (schema "ktd-gh-design/v1",
# written by scripts/gh_export_ktd.py).
#
# Usage (headless):
#   julia --project=. -e '
#     include("scripts/build_from_gh_json.jl");
#     sys, u0, p, label = build_from_gh_json("scripts/gh_designs/my_design.json");
#     run_canonical_sim!(sys, u0, p)'      # always run_canonical_sim! (CLAUDE.md rule 3)
#
# Or from the dashboard: include this file and call build_from_gh_json(...)
# wherever a builders_util.jl-style (sys, u0, p, label) tuple is expected.
#
# What is imported:  ring stack (exact measured radii + axial positions),
# n_lines, and per-ring rotors (signed blade offsets, chord, bank).
# What is NOT imported:  bridle/fuselage detail (below KTD resolution),
# masses, materials, control gains — these default from `params_fn` and
# should be re-tuned (k_mppt via scripts/hunt_kmppt_bisect.jl).

using KiteTurbineDynamics
using JSON3
using Statistics: mean

"""
    build_from_gh_json(json_path; params_fn=params_v5_50kw,
                       tether_diameter=nothing, exact_rings=true,
                       kite_area=10.0, kite_mass=5.0, kite_tether_length=20.0)
        → (sys, u0, p, label)

Build a KiteTurbineSystem from a Grasshopper design.json.

- `exact_rings=true`  → pass the measured ring radii and segment lengths
  straight into the system builder (faithful to the Rhino model).
- `exact_rings=false` → idealise via ring_spacing_v4 (constant-L/r taper,
  same path as DE campaign designs), using mean_Lr from the JSON.

Rotor convention (matches gh_export_ktd.py): `ring_idx` is 1-based in the
full stack (1 = ground ring … n = hub ring).  Blade offsets are SIGNED
distances from the ring radius; the physical blades straddle the ring
(hub_offset < 0 = annulus reaches inside the ring).  A rotor at the hub
ring is NOT converted to an ExpansionRotorParams — the hub rotor is the
Cp-disc model; its measured tip radius sets `rotor_radius` instead.
"""
function build_from_gh_json(json_path::String;
    params_fn=params_v5_50kw,
    tether_diameter::Union{Nothing,Float64}=nothing,
    exact_rings::Bool=true,
    kite_area::Float64=10.0,
    kite_mass::Float64=5.0,
    kite_tether_length::Float64=20.0,
)
    d = JSON3.read(read(json_path, String))
    d.schema == "ktd-gh-design/v1" ||
        error("Unsupported schema '$(d.schema)' (expected ktd-gh-design/v1)")

    ring_r = Float64.(collect(d.ring_radii_m))
    ring_z = Float64.(collect(d.ring_z_m))
    n_stack = length(ring_r)
    n_stack >= 3 || error("Need ≥3 rings in stack (ground + ≥1 spacer + hub)")
    length(ring_z) == n_stack || error("ring_radii_m / ring_z_m length mismatch")
    issorted(ring_z) || error("ring_z_m must be sorted ground → hub")

    n_rings  = n_stack - 2                     # intermediate rings
    n_lines  = Int(d.n_lines)
    r_hub    = ring_r[end]
    r_bottom = ring_r[1]
    tether_length = ring_z[end] - ring_z[1]

    p_base = params_fn()

    # ── rotors ────────────────────────────────────────────────────────────
    rotors = haskey(d, :rotors) ? d.rotors : []
    rotor_radius = p_base.rotor_radius         # fallback if no hub rotor wired
    expansion_params = ExpansionRotorParams[]
    for ro in rotors
        ri   = Int(ro.ring_idx)
        1 <= ri <= n_stack || error("rotor ring_idx $ri outside stack 1..$n_stack")
        tip  = Float64(ro.tip_offset_m)
        hub  = Float64(ro.hub_offset_m)
        bank = Float64(ro.bank_angle_deg)
        tip > hub || error("rotor @ ring $ri: tip_offset must exceed hub_offset")
        if ri == n_stack
            # Hub rotor → Cp-disc: absolute tip radius in the rotation plane
            rotor_radius = r_hub + tip * cosd(bank)
            continue
        end
        chord = ro.chord_m === nothing ? nothing : Float64(ro.chord_m)
        chord === nothing &&
            error("rotor @ ring $ri has no chord_m — set chord_m in the GH exporter")
        push!(expansion_params, ExpansionRotorParams(
            Int(get(ro, :n_blades, n_lines)),
            tip, hub, chord,                    # signed offsets from ring radius
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            bank, 0.0, ri, 1.0,
        ))
    end

    # ── params ────────────────────────────────────────────────────────────
    td  = tether_diameter === nothing ? p_base.tether_diameter : tether_diameter
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation,
                       rotor_radius, tether_length, r_hub, p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(td, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    ctrl = ControlSpec(p_base.i_pto, p_base.k_mppt, p_base.p_rated_w,
                       p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line,
                        p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)

    # ── build ─────────────────────────────────────────────────────────────
    if exact_rings
        seg_lengths = max.(diff(ring_z), 1e-6)
        sys, u0 = KiteTurbineDynamics._build_kite_turbine_system_impl(
            pc, ring_r, seg_lengths;
            kite_area=kite_area, kite_mass=kite_mass,
            kite_tether_length=kite_tether_length,
            expansion_rotors=expansion_params)
    else
        target_Lr = haskey(d, :mean_Lr) && d.mean_Lr !== nothing ?
            Float64(d.mean_Lr) :
            mean(diff(ring_z) ./ ((ring_r[1:end-1] .+ ring_r[2:end]) ./ 2))
        sys, u0 = build_kite_turbine_system_v5(pc, target_Lr, r_bottom;
            kite_area=kite_area, kite_mass=kite_mass,
            kite_tether_length=kite_tether_length,
            expansion_rotors=expansion_params)
    end

    label = String(get(d, :label, splitext(basename(json_path))[1]))
    println("GH import '$label': n_lines=$n_lines, $n_stack rings " *
            "(r $(round(r_bottom, digits=2))→$(round(r_hub, digits=2)) m, " *
            "L=$(round(tether_length, digits=1)) m), " *
            "$(length(expansion_params)) expansion rotor(s), " *
            "rotor_radius=$(round(rotor_radius, digits=2)) m " *
            "[k_mppt=$(round(pc.k_mppt, digits=1)) from $(nameof(params_fn)) — re-hunt!]")
    return sys, u0, pc, label
end
