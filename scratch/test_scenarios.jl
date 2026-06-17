using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)

println("--- FURL SETTLE ---")
wf_furl = (pos, t) -> begin
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [11.0 * sh, 0.0, 0.0]
end
u_furl = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_furl)
spos = u_furl[3*(sys.sky_anchor_id-1)+1:3*sys.sky_anchor_id]
bpos = u_furl[3*(sys.bearing_id-1)+1:3*sys.bearing_id]
println("Furl Sky Anchor: ", spos)
println("Furl Bearing: ", bpos)

println("\n--- STEADY SETTLE ---")
wf_steady = (pos, t) -> begin
    v = t < 2.0 ? 11.0*(t/2.0) : 11.0
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [v * sh, 0.0, 0.0]
end
u_steady = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_steady)
spos_s = u_steady[3*(sys.sky_anchor_id-1)+1:3*sys.sky_anchor_id]
bpos_s = u_steady[3*(sys.bearing_id-1)+1:3*sys.bearing_id]
println("Steady Sky Anchor: ", spos_s)
println("Steady Bearing: ", bpos_s)
