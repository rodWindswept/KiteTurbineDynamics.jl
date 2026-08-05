#!/usr/bin/env julia
# ══════════════════════════════════════════════════════════════════════════════
# scripts/trace_altitude_torque.jl
#
# QUESTION
#   The relax sweep (relax_sensitivity.csv) showed 0 of 5 genomes reach a steady
#   state: all five lose power monotonically as the observation window moves out,
#   four of them to ~1e-4 kW, while FoS climbs up to 23× and 4 of 5 cross the 1.5
#   design gate on window choice alone.  Across all 20 evals
#   r(log P, log FoS) = -0.598 — the structure reads SAFER the less power it makes.
#
#   Rod's hypothesis (2026-08-05): the machines are sinking.
#
#   Wind is WIND_MS * (z/h_ref)^(1/7), so altitude loss cuts wind, and power goes
#   as v³.  Sinking would produce the power decay, the falling loads, the rising
#   FoS and the anti-correlation FROM A SINGLE CAUSE.  Nothing in objective_v11
#   records hub_z, so the campaign could not have seen it.
#
# WHAT THIS DISTINGUISHES
#   A. SINKING          hub_z decays; P tracks (z/z0)^(3/7); FoS rises as load sheds.
#                       → lift sizing is the root cause.  The lift device is a fixed
#                         638 N const, and autogyro_lift_required was design-blind
#                         (hard-coded 12 kg v5 shaft) until this session, so heavy
#                         stiff designs were unsupported and the margin hid it.
#   B. PHYSICAL SPIN-DOWN  hub_z holds; ω decays; τ_aero < τ_gen + losses throughout.
#                       → aero cannot sustain rotation at rated wind.  The sampled
#                         envelope is non-viable; rethink the search space.
#   C. NUMERICAL        hub_z holds, ω holds, but P still falls, or the torque
#                       balance does not close.  → integrator bleeding energy;
#                         every long-horizon result in the project is suspect.
#
#   These are mutually exclusive on the recorded columns.  Read the verdict block.
#
# METHOD
#   Runs the CANONICAL warm-start path — objective_v11_warmstart with the new
#   trace_callback tap — so the trace is provably the same code that produced the
#   campaign numbers.  The tap is scoring-neutral: a traced eval returns identical
#   P/FoS to an untraced one.  No re-implementation of the init sequence, and no
#   settle_to_operational_state (which blows up on 873fe660: NaN hub_z, ω≈1e141).
#
# USAGE
#   rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji \
#         ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
#   julia --project=. scripts/trace_altitude_torque.jl                  # default genomes
#   julia --project=. scripts/trace_altitude_torque.jl 873fe66 6f9db72  # hash prefixes
#
#   Writes one CSV per genome to scripts/results/recampaign/trace_<hash12>.csv
#   plus a combined summary.  Relax is set to 120 s + 30 s window so the full
#   decay is captured; expect ~20-40 min per genome under GC pressure.
# ══════════════════════════════════════════════════════════════════════════════

using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics, LinearAlgebra, Dates

const KTD = KiteTurbineDynamics

# ── Campaign configuration — mirrors run_feasibility_phase_a.jl ───────────────
const SP          = KTD.SpokeParams(enabled=false)
const BEAM        = KTD.PROFILE_ELLIPTICAL
const P_BASE      = KTD.params_v5_50kw()
const POWER_W     = 50000.0
const V_RATED     = 11.0

# ── Lift device ───────────────────────────────────────────────────────────────
# DESIGN-AWARE (Rod, 2026-08-05).  Presume the coaxial autogyro stack delivers
# enough lift at the lift bearing to support the machine smoothly in the air;
# size it to 1.5× this genome's weight and test on that basis.
#
# This replaces the fixed 638 N RotaryLifterParams the Phase A campaign used,
# which gave every design identical lift regardless of mass (≈61 kg of vertical
# support at 70°, against a V6.2 optimum that is 74 kg airborne on its own) and
# so penalised exactly the heavy, stiff designs we want the optimiser to explore.
#
# Passed as a function because sizing needs the built system's airborne mass.
const LIFT_MARGIN = 1.5
lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=LIFT_MARGIN, v_ref=V_RATED)

# Set KTD_LEGACY_LIFT=1 to reproduce the old fixed-force behaviour for comparison.
const LEGACY_LIFT = get(ENV, "KTD_LEGACY_LIFT", "0") == "1"
const LIFT_DEVICE = LEGACY_LIFT ?
    KTD.RotaryLifterParams(1.3, 0.3, 3, 0.15, 1.0, 0.08, 33.0, 25.0, 200_000.0, 4.0) :
    lift_for

# Full-decay horizon: the relax sweep showed collapse completing by ~120 s.
const RELAX_S  = 120.0
const WINDOW_S = 30.0
const SAMPLE_HZ = 2.0        # trace samples per second

