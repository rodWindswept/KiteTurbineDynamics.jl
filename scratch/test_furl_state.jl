using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)
ld = rotary_lifter_default()
ω = cbrt(p.p_rated_w / p.k_mppt)

wf_furl = (pos, t) -> begin
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [11.0 * sh, 0.0, 0.0]
end

# To emulate dashboard exactly:
wf_steady = (pos, t) -> begin
    v = t < 2.0 ? 11.0*(t/2.0) : 11.0
    z = max(pos[3], 1.0); sh = (z / p.h_ref)^(1/7)
    [v * sh, 0.0, 0.0]
end
u_settled = settle_to_operational_state(sys, u0, p, ω; lift_device=ld, wind_fn=wf_steady)

u_furl = settle_to_operational_state(sys, u_settled, p, ω; lift_device=ld, wind_fn=wf_furl)

println("--- FURL FRAME 0 ---")
bgid = sys.bearing_id
sgid = sys.sky_anchor_id
println("Bearing: ", u_furl[3*(bgid-1)+1:3*bgid])
println("Sky Anchor: ", u_furl[3*(sgid-1)+1:3*sgid])

# Check TRPT tensions
N = sys.n_total; Nr = sys.n_ring
for s in Nr-2:Nr-1
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s+1]
    pa = u_furl[3*(gid_a-1)+1:3*gid_a]
    pb = u_furl[3*(gid_b-1)+1:3*gid_b]
    println("Ring ", s, " to ", s+1, " dist: ", norm(pb - pa))
end

# Check Cyan tension
cyan_l = norm(u_furl[3*(sgid-1)+1:3*sgid] - u_furl[3*(bgid-1)+1:3*bgid])
println("Cyan length: ", cyan_l, " (L0=5.0)")

# Check acceleration
du = zeros(length(u_furl))
KiteTurbineDynamics.multibody_ode!(du, u_furl, (sys, p, wf_furl, ld), 0.0)
println("Bearing Acc: ", du[3N+3*(bgid-1)+1:3N+3*bgid])
println("Sky Anchor Acc: ", du[3N+3*(sgid-1)+1:3N+3*sgid])
