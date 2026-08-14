using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
kw=5.0; pw=5000.0
p=mass_scale(params_10kw(),10.0,kw)
x=seed_genome(kw)
x[8]=Float64(round(Int,clamp(x[8],3,16)))
x[10]=clamp(x[10],0.0,Float64(N_VALID_MASKS))
dec=design_from_vector_v10(x,PROFILE_ELLIPTICAL,p;power_W=pw)
sys,u0,pc=KiteTurbineDynamics.build_system_from_v10(dec,1.0,p.k_mppt;tether_diameter=p.tether_diameter)
wind_fn(r,t)=[p.v_wind_ref,0.0,0.0]
u=settle_to_operational_state(sys,copy(u0),pc,9.5;lift_device=rotary_lifter_default(),wind_fn=wind_fn,n_op=20_000)
println("Settled ω=", round(u[6*sys.n_total+sys.n_ring+sys.n_ring],digits=2))
sys.k_mppt_ref[]=p.k_mppt
dt=4e-5; n_steps=500_000
run_canonical_sim!(u,sys,pc,wind_fn,n_steps,dt;lift_device=rotary_lifter_default(),lin_damp=0.05)
ωf=u[6*sys.n_total+sys.n_ring+sys.n_ring]
gnd_ri=(sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
ωg=u[6*sys.n_total+sys.n_ring+gnd_ri]
tau_gen,_=get_generator_torque(u,sys,p,20.0,wind_fn;brake_engaged=sys.brake_engaged[])
Pf=tau_gen*max(ωg,0.0)/1000
println("FINAL: ω=",round(ωf,digits=2)," P=",round(Pf,digits=2),"kW")
