#!/usr/bin/env julia
# postprocess_gate2_spokes.jl — adds spoke/drag/stability from ODE timeseries
# Physical model: T_spoke = m_vertex*ω²*r - F_in (from P_aero)
# Usage: julia --project=. scripts/postprocess_gate2_spokes.jl

using CSV, DataFrames, Printf, Statistics
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics; import KiteTurbineDynamics: RingNode, SpokeParams

const OUT_DIR = joinpath(@__DIR__, "results", "control_maps")
const spoke  = SpokeParams(; enabled=true)

# Name → builder function (maps summary CSV prefix to builder)
const BLD = Dict(
    "gate2_reinforced"             => ControlMapHunt.v10_tight_builder(r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0),
    "gate1_blade_scaled_069_maxpower" => ControlMapHunt.v10_tight_builder(blade_scale=0.69),
)

for (bname, bfn) in BLD
    for sfx in ["", "_tmp"]
        tsf = joinpath(OUT_DIR, bname * sfx * "_timeseries.csv")
        ssf = joinpath(OUT_DIR, bname * sfx * "_summary.csv")
        isfile(tsf) && isfile(ssf) || continue
        nm = bname * sfx
        println("\n=== $nm ===")

        sys, u0, p, _ = Base.invokelatest(bfn)
        nr = sys.n_ring; nl = p.n_lines

        # Ring radii from system
        rr = zeros(nr)
        for i in 1:nr
            nid = sys.ring_ids[i]; nid === nothing && continue
            rr[i] = (sys.nodes[nid]::RingNode).radius
        end

        # Expansion rotor data
        erings = Int[]; emass = zeros(nr)
        for er in sys.expansion_rotors
            push!(erings, er.ring_idx)
            emass[er.ring_idx] = er.mass
        end

        # Per-vertex structural mass (beam + knuckle + blade share)
        mb = isdefined(p, :m_ring) ? p.m_ring : 0.0
        mv = fill(mb * 1.1, nr)  # beam + 10% knuckle
        for ri in erings
            mv[ri] += emass[ri] / nl  # blade mass per vertex
        end

        ts  = CSV.read(tsf, DataFrame; comment="#")
        sum = CSV.read(ssf, DataFrame; comment="#")

        sum.n_spokes       = zeros(Int, nrow(sum))
        sum.max_T_spoke_N  = zeros(nrow(sum))
        sum.min_fos_spoke  = fill(Inf, nrow(sum))
        sum.spoke_drag_kW  = zeros(nrow(sum))
        sum.P_windowed     = zeros(nrow(sum))
        sum.stability      = fill("ok", nrow(sum))

        ti = 1  # timeseries row pointer
        for i in 1:nrow(sum)
            wrpm = sum[i, Symbol("ω_rpm")]
            w = wrpm * 2π / 60
            te = min(ti + 59, nrow(ts))
            ws = ts[ti:te, :]
            ti = te + 1

            dkW = 0.0; mxT = 0.0; nE = 0
            for ri in erings
                R = rr[ri]
                Fcf = mv[ri] * w^2 * R
                # Estimate inward aero force from power balance
                Pa = nrow(ws) > 0 ? ws[end, :P_aero_kw] * 1000.0 : 0.0
                ne = length(erings)
                Fi = ne > 0 ? Pa / (w * rr[ri] * nl * ne) : 0.0
                Fnet = Fcf - Fi
                if Fnet > 0
                    nE += 1
                    if Fnet > mxT; mxT = Fnet; end
                end
                # Spoke drag
                tau = 0.5 * p.rho * spoke.C_D * spoke.d_line * w^2 * R^4 / 4.0
                dkW += nl * tau * w / 1000.0
            end
            fs = mxT > 0 ? spoke.SWL_N / mxT : Inf

            # Windowed-mean P + stability from final 20s
            if nrow(ws) >= 20
                la = ws[end-19:end, :]
                pv = la.P_kw
                pw = mean(pv)
                nrp = (maximum(pv) - minimum(pv)) / max(abs(mean(pv)), 0.1)
                st = nrp > 0.15 ? "unstable" : nrp > 0.05 ? "marginal" : "ok"
            else
                pw = sum[i, :P_kw]; st = "ok"
            end

            sum[i, :n_spokes]      = nE
            sum[i, :max_T_spoke_N] = mxT
            sum[i, :min_fos_spoke] = fs
            sum[i, :spoke_drag_kW] = dkW
            sum[i, :P_windowed]    = pw
            sum[i, :stability]     = st

            @printf("  v=%.0f ω=%.0f eng=%d T=%.0fN FoS=%.1f dkW=%.1f %s\n",
                sum[i,:v_wind], wrpm, nE, mxT, fs, dkW, st)
        end

        out = joinpath(OUT_DIR, nm * "_spokes.csv")
        open(out, "w") do io
            write(io, "# postprocess_spokes · builder:$nm · spokes:$(spoke.d_line*1000)mm_SWL$(spoke.SWL_N/1000)kN\n")
            CSV.write(io, sum)
        end
        println("  → $out")
    end
end
println("\n=== Done ===")
