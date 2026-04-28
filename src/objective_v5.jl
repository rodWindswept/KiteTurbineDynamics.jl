# V5: BEM-coupled rotor radius replaces the fixed r_rotor from v4.
# TRPTDesignV5 is structurally identical to TRPTDesignV4; n_lines drives BEM sizing.

const TRPTDesignV5 = TRPTDesignV4

function evaluate_design_v5(design::TRPTDesignV4;
                             power_W          :: Float64 = 50_000.0,
                             v_rated          :: Float64 = 12.0,
                             elev_angle       :: Float64 = π/6,
                             v_peak           :: Float64 = OPT_V_PEAK,
                             fos_req          :: Float64 = OPT_FOS_REQUIRED,
                             omega_rotor      :: Float64 = 4.1 * OPT_V_PEAK / 5.0,
                             m_blade_total    :: Float64 = 11.0,
                             max_ground_radius:: Float64 = OPT_MAX_GROUND_RADIUS)
    r_rotor = BEM.rotor_radius_for_power(power_W, v_rated, design.n_lines)
    return evaluate_design(design;
                           r_rotor=r_rotor,
                           elev_angle=elev_angle,
                           v_peak=v_peak,
                           fos_req=fos_req,
                           omega_rotor=omega_rotor,
                           m_blade_total=m_blade_total,
                           max_ground_radius=max_ground_radius)
end

const search_bounds_v5      = search_bounds_v4
const design_from_vector_v5 = design_from_vector_v4

function objective_v5(x::AbstractVector, beam_profile::BeamProfile, p::SystemParams;
                       power_W          :: Float64 = 50_000.0,
                       v_rated          :: Float64 = 12.0,
                       elev_angle       :: Float64 = π/6,
                       v_peak           :: Float64 = OPT_V_PEAK,
                       max_ground_radius:: Float64 = OPT_MAX_GROUND_RADIUS)
    design = design_from_vector_v4(x, beam_profile, p; max_ground_radius=max_ground_radius)
    r      = evaluate_design_v5(design;
                                 power_W=power_W, v_rated=v_rated,
                                 elev_angle=elev_angle, v_peak=v_peak,
                                 max_ground_radius=max_ground_radius)
    return r.feasible ? r.mass_total_kg : 1e6 + r.mass_total_kg
end
