#!/usr/bin/env julia
# ══════════════════════════════════════════════════════════════════════════════
# scripts/diagnose_relax_sensitivity.jl
#
# QUESTION
#   Phase A v2 recorded stationary=false on 42/42 rows.  For 37 of those rows the
#   gate could not have fired at all (see below), so the flag is uninformative.
#   For the 5 rows where P_mean > 0.1 kW the gate WAS reachable and failed — every
#   one of them on the amplitude test, with P_range/P_mean between 0.72 and 14.85
#   against a 0.20 threshold.
#
#   Is that amplitude failure PHYSICAL (the machine really does surge) or is it an
#   ARTEFACT of measuring during an undecayed start-up transient?
#
# WHY IT IS PLAUSIBLY AN ARTEFACT
#   The warm-start path allows WARM_RELAX_S = 10 s of relaxation before it starts
#   sampling.  The cold path (objective_v11) discards DISCARD_S = 30 s.  A design
#   that needs more than 10 s to settle is therefore still decaying across the
#   entire 30 s warm-start measurement window.  The window's own comment says the
#   signal is "in departure" — it was tuned to detect leaving a state, and a
#   stationarity gate then demands the opposite of that same window.
#
# METHOD
#   Re-score each reachable genome at WARM_RELAX_S ∈ {10, 30, 60, 120} s with the
#   window held at 30 s.  Everything else — objective, integrator, lift device,
#   k bracket — is the canonical campaign path, untouched.
#
# READING THE RESULT
#   ratio collapses below 0.20 as relax grows  → ARTEFACT.  The campaign's
#       amplitude failures are transient contamination; raise WARM_RELAX_S to at
#       least DISCARD_S and re-run Phase A before drawing any physics conclusion.
#   ratio stays high and flat                  → PHYSICAL.  These designs genuinely
#       surge; stationary=false is a true finding for the 5 reachable rows.
#   P_mean itself moves a lot with relax       → the reported kW figures are
#       window-dependent and none of the 42 power numbers can be quoted.
#
# USAGE
#   rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji \
#         ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
#   julia --project=. scripts/diagnose_relax_sensitivity.jl
#
#   Runtime: 4 relax settings × ~5 genomes × 3 k-bracket evals.  Warm-start evals
#   cost 10–20 min each under GC pressure, so budget generously and expect the
#   120 s setting to dominate.  Progressive CSV saves after every single eval —
#   killing the job never loses completed work, and re-running skips what is done.
# ══════════════════════════════════════════════════════════════════════════════

using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics, Dates

const KTD = KiteTurbineDynamics

# ── Campaign configuration — must mirror run_feasibility_phase_a.jl ───────────
const SP          = KTD.SpokeParams(enabled=false)
const BEAM        = KTD.PROFILE_ELLIPTICAL
const P_BASE      = KTD.params_v5_50kw()
const LIFT_DEVICE = KTD.RotaryLifterParams(
    1.3, 0.3, 3, 0.15, 1.0, 0.08, 33.0, 25.0, 200_000.0, 4.0)
const POWER_W     = 50000.0
const V_RATED     = 11.0

const RELAX_SWEEP = [10.0, 30.0, 60.0, 120.0]   # 10.0 = campaign default
const WINDOW_S    = 30.0                        # held fixed across the sweep

const IN_CSV  = joinpath(@__DIR__, "results", "recampaign", "feasibility_phase_a_v2.csv")
const OUT_CSV = joinpath(@__DIR__, "results", "recampaign", "relax_sensitivity.csv")

# Only genomes that cleared the P_steady precondition are worth testing: below
# 0.1 kW the gate returns false unconditionally and tells us nothing.
const P_REACHABLE = 0.1

# ── Load the reachable genomes ────────────────────────────────────────────────
isfile(IN_CSV) || error("campaign CSV not found: $IN_CSV")
camp = CSV.read(IN_CSV, DataFrame)

reachable = filter(r -> isfinite(r.P_mean_kw) && r.P_mean_kw > P_REACHABLE, camp)
isempty(reachable) && error("no rows with P_mean_kw > $P_REACHABLE — nothing to test")