const IN_CSV  = joinpath(@__DIR__, "results", "recampaign", "feasibility_phase_a_v2.csv")
const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")

# Default: the headline genome (stalls out) + the one that held the most power.
const DEFAULT_GENOMES = ["873fe660", "6f9db729"]

wanted = isempty(ARGS) ? DEFAULT_GENOMES : ARGS

# ── Load genomes ──────────────────────────────────────────────────────────────
isfile(IN_CSV) || error("campaign CSV not found: $IN_CSV")
camp = CSV.read(IN_CSV, DataFrame)
genome_cols = [Symbol("x$i") for i in 1:15]

targets = DataFrame()
for w in wanted
    hit = filter(r -> startswith(String(r.genome_hash), w), camp)
    nrow(hit) == 0 && (@warn "no genome matching prefix" prefix=w; continue)
    append!(targets, first(hit, 1))
end
nrow(targets) == 0 && error("no matching genomes in $IN_CSV")

@printf("Tracing %d genome(s) over %.0f s at %.0f Hz\n", nrow(targets),
        RELAX_S + WINDOW_S, SAMPLE_HZ)
println(LEGACY_LIFT ?
    "Lift: LEGACY fixed 638 N RotaryLifter (design-blind — comparison run)" :
    @sprintf("Lift: design-aware stack, %.1f× weight at %.0f m/s (presumed sufficient)",
             LIFT_MARGIN, V_RATED))
println()

summary = DataFrame(
    genome_hash=String[], z0_m=Float64[], z_end_m=Float64[], dz_pct=Float64[],
    P0_kw=Float64[], P_end_kw=Float64[], dP_pct=Float64[],
    om0_rpm=Float64[], om_end_rpm=Float64[], dom_pct=Float64[],
    P_pred_from_shear_kw=Float64[], shear_explains=String[],
    tau_net_mean_Nm=Float64[], verdict=String[],
)

