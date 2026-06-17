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
ld = rotary_lifter_default()
v_wind = 11.0
wf_steady = (pos, t) -> begin
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [v_wind * sh, 0.0, 0.0]
end
ω = cbrt(p.p_rated_w / p.k_mppt)
u_settled = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_steady)

# How far does the kite pull the sky anchor just with payout, NO BOOST?
u_furl = copy(u_settled)
N = sys.n_total; Nr = sys.n_ring
dt = 4e-5
du = zeros(length(u_furl))

# 1 second of payout, NO boost
for step in 1:25000
    t = step * dt
    release_frac = clamp(t / 25.0, 0.0, 1.0)
    # Give it a lot of payout to see if it rises
    p_furl = _modified_params(p; backline_payout = 15.0 * release_frac)
    
    ode_p = (sys, p_furl, wf_steady, ld)

    fill!(du, 0.0)
    multibody_ode!(du, u_furl, ode_p, t)
    @views u_furl[3N+1:6N]        .+= dt .* du[3N+1:6N]
    @views u_furl[1:3N]            .+= dt .* u_furl[3N+1:6N]
    @views u_furl[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
    @views u_furl[6N+1:6N+Nr]     .+= dt .* u_furl[6N+Nr+1:6N+2Nr]
    KiteTurbineDynamics.orbital_damp_rope_velocities!(u_furl, sys, p, 0.05)
    u_furl[1:3] .= 0.0; u_furl[3N+1:3N+3] .= 0.0
end

bgid = sys.bearing_id
sgid = sys.sky_anchor_id
println("Initial Sky Anchor Z: ", u_settled[3*(sgid-1)+3])
println("After 1s Payout Sky Anchor Z: ", u_furl[3*(sgid-1)+3])

println("\nInitial TRPT Hub Z: ", u_settled[3*(sys.rotor.node_id-1)+3])
println("After 1s Payout TRPT Hub Z: ", u_furl[3*(sys.rotor.node_id-1)+3])

# Does the elevation angle of the TRPT increase?
hub_x_init = u_settled[3*(sys.rotor.node_id-1)+1]
hub_z_init = u_settled[3*(sys.rotor.node_id-1)+3]
beta_init = atand(hub_z_init, hub_x_init)

hub_x_furl = u_furl[3*(sys.rotor.node_id-1)+1]
hub_z_furl = u_furl[3*(sys.rotor.node_id-1)+3]
beta_furl = atand(hub_z_furl, hub_x_furl)

println("\nInitial TRPT Elevation: ", beta_init, " deg")
println("After 1s Payout TRPT Elevation: ", beta_furl, " deg")

