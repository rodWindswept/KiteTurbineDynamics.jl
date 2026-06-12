using KiteTurbineDynamics, LinearAlgebra

p = params_10kw()
sys, u0 = build_kite_turbine_system(p)

N = sys.n_total;
Nr = sys.n_ring
for s in 1:(Nr - 1)
    gid_a = sys.ring_ids[s]
    gid_b = sys.ring_ids[s + 1]
    na = sys.nodes[gid_a]::KiteTurbineDynamics.RingNode
    nb = sys.nodes[gid_b]::KiteTurbineDynamics.RingNode

    ctr_a = u0[(3 * (gid_a - 1) + 1):(3 * gid_a)]
    ctr_b = u0[(3 * (gid_b - 1) + 1):(3 * gid_b)]

    dz_0 = norm(ctr_b - ctr_a)
    dr = nb.radius - na.radius

    println("Seg ", s, ": dz_0=", dz_0, ", r_a=", na.radius, ", r_b=", nb.radius)
end