@printf("Loaded %d campaign rows; %d reachable (P_mean > %.2f kW)\n",
        nrow(camp), nrow(reachable), P_REACHABLE)
println("These are the only rows where the stationarity gate could fire.\n")

genome_cols = [Symbol("x$i") for i in 1:15]

# ── Resume support ────────────────────────────────────────────────────────────
done = Set{Tuple{String,Float64}}()
R = DataFrame(
    genome_hash=String[], relax_s=Float64[], window_s=Float64[],
    P_mean_kw=Float64[], P_range_kw=Float64[], ratio=Float64[],
    FoS_min=Float64[], omega_eq_rpm=Float64[], k_chosen=Float64[],
    stationary=Bool[], drift_flag=Bool[],
    P_mean_campaign=Float64[], ratio_campaign=Float64[],
    verdict=String[], timestamp=String[],
)
if isfile(OUT_CSV)
    R = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(R)
        push!(done, (String(r.genome_hash), Float64(r.relax_s)))
    end
    @printf("Resuming: %d evals already recorded in %s\n\n", nrow(R), basename(OUT_CSV))
end

# ── Sweep ─────────────────────────────────────────────────────────────────────
for row in eachrow(reachable)
    gh        = String(row.genome_hash)
    x         = Float64[row[c] for c in genome_cols]
    P_camp    = Float64(row.P_mean_kw)
    ratio_camp = P_camp > 0 ? Float64(row.P_range_kw) / P_camp : NaN

    @printf("═══ genome %s  (campaign: P=%.3f kW, P_range/P_mean=%.3f) ═══\n",
            gh[1:min(12, end)], P_camp, ratio_camp)

    for relax in RELAX_SWEEP
        if (gh, relax) in done
            @printf("  relax=%6.1f s  [already done, skipping]\n", relax)
            continue
        end

        KTD.WARM_RELAX_S[]  = relax
        KTD.WARM_WINDOW_S[] = WINDOW_S

        t0 = time()
        local res
        try
            res = KTD.warmstart_with_k_bracket(copy(x), BEAM, P_BASE;
                power_W=POWER_W, v_rated=V_RATED, spoke=SP, lift_device=LIFT_DEVICE)
        catch e
            @printf("  relax=%6.1f s  EXCEPTION: %s\n", relax, sprint(showerror, e))
            continue
        end
        _f, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, _ua, _ub = res
        el = time() - t0

        ratio = P_mean > 0 ? P_range / P_mean : NaN
        verdict = !isfinite(ratio)          ? "no-power"  :
                  ratio < 0.20              ? "STEADY"    :
                  ratio < 0.5 * ratio_camp  ? "improving" : "still-surging"

        @printf("  relax=%6.1f s  P=%8.3f kW  P_range=%8.3f  ratio=%7.3f  FoS=%8.4g  stat=%-5s  %-13s (%.0f s)\n",
                relax, P_mean, P_range, ratio, FoS_min, stationary, verdict, el)

        push!(R, (gh, relax, WINDOW_S, P_mean, P_range, ratio, FoS_min, ω_eq,
                  k_chosen, stationary, drifted, P_camp, ratio_camp, verdict,
                  string(now())))
        CSV.write(OUT_CSV, R)   # progressive save — every eval, per repo guideline 5
    end
    println()
end

# ── Restore campaign defaults ─────────────────────────────────────────────────
KTD.WARM_RELAX_S[]  = 10.0
KTD.WARM_WINDOW_S[] = 30.0

# ── Verdict ───────────────────────────────────────────────────────────────────
println("═"^78)
println("VERDICT")
println("═"^78)

