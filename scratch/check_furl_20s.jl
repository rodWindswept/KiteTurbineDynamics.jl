# scratch/check_furl_20s.jl
using KiteTurbineDynamics, LinearAlgebra, Printf

# Helper function to modify immutable SystemParams
function _modified_params(base::SystemParams; kwargs...)
    fnames    = fieldnames(SystemParams)
    ftypes    = fieldtypes(SystemParams)
    overrides = Dict{Symbol,Any}(kwargs)
    vals = ntuple(length(fnames)) do i
        convert(ftypes[i], get(overrides, fnames[i], getfield(base, fnames[i])))
    end
    SystemParams(vals...)
end

println("Loading 10kW canonical parameters...")
p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
v_wind = 11.0 # Rated wind speed
wf = (pos, t) -> begin
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [v_wind * sh, 0.0, 0.0]
end

println("Settling to operational equilibrium (ω=9.5)...")
ω_rated = cbrt(p.p_rated_w / p.k_mppt)
u_settled = settle_to_operational_state(sys, u0, p, ω_rated; lift_device=ld, wind_fn=wf)

u = copy(u_settled)
N = sys.n_total; Nr = sys.n_ring
dt = 4e-5
t_total = 20.0
n_steps = round(Int, t_total / dt)
du = zeros(length(u))

println("Running 20.0s Furl simulation...")
save_every = round(Int, 1.0 / dt) # print every 1 second

for step in 1:n_steps
    t = step * dt
    
    # Winch payout controller
    furl_delay    = t_total / 6
    furl_duration = 5 * t_total / 6
    x             = clamp((t - furl_delay) / furl_duration, 0.0, 1.0)
    release_frac  = x * x * x   # cubic ease-in
    p_furl = _modified_params(p; backline_payout = 15.0 * release_frac)
    ode_p = (sys, p_furl, wf, ld)

    fill!(du, 0.0)
    multibody_ode!(du, u, ode_p, t)
    @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
    @views u[1:3N]            .+= dt .* u[3N+1:6N]
    @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
    @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
    KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p_furl, 0.05)
    
    # Co-braking during furl
    if release_frac > 0.0
        @views u[6N+Nr+1:6N+2Nr] .*= (1.0 - release_frac * 1e-5)
    end
    u[1:3] .= 0.0; u[3N+1:3N+3] .= 0.0

    if step % save_every == 0 || step == n_steps
        # Compute telemetry
        # Reconstruct state at t
        sf = capture_frame(u, sys, p_furl, t, wf, ld)
        println("--- t = $(round(t, digits=1))s (payout = $(round(p_furl.backline_payout, digits=2))m) ---")
        @printf("  Hub ω: %6.3f rad/s | PTO ω: %6.3f rad/s\n", sf.omega_hub, sf.omega_gnd)
        @printf("  Hub Elevation: %.1f deg (design %.1f deg)\n", rad2deg(atan(u[3*(sys.rotor.node_id-1)+3], u[3*(sys.rotor.node_id-1)+1])), rad2deg(p.elevation_angle))
        @printf("  Max tether tension: %6.1f N | FoS: %s\n", sf.T_max, (sf.fos_tether > 9999 ? "Inf" : @sprintf("%.1f", sf.fos_tether)))
        @printf("  Slack tethers: %d lines\n", sf.n_slack)
        @printf("  Max ring buckling util: %6.1f%% | FoS: %s\n", sf.ring_max_util*100.0, (sf.fos_ring > 9999 ? "Inf" : @sprintf("%.1f", sf.fos_ring)))
        
        # Print details of ring utilisation
        for k in 1:length(sf.ring_beam_utils)
            utils = sf.ring_beam_utils[k]
            @printf("    Ring %d max util: %6.1f%%\n", k, maximum(utils)*100.0)
        end
    end
end
