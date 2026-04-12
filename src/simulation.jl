export run_canonical_sim!

"""
    run_canonical_sim!(u, sys, p, wind_fn, n_steps, dt; lift_device, lin_damp, callback)

The canonical explicit Euler integration loop, extracted directly from the interactive dashboard.
Provides a unified, headless simulation engine for all batch sweeps and reports.
"""
function run_canonical_sim!(u::Vector{Float64}, sys::KiteTurbineSystem, p::SystemParams, wind_fn::Function, n_steps::Int, dt::Float64;
                            lift_device::Union{Nothing, LiftDevice} = nothing,
                            lin_damp::Float64 = 0.05,
                            callback::Union{Nothing, Function} = nothing)
    N  = sys.n_total
    Nr = sys.n_ring
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = lift_device === nothing ? (sys, p, wind_fn) : (sys, p, wind_fn, lift_device)

    for step in 1:n_steps
        fill!(du, 0.0)
        multibody_ode!(du, u, ode_params, t)
        t += dt

        @views u[3N+1:6N]        .+= dt .* du[3N+1:6N]
        @views u[1:3N]            .+= dt .* u[3N+1:6N]
        @views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
        @views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]

        if lin_damp > 0.0
            orbital_damp_rope_velocities!(u, sys, p, lin_damp)
        end

        u[1:3]       .= 0.0   # ground ring centre stays at origin
        u[3N+1:3N+3] .= 0.0   # ground ring translational velocity = 0

        if callback !== nothing
            callback(u, t, step)
        end
    end
    return u
end
