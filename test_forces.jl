using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)

wf_furl = (pos, t) -> begin
    z = max(pos[3], 1.0);
    sh = (z / p.h_ref)^(1/7)
    [11.0 * sh, 0.0, 0.0]
end
u_furl = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_furl)

du = zeros(length(u_furl))
multibody_ode!(du, u_furl, (sys, p, wf_furl, ld), 0.0)

bacc = du[(3 * sys.n_total + 3 * (sys.bearing_id - 1) + 1):(3 * sys.n_total + 3 * sys.bearing_id)]
sacc = du[(3 * sys.n_total + 3 * (sys.sky_anchor_id - 1) + 1):(3 * sys.n_total + 3 * sys.sky_anchor_id)]

println("Furl Bearing Acc: ", bacc)
println("Furl Sky Anchor Acc: ", sacc)
