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

if nrow(R) == 0
    println("No evals completed.")
else
    improved = 0
    tested   = 0
    for gh in unique(R.genome_hash)
        g = sort(filter(r -> r.genome_hash == gh, R), :relax_s)
        nrow(g) < 2 && continue
        tested += 1
        base = g[1, :ratio]; final = g[end, :ratio]
        tag = (isfinite(final) && final < 0.20) ? "ARTEFACT (now steady)" :
              (isfinite(final) && isfinite(base) && final < 0.5 * base) ? "ARTEFACT (halved)" :
              "PHYSICAL (ratio held)"
        occursin("ARTEFACT", tag) && (improved += 1)
        @printf("  %-14s ratio %7.3f @%.0fs → %7.3f @%.0fs   P %7.3f → %7.3f kW   %s\n",
                gh[1:min(12, end)], base, g[1, :relax_s], final, g[end, :relax_s],
                g[1, :P_mean_kw], g[end, :P_mean_kw], tag)
    end
    println()
    if tested == 0
        println("  Not enough relax settings completed per genome to judge.")
    elseif improved == tested
        println("  → ARTEFACT across the board.  The amplitude failures are undecayed")
        println("    transient, not physical surge.  Raise WARM_RELAX_S to >= DISCARD_S")
        println("    (30 s) and re-run Phase A.  The existing 42 rows cannot support the")
        println("    'power is the binding constraint' conclusion.")
    elseif improved == 0
        println("  → PHYSICAL.  These designs genuinely surge; stationary=false is a real")
        println("    finding for the reachable rows.  The 37 sub-100 W rows remain")
        println("    uninformative regardless — that part of the flag is still an artefact")
        println("    of the P_steady precondition.")
    else
        @printf("  → MIXED: %d of %d genomes settle with more relaxation.\n", improved, tested)
        println("    Per-genome judgement required; do not generalise either way.")
    end
end

@printf("\nWritten: %s (%d rows)\n", OUT_CSV, nrow(R))
