using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
kw=5.0; pw=5000.0; p=mass_scale(params_10kw(),10.0,kw)
for lam in [0.5,0.7,1.0,1.3,1.5,2.0]
 x=seed_genome(kw)
 x[7]=0.7; x[13]=lam; x[14]=lam  # increase both λ
 x[8]=Float64(round(Int,clamp(x[8],3,16)))
 x[10]=clamp(x[10],0.0,Float64(N_VALID_MASKS))
 dec=design_from_vector_v10(x,PROFILE_ELLIPTICAL,p;power_W=pw)
 r=evaluate_design_v5(dec.design;power_W=pw)
 if r.feasible; ok="OK"; else; ok="XX"; end
 @printf("λ=%.1f tors=%.2f FoS=%.1f mass=%.1f %s\n",
   lam,r.min_torsional_fos,r.min_fos,r.mass_total_kg,ok)
end
