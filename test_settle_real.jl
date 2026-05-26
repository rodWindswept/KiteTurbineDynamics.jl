using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)
wf = (pos, t) -> [11.0, 0.0, 0.0]

u_s = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf)

du = zeros(length(u_s))
multibody_ode!(du, u_s, (sys, p, wf, ld), 0.0)

bgid = sys.bearing_id
sgid = sys.sky_anchor_id
bacc = du[3*sys.n_total+3*(bgid-1)+1 : 3*sys.n_total+3*bgid]
sacc = du[3*sys.n_total+3*(sgid-1)+1 : 3*sys.n_total+3*sgid]

println("Bearing Acc: ", bacc)
println("Sky Anchor Acc: ", sacc)

println("Bearing Force: ", bacc .* 0.3)
println("Sky Anchor Force: ", sacc .* 0.3)
