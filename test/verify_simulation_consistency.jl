using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, LinearAlgebra

p       = params_10kw()
sys, u0 = build_kite_turbine_system(p)
u_start = settle_to_operational_state(sys, u0, p, 9.5)

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

const N_STEPS_TOTAL = 25000
const DT            = 4e-5
const LIN_DAMP      = 0.05
N  = sys.n_total
Nr = sys.n_ring

# ── DASHBOARD METHOD (Direct Copy-Paste) ──────────────────────────────────────
u_dash = copy(u_start)
du_dash = zeros(Float64, length(u_dash))

let t = 0.0
    for step in 1:N_STEPS_TOTAL
        fill!(du_dash, 0.0)
        multibody_ode!(du_dash, u_dash, (sys, p, wind_fn), t)
        t += DT

        @views u_dash[3N+1:6N]        .+= DT .* du_dash[3N+1:6N]
        @views u_dash[1:3N]            .+= DT .* u_dash[3N+1:6N]
        @views u_dash[6N+Nr+1:6N+2Nr] .+= DT .* du_dash[6N+Nr+1:6N+2Nr]
        @views u_dash[6N+1:6N+Nr]     .+= DT .* u_dash[6N+Nr+1:6N+2Nr]

        orbital_damp_rope_velocities!(u_dash, sys, p, LIN_DAMP)

        u_dash[1:3]       .= 0.0
        u_dash[3N+1:3N+3] .= 0.0
    end
end

# ── LIBRARY METHOD (run_canonical_sim!) ───────────────────────────────────────
u_lib = copy(u_start)
run_canonical_sim!(u_lib, sys, p, wind_fn, N_STEPS_TOTAL, DT; lin_damp=LIN_DAMP)

# ── COMPARISON ────────────────────────────────────────────────────────────────
diff = maximum(abs.(u_dash .- u_lib))
@printf "Maximum absolute difference after 25,000 steps: %.20f\n" diff

if diff == 0.0
    println("✅ SUCCESS: The integration loops are perfectly shadowed and mathematically identical.")
else
    println("❌ FAILURE: Discrepancy detected!")
    exit(1)
end