# CLASSIFIER v2 (2026-08-05).
#
# v1 classified on `ratio = P_range/P_mean` alone and called a genome ARTEFACT
# when the ratio dropped below 0.20.  That was wrong, and wrong in exactly the
# way this script was written to expose: a ratio whose denominator can collapse
# is not a steadiness measure.  Two genomes were labelled "ARTEFACT (now steady)"
# when what actually happened is that P_mean fell four orders of magnitude — the
# numerator collapsed faster than the denominator.  A dead machine reads as
# perfectly steady.  Same defect class as `P_steady` in objective_v11.jl:503.
#
# v2 requires a genome to still be PRODUCING before its steadiness is assessed,
# and reports the power trend as a first-class result rather than a footnote.
const P_ALIVE = 0.1   # kW — below this the design is not producing; ratio is meaningless

if nrow(R) == 0
    println("No evals completed.")
else
    counts = Dict("SETTLES" => 0, "STALLS OUT" => 0, "SURGES" => 0, "DECAYING" => 0)
    tested = 0
    for gh in unique(R.genome_hash)
        g = sort(filter(r -> r.genome_hash == gh, R), :relax_s)
        nrow(g) < 2 && continue
        tested += 1
        P0, P1     = g[1, :P_mean_kw], g[end, :P_mean_kw]
        r0, r1     = g[1, :ratio], g[end, :ratio]
        F0, F1     = g[1, :FoS_min], g[end, :FoS_min]
        dP         = P0 > 0 ? (P1 - P0) / P0 : NaN
        alive      = isfinite(P1) && P1 >= P_ALIVE
        steady     = isfinite(r1) && r1 < 0.20

        tag = !alive              ? "STALLS OUT" :   # died — ratio says nothing
              steady              ? "SETTLES"    :   # alive AND steady: the only good outcome
              dP < -0.20          ? "DECAYING"   :   # still producing but bleeding down
                                    "SURGES"          # holding power, genuinely oscillating
        counts[tag] += 1

        kswitch = length(unique(g.k_chosen)) > 1 ? " k-SWITCHED" : ""
        fswing  = (isfinite(F0) && isfinite(F1) && min(F0, F1) > 0) ?
                  @sprintf(" FoS %.3g→%.3g (%.1f×)", F0, F1, max(F0,F1)/min(F0,F1)) : ""
        @printf("  %-14s P %9.4g → %9.4g kW (%+6.1f%%)  ratio %7.3f → %7.3f  %-11s%s%s\n",
                gh[1:min(12, end)], P0, P1, 100*dP, r0, r1, tag, fswing, kswitch)
    end

    println()
    if tested == 0
        println("  Not enough relax settings completed per genome to judge.")
    else
        @printf("  SETTLES %d   SURGES %d   DECAYING %d   STALLS OUT %d   (of %d)\n\n",
                counts["SETTLES"], counts["SURGES"], counts["DECAYING"],
                counts["STALLS OUT"], tested)
        if counts["SETTLES"] == 0
            println("  → NO STEADY STATE FOUND AT ANY RELAX TIME.")
            println("    This is not a 'tune WARM_RELAX_S' result.  If no genome reaches a")
            println("    productive plateau, there is no correct window to pick — the 10 s")
            println("    campaign figure is just the highest point on a decay curve, and")
            println("    every P and FoS in feasibility_phase_a_v2.csv is a readout of how")
            println("    far a design had got through dying when sampling happened to stop.")
            println()
            println("    Next question is whether the decay is PHYSICAL (aero torque cannot")
            println("    sustain rotation against generator + losses) or NUMERICAL (the")
            println("    integrator is bleeding energy).  Resolve with an omega/torque trace")
            println("    over the full 120 s on the warm-start path — not settle_to_operational_state,")
            println("    which blows up.  Watch omega(t), tau_aero(t), tau_gen(t).")
        elseif counts["SETTLES"] == tested
            println("  → ALL SETTLE.  Raise WARM_RELAX_S to the settling time and re-run")
            println("    Phase A; the existing 42 rows were measured mid-transient.")
        else
            println("  → MIXED.  Judge per genome; do not generalise.  Only the SETTLES rows")
            println("    have quotable P and FoS figures.")
        end
    end
end

@printf("\nWritten: %s (%d rows)\n", OUT_CSV, nrow(R))
