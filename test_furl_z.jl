using KiteTurbineDynamics, LinearAlgebra

function _modified_params(base::SystemParams; kwargs...)
    fnames    = fieldnames(SystemParams)
    ftypes    = fieldtypes(SystemParams)
    overrides = Dict{Symbol,Any}(kwargs)
    vals = ntuple(length(fnames)) do i
        convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
    end
    SystemParams(vals...)
end

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
wf = (pos, t) -> [11.0, 0.0, 0.0]
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)
u_s = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf)

println("Initial Bearing Z: ", u_s[3*(sys.bearing_id-1)+3])

N = sys.n_total; Nr = sys.n_ring
u = copy(u_s)
dt = 4e-5
du = zeros(length(u))

for step in 1:25000 # 1.0 second
    t = step * dt
    if step % 500 == 0
        release_frac = clamp(t / 25.0, 0.0, 1.0)
        p_furl = _modified_params(p; backline_payout = 15.0 * release_frac)
        base_boost = clamp(1.0 + 0.5 * (t / 5.0), 1.0, 1.5)
        ω_gnd_now = abs(u[6N + Nr + 1])
        P_now = p.k_mppt * ω_gnd_now^3 / 1000.0
        P_rated_kw = p.p_rated_w / 1000.0
        excess = max(0.0, P_now - P_rated_kw)
        power_boost = 1.0 + 2.0 * excess / P_rated_kw
        boost = clamp(max(base_boost, power_boost), 1.0, 3.0)
        
        ld_furl = RotaryLifterParams(ld.rotor_radius, ld.hub_radius, ld.n_blades, ld.blade_chord, ld.CL_blade * boost, ld.CD_blade, ld.omega_fixed, ld.line_length, ld.line_EA, ld.m_lifter)
        global ode_p = (sys, p_furl, wf, ld_furl)
    end
    if !@isdefined(ode_p)
        global ode_p = (sys, p, wf, ld)
    end

    fill!(du, 0.0)
    multibody_ode!(du, u, ode_p, t)
    @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
    @views u[1:3N]            .+= dt .* u[3N+1:6N]
    @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
    @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
    KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, 0.05)
    u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0
    
    if step % 2500 == 0
        println("t=", t, " Bearing Z: ", u[3*(sys.bearing_id-1)+3], " Sky Z: ", u[3*(sys.sky_anchor_id-1)+3])
    end
end
