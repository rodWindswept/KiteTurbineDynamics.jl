# READ-ONLY. Is a global perpendicular motion of the ring stack stiff or soft?
# Perturb the hub and the ring stack in the perpendicular direction and read the
# FORCE response (not acceleration).  If a global move is soft, the bow is reachable
# by a rigid-ish rearrangement; if stiff, stretching blocks it.
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))
pos(u,g)=u[(3*(g-1)+1):(3*g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr; u[6N+Nr+k] = 12.983466; end
    @views u[(3N+1):6N] .= 0.0
    axis = normalize(pos(u,hub))
    up = [0.0,0.0,1.0]; perp = normalize(up .- dot(up,axis).*axis)
    ssz = 6N+2Nr
    function F(uu)
        du = zeros(ssz); KiteTurbineDynamics.multibody_ode!(du, uu, (sys,p,wf,lift), 0.0)
        return [ (sys.nodes[g]).mass .* du[(3N+3*(g-1)+1):(3N+3*g)] for g in 1:N ]
    end
    F0 = F(u)
    hubforce(Fs) = Fs[hub]
    perpcomp(Fv) = dot(Fv, perp)
    @printf("hub perpendicular force at rest = %+.4f N\n", perpcomp(hubforce(F0)))
    @printf("\n  %10s %16s %16s %14s\n","delta_m","hub_F_perp_N","sum_stack_F_perp","k_N/m")
    prev=nothing
    for d in (0.0, 1e-3, 1e-2, 5e-2, 0.1, 0.25, 0.5)
        uu = copy(u)
        # move the WHOLE ring stack + bearing + sky, i.e. a global rigid translation
        for g in vcat(sys.ring_ids, sys.bearing_id, sys.sky_anchor_id)
            uu[(3*(g-1)+1):(3*g)] .+= d .* perp
        end
        uu[1:3] .= 0.0   # keep the ground anchor pinned
        Fs = F(uu)
        hf = perpcomp(Fs[hub])
        stot = sum(perpcomp(Fs[g]) for g in sys.ring_ids[2:end])
        k = prev === nothing || d == 0.0 ? NaN : (hf - prev)/d
        @printf("  %10.4f %16.4f %16.4f %14.4e\n", d, hf, stot, k)
        prev = hf
    end
    println("\n(positive k = restoring; small k = soft/global mode, large k = blocked by stretching)")
end
main()
