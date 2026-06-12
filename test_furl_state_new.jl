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

wf_steady = (pos, t) -> begin
    v = t < 2.0 ? 11.0*(t/2.0) : 11.0
    z = max(pos[3], 1.0);
    sh = (z / p.h_ref)^(1/7)
    [v * sh, 0.0, 0.0]
end
u_settled = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_steady)
u_furl = settle_to_operational_state(sys, u_settled, p, ω; lift_device=ld, wind_fn=wf_furl)

println("--- FURL FRAME 0 ---")
bgid = sys.bearing_id
sgid = sys.sky_anchor_id

du = zeros(length(u_furl))
multibody_ode!(du, u_furl, (sys, p, wf_furl, ld), 0.0)
N = sys.n_total
println("Bearing Acc: ", du[(3N + 3 * (bgid - 1) + 1):(3N + 3 * bgid)])
println("Sky Anchor Acc: ", du[(3N + 3 * (sgid - 1) + 1):(3N + 3 * sgid)])
