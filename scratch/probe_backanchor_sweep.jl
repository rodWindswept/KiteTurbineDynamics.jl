# scratch/probe_backanchor_sweep.jl
#
# Back-line work item (2026-09-22): does moving the ground anchor DOWNWIND bring
# the demanded back-line tension below the 320 N hard stop, so the sky anchor can
# operate on its elastic travel?
#
# Rod's field rule: place the backline ground anchor ~2 m DOWNWIND of the sky
# anchor's axial projection.  The model instead carries a prespecified constant
# (`back_anchor_fwd_x`), which for these candidates puts the ground anchor UPWIND
# of the projection and makes the back line nearly vertical — anti-parallel to the
# lift line, so it acts as a pure tension sink.
#
# The sky anchor sits where the two cut lengths meet (`_sky_anchor_design_pos`), so
# `fwd_x` moves BOTH the anchor position and the 2x2 split.  This sweep reports
# the split, the line elevation and the angle to the lift line for each offset.
# Design-time only: no settle, no ODE.
#
# Usage: julia --project=. scratch/probe_backanchor_sweep.jl [island_dir ...]

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
elev(v) = rad2deg(atan(v[3], hypot(v[1], v[2])))

function run_island(ISLAND)
    CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")
    p0 = params_at_length(params_daisy(), 18.8, 5.0)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p0, cfg)
    sys, u0, p = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
        beam_sizing=sizing)
    lift = lift_for(sys, p)
    hub_gid = sys.rotor.node_id
    hub_pos = pos(u0, hub_gid)
    ω = 13.7084

    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    _, T_lift, el_deg = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    lift_dir = [cos(deg2rad(el_deg)), 0.0, sin(deg2rad(el_deg))]
    T_hard = KiteTurbineDynamics.BACK_LINE_T_DESIGN_N

    @printf("\n═══════════ %s   T_lift=%.1f N  lift elev=%.1f deg  T_hard=%.0f N ═══════════\n",
        ISLAND, T_lift, el_deg, T_hard)
    @printf("%8s %9s %9s %9s %9s %9s %9s %9s\n",
        "fwd_x", "sky_x", "downwind", "back_elev", "ang(l,b)", "T_back", "T_cyan", "soft?")

    for fwd in (6.901, 8.0, 9.0, 10.0, 11.0, 12.0, 14.0, 16.0)
        pp = KiteTurbineDynamics.override_params(p; back_anchor_fwd_x=fwd)
        d = KiteTurbineDynamics.lift_chain_design(sys, pp, lift, hub_pos; omega_eq=ω)
        d === nothing && continue
        back_ax = pp.tether_length * cos(β) + fwd
        sky, back_dir = KiteTurbineDynamics._sky_anchor_design_pos(pp, hub_pos)
        downwind = back_ax - sky[1]
        ang_lb = rad2deg(acos(clamp(dot(lift_dir, back_dir), -1.0, 1.0)))
        @printf("%8.3f %9.3f %+9.3f %9.2f %9.2f %9.2f %9.2f %9s\n",
            fwd, sky[1], downwind, elev(back_dir), ang_lb, d.T_back, d.T_cyan,
            d.T_back < T_hard ? "YES" : "no")
    end
    @printf("  (downwind = ground anchor x − sky anchor x; + = anchor is downwind)\n")
    return nothing
end

islands = isempty(ARGS) ? ["island_1", "island_3"] : ARGS
for isl in islands
    run_island(isl)
end
println("\n=== done ===")
