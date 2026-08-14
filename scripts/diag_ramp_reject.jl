using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
kw=5.0; pw=5000.0
p=mass_scale(params_10kw(),10.0,kw)
x=seed_genome(kw); x[8]=Float64(round(Int,clamp(x[8],3,16)))
x[10]=clamp(x[10],0.0,Float64(N_VALID_MASKS))
dec=design_from_vector_v10(x,PROFILE_ELLIPTICAL,p;power_W=pw)
d=dec.design; rotors=dec.rotors
ep=KiteTurbineDynamics.expansion_params_from_rotors(rotors,dec.n_rings,d.n_lines)
zs,radii,_=ring_spacing_v4(d.r_hub,d.r_bottom,d.tether_length,d.target_Lr;density_profile=d.density_profile)
leff = dec.n_active > 0 ? rotors[1].blade_scale : 1.0
keff=p.k_mppt*leff^2
ps=override_params(p;k_mppt=keff)
println("n_active=",dec.n_active," λ_eff=",leff," k_mppt_eff=",round(keff,digits=3))
println("rotor_radius=",round(p.rotor_radius,digits=2)," tether=",round(p.tether_length,digits=1))
weq,rref=solve_equilibrium_self_consistent(d,ep,ps,d.n_lines,radii,zs;P_per_rotor=pw/max(dec.n_active,1),v_wind=11.0,elev_rad=π/6)
if weq===nothing
 println("ω_eq = nothing — EQUILIBRIUM SOLVER FAILED")
else
 println("ω_eq = ",round(weq,digits=2)," rad/s")
end
# Also check Betz gate
A_total=π*p.rotor_radius^2
for rotor in rotors
 A_total+=π*rotor.blade_tip_radius^2*cosd(rotor.bank_angle_deg)
end
Betz_cp=0.593*0.5*p.rho*A_total*11.0^3/1000
Betz_cp_kW=p.cp*0.5*p.rho*A_total*11.0^3/1000
println("A_total=",round(A_total,digits=1),"m² Betz_ceiling=",round(Betz_cp,digits=1),"kW Betz_cp=",round(Betz_cp_kW,digits=1),"kW floor*0.8=",2.5*0.8,"kW")
if Betz_cp_kW<2.0; println("❌ Betz gate FAILS"); else; println("✅ Betz gate passes"); end