for row in eachrow(targets)
    gh = String(row.genome_hash)
    x  = Float64[row[c] for c in genome_cols]
    @printf("═══ %s  (campaign P=%.3f kW, FoS=%.4g) ═══\n",
            gh[1:12], row.P_mean_kw, row.FoS_min)

    KTD.WARM_RELAX_S[]  = RELAX_S
    KTD.WARM_WINDOW_S[] = WINDOW_S

    dt        = KTD.V11_DT
    every     = max(1, round(Int, (1.0 / SAMPLE_HZ) / dt))
    T = DataFrame(
        t=Float64[], hub_z=Float64[], hub_z_delta=Float64[],
        omega_hub=Float64[], omega_gnd=Float64[], P_kw=Float64[],
        V_hub=Float64[], tsr=Float64[],
        tau_aero=Float64[], tau_gen=Float64[], tau_net=Float64[],
        T_max=Float64[], T_lift=Float64[], lift_margin=Float64[],
        FoS_min=Float64[],
    )

    function tap(u, t, s, ctx)
        s % every == 0 || return
        ef = capture_extended(u, ctx.sys, ctx.pc, t, ctx.wf, ctx.lift_device;
                              brake_engaged=ctx.sys.brake_engaged[])
        b = ef.base
        airborne = Float64[]
        for i in 2:length(ef.ring_fos)
            v = ef.ring_fos[i]
            (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
        end
        push!(T, (t, b.hub_z, b.hub_z_delta, b.omega_hub, b.omega_gnd, b.P_kw,
                  b.V_hub, b.tsr, b.tau_aero, b.tau_gen, b.tau_aero - b.tau_gen,
                  b.T_max, b.T_lift, b.lift_margin,
                  isempty(airborne) ? Inf : minimum(airborne)))
    end

    t0 = time()
    res = try
        KTD.objective_v11_warmstart(copy(x), BEAM, P_BASE;
            power_W=POWER_W, v_rated=V_RATED, spoke=SP,
            lift_device=LIFT_DEVICE, trace_callback=tap)
    catch e
        @printf("  EXCEPTION: %s\n\n", sprint(showerror, e))
        continue
    end
    @printf("  %d samples in %.0f s;  objective returned P=%.4g kW FoS=%.4g\n",
            nrow(T), time() - t0, res[2], res[3])

    if nrow(T) < 4
        println("  too few samples to judge\n"); continue
    end

    out = joinpath(OUT_DIR, "trace_$(gh[1:12]).csv")
    CSV.write(out, T)

    # ── Diagnosis ─────────────────────────────────────────────────────────────
    n0 = max(1, nrow(T) ÷ 20)                     # first 5% as the reference
    z0   = mean(T.hub_z[1:n0]);      z1   = mean(T.hub_z[end-n0+1:end])
    P0   = mean(T.P_kw[1:n0]);       P1   = mean(T.P_kw[end-n0+1:end])
    om0  = mean(T.omega_hub[1:n0]);  om1  = mean(T.omega_hub[end-n0+1:end])
    dz   = z0  > 0 ? (z1 - z0) / z0   : NaN
    dP   = P0  > 0 ? (P1 - P0) / P0   : NaN
    dom  = om0 > 0 ? (om1 - om0) / om0 : NaN

    # If sinking alone explains it, P scales as v³ ∝ (z)^(3/7).
    P_pred = (z0 > 0 && z1 > 0) ? P0 * (z1 / z0)^(3 / 7) : NaN
    shear  = !isfinite(P_pred) ? "n/a" :
             (P1 > 0 && 0.5 < P_pred / max(P1, 1e-12) < 2.0) ? "YES (within 2×)" :
             P_pred > P1 ? "NO — P fell further than shear predicts" :
                           "NO — P held above shear prediction"
    tau_net = mean(filter(isfinite, T.tau_net))

    sinking  = isfinite(dz)  && dz  < -0.10
    spinning = isfinite(dom) && dom < -0.10
    dying    = isfinite(dP)  && dP  < -0.20

    verdict = !dying                    ? "NO DECAY (P held)" :
              sinking && occursin("YES", shear) ? "A: SINKING (shear explains P)" :
              sinking && spinning       ? "A+B: SINKING and SPINNING DOWN" :
              sinking                   ? "A: SINKING (P falls faster than shear)" :
              spinning                  ? "B: SPIN-DOWN at altitude" :
                                          "C: NUMERICAL (z and ω hold, P falls)"

    @printf("  hub_z   %8.2f → %8.2f m   (%+6.1f%%)\n", z0, z1, 100dz)
    @printf("  P       %8.4g → %8.4g kW  (%+6.1f%%)\n", P0, P1, 100dP)
    @printf("  omega   %8.3f → %8.3f rad/s (%+6.1f%%)\n", om0, om1, 100dom)
    @printf("  P predicted from shear alone: %.4g kW  → %s\n", P_pred, shear)
    @printf("  mean tau_net (aero - gen): %+.1f Nm  %s\n", tau_net,
            tau_net < 0 ? "(braking — consistent with spin-down)" : "(driving)")
    # lift_margin is T_lift / autogyro_lift_required(p, sys), and the requirement
    # is the 1.0× weight figure — so with a correctly wired sized lifter this
    # should read LIFT_MARGIN.  A different value means the sizing did not take.
    Tl = mean(filter(isfinite, T.T_lift))
    lm = mean(filter(isfinite, T.lift_margin))
    m_implied = Tl * sind(70.0) / (LIFT_MARGIN * 9.81)
    @printf("  T_lift %.0f N   lift_margin %.2f×  %s\n", Tl, lm,
            LEGACY_LIFT ? "(legacy fixed force)" :
            (isapprox(lm, LIFT_MARGIN; rtol=0.05) ? "✓ sizing wired correctly" :
             @sprintf("⚠ expected %.2f× — sizing may not have taken", LIFT_MARGIN)))
    LEGACY_LIFT || @printf("  implied airborne mass: %.1f kg  (vs the 61 kg the old fixed 638 N could hold)\n",
                           m_implied)
    @printf("  → %s\n", verdict)
    @printf("  written: %s\n\n", basename(out))

    push!(summary, (gh, z0, z1, 100dz, P0, P1, 100dP, om0 * 60 / 2π, om1 * 60 / 2π,
                    100dom, P_pred, shear, tau_net, verdict))
end

KTD.WARM_RELAX_S[]  = 10.0
KTD.WARM_WINDOW_S[] = 30.0

if nrow(summary) > 0
    sp = joinpath(OUT_DIR, "trace_altitude_summary.csv")
    CSV.write(sp, summary)
    println("═"^78)
    println("SUMMARY")
    println("═"^78)
    for r in eachrow(summary)
        @printf("  %-14s z %+6.1f%%   P %+7.1f%%   ω %+6.1f%%   %s\n",
                r.genome_hash[1:12], r.dz_pct, r.dP_pct, r.dom_pct, r.verdict)
    end
    println()
    if all(v -> startswith(v, "A"), summary.verdict)
        println("  → SINKING CONFIRMED across all traced genomes.")
        println("    The lift device is a fixed 638 N const outside the genome, and")
        println("    autogyro_lift_required was design-blind until this session, so")
        println("    heavier stiffer designs were unsupported while the reported margin")
        println("    stayed healthy.  Next: size the device to the design (or put it in")
        println("    the genome) and re-run Phase A.  Nothing in the current CSV is")
        println("    quotable — the campaign was ranking descent rates.")
    elseif all(v -> startswith(v, "C"), summary.verdict)
        println("  → NUMERICAL.  Altitude and ω hold while power decays.  This is an")
        println("    integrator problem, not a design problem, and it invalidates every")
        println("    long-horizon result in the project — not just this campaign.")
    else
        println("  → MIXED / see per-genome verdicts above.  Do not generalise.")
    end
    @printf("\n  summary: %s\n", sp)
end
