# scratch/test_crossing_preload_eval.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

# 1. Test the logic on build_case
sys, u0, p, lift, wf = build_case(nothing, nothing)
N, Nr = sys.n_total, sys.n_ring
τ_eq = sys.k_mppt_ref[] * 13.452^2

println("Testing crossing-aware preload enforcement:")
# Let us run design_axial_preload with our logic
n_seg = Nr - 1
β = p.elevation_angle
d = KTD.lift_chain_design(
    sys,
    p,
    lift,
    u0[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)];
    omega_eq=13.452,
)
F_top = d.T_top
g_inc = p.m_ring * 9.81 * sin(β)
F_ax = zeros(n_seg)
function rebuild!(Ftop)
    F_ax[n_seg] = Ftop
    for i in (n_seg - 1):-1:1
        F_ax[i] = F_ax[i + 1] + g_inc
    end
end
rebuild!(F_top)

realisability_margin = 1.05
target = 1.0 / realisability_margin
target_cross = 0.95 # keep crossing ratio <= 0.95

F_curr = F_top
for iter in 1:12
    rebuild!(F_curr)
    place = KTD.trpt_matched_place(
        sys, p, F_ax, τ_eq, 13.452, wf; raise_on_unrealisable=false
    )
    worst_dem = maximum(place.demand)
    worst_cross = 0.0
    for ri in 1:n_seg
        da = abs(place.α[ri + 1] - place.α[ri])
        ra = (sys.nodes[sys.ring_ids[ri]]::KTD.RingNode).radius
        rb = (sys.nodes[sys.ring_ids[ri + 1]]::KTD.RingNode).radius
        rs = max(ra, rb)
        L_s = norm(place.ctrs[ri + 1] - place.ctrs[ri])
        ds = 2 * asin(min(L_s / sqrt(2 * (L_s^2 + 2 * rs^2)), 1.0))
        worst_cross = max(worst_cross, da / max(ds, 1e-9))
    end
    @printf(
        "  iter %2d: F_top=%.1f N | worst demand=%.4f (target %.4f) | worst cross=%.4f (target %.4f)\n",
        iter,
        F_curr,
        worst_dem,
        target,
        worst_cross,
        target_cross
    )
    if worst_dem <= target * (1.0 + 1e-9) && worst_cross <= target_cross * (1.0 + 1e-9)
        println("  -> Cleared at F_top = ", F_curr)
        break
    end
    step = max(worst_dem / target, worst_cross / target_cross)
    global F_curr *= step
end
