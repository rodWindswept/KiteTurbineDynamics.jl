#!/usr/bin/env julia
using KiteTurbineDynamics, Random, Printf

function run(SAFE_TFOS, SAFE_EFOS, SAFE_RBOT, label)
    p = params_10kw()
    lo, hi = search_bounds_v4(p, PROFILE_CIRCULAR)
    lo[6] = max(lo[6], SAFE_RBOT)
    D = length(lo)
    rng = MersenneTwister(42 + Int(SAFE_TFOS*10))
    POP = 128

    function eval_safe(x)
        d = design_from_vector_v4(x, PROFILE_CIRCULAR, p)
        d.r_bottom < SAFE_RBOT && return Inf
        r = evaluate_design(d; r_rotor=5.0, elev_angle=π/6, v_peak=25.0,
                            fos_req=SAFE_EFOS, v_rated=11.0, P_rated=10000.0)
        (r.feasible && r.min_torsional_fos >= SAFE_TFOS) ? r.mass_total_kg : 1e6 + r.mass_total_kg
    end

    pop = zeros(POP, D)
    for i in 1:POP, d in 1:D
        pop[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
    end
    fitness = [eval_safe(pop[i, :]) for i in 1:POP]
    bi = argmin(fitness)
    best_mass, best_x = fitness[bi], copy(pop[bi, :])
    F, CR = 0.7, 0.9

    for gen in 1:300
        for i in 1:POP
            r1=r2=r3=i
            while r1==i||r2==i||r3==i||r1==r2||r1==r3||r2==r3
                r1=rand(rng,1:POP); r2=rand(rng,1:POP); r3=rand(rng,1:POP)
            end
            v = pop[r1,:] .+ F .* (pop[r2,:] .- pop[r3,:])
            for d in 1:D; v[d]=clamp(v[d],lo[d],hi[d]); end
            u = copy(pop[i,:]); jr = rand(rng,1:D)
            for d in 1:D; (rand(rng)<CR||d==jr) && (u[d]=v[d]); end
            fu = eval_safe(u)
            if fu < fitness[i]; pop[i,:] .= u; fitness[i] = fu; end
        end
        bi = argmin(fitness)
        if fitness[bi] < best_mass; best_mass = fitness[bi]; best_x = copy(pop[bi, :]); end
    end

    db = design_from_vector_v4(best_x, PROFILE_CIRCULAR, p)
    rb = evaluate_design(db; r_rotor=5.0, elev_angle=π/6, v_peak=25.0,
                          fos_req=SAFE_EFOS, v_rated=11.0, P_rated=10000.0)
    feas = rb.feasible && rb.min_torsional_fos >= SAFE_TFOS
    @printf("%s: %5.1f kg  r_b=%.2f  n=%d  EFOS=%.1f  TFOS=%.1f  %s\n",
        label, feas ? rb.mass_total_kg : Inf, db.r_bottom, db.n_lines,
        rb.min_fos, rb.min_torsional_fos, feas ? "✓" : "✗")
end

println("v5-safe sweep — what mass for what safety margin?\n")
run(1.5, 1.8, 0.5, "TFOS≥1.5 EFOS≥1.8 r≥0.5")   # v5-original margins + anti-neck
run(2.0, 2.0, 0.5, "TFOS≥2.0 EFOS≥2.0 r≥0.5")   # moderate
run(2.0, 2.5, 0.5, "TFOS≥2.0 EFOS≥2.5 r≥0.5")   # moderate torsion, strong euler
run(2.5, 2.5, 0.5, "TFOS≥2.5 EFOS≥2.5 r≥0.5")   # strong both
run(2.5, 2.5, 0.7, "TFOS≥2.5 EFOS≥2.5 r≥0.7")   # strong + wider ground
