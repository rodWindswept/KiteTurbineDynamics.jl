# scratch/r7_cycle_dt.jl — is the ~10 s load limit cycle numerical or physical?
# Run the same settled state for 60 s at dt and dt/2 and compare the ring-load
# trace. A numerical limit cycle changes period/amplitude with dt; a physical
# one does not.
using KiteTurbineDynamics, Printf, Statistics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

p = params_5kw_188()
x = seed_genome(5.0)
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    k_mppt=K_MPPT_5KW_HONEST)
sizing = size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
dt0 = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
u_settled = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
@printf("dt0 = %.3e\n", dt0)

function trace(scale::Float64, secs::Float64=40.0, sample::Float64=2.0; lin_damp::Float64=0.05)
    dt = dt0 * scale
    u = copy(u_settled)
    N = sys.n_total
    Nr = sys.n_ring
    n_chunk = round(Int, sample / dt)
    n = round(Int, secs / sample)
    Nc = Float64[]; T1 = Float64[]; Tl = Float64[]; wg = Float64[]
    for _ in 1:n
        run_canonical_sim!(u, sys, pc, wf, n_chunk, dt; lift_device=lift, lin_damp=lin_damp)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
        push!(Nc, ef.ring_Ncomp[1])
        push!(T1, ef.segment_tension[1])
        push!(Tl, ef.base.T_lift)
        push!(wg, u[6N + Nr + 1])
    end
    return Nc, T1, Tl, wg
end

for ld in (0.0, 0.05)
    for sc in (1.0, 0.5)
        Nc, T1, Tl, wg = trace(sc; lin_damp=ld)
        @printf("lin_damp=%.2f scale=%.2f  N_ring2 mean=%.1f min=%.1f max=%.1f range=%.1f  T_seg1 mean=%.1f\n",
            ld, sc, mean(Nc), minimum(Nc), maximum(Nc), maximum(Nc)-minimum(Nc), mean(T1))
        println("   N: ", join(round.(Nc, digits=0), ","))
        flush(stdout)
    end
end
