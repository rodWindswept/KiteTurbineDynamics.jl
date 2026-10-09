# extract_evolution_strip.jl — machine-evolution-strip extract (aero-validator seat).
#
# WHY: the machine-evolution-strip (report figure map, row 9) draws one panel per
# extract entry from ONE prepared extract: island 3's best-so-far design at each
# selected generation.  This script produces THE extract — genomes beside their
# recorded decode, the selection rule recorded — for F-CITE / F-VALUE.
#
# DATASET   v13_5kw_masslift_len18.8_rotorcount_bankderate2 (data commit dd3cc6a;
#           launch a76c5e9; physics era: post-95c385d_wind-authority).
# SOURCE    scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/
#           island_3/telemetry.csv   (310 rows; gens 0..30; idx 1..10)
#           island_3/best_vector.csv (the winner's byte-exact genome)
#
# RULE      best-so-far at a selected generation G = the `ok` row of minimal
#           recorded fitness among rows with gen <= G; ties break to the earliest
#           (gen, idx); non-ok rows are excluded (sentinel fitness 1.0e9).
#           No interpolation, no reconstruction — every panel is a recorded
#           evaluation.
#
# SELECTION proposed by the figures seat (2026-10-09): {0, 5, 10, 15, 20, 25, 26}.
#           The milestone cut repeats machines (M0 = M5 = the seed; M10 = M15),
#           so it is AMENDED here (aero-validator, 2026-10-09) to the improvement
#           generations {0, 6, 10, 18, 22, 25, 26}: seven panels, seven distinct
#           machines.  Revert by editing SELECTED and rerunning; nothing else
#           changes.
#
# PRECISION telemetry records the raw genes rounded to 6 decimal places; that is
#           the only per-row genome record.  The winner's byte-exact vector is
#           read from best_vector.csv (the pair-extract basis) and cross-checked
#           against the telemetry rounding.  Decode columns are carried exactly
#           as logged (display precision).  The recorded decode chain rounds
#           before scoring: x4 -> round(clamp(x4, 3, 16)); x6 -> round(clamp(x6,
#           1, 3)); n_active = min(count, n_rings).
#
# USAGE     scripts/ktd-julia scripts/extract_evolution_strip.jl
# WRITES    docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv
#           docs/reporting/figures/machine-evolution-strip/extract-best-so-far.log

using Dates, Printf

const REPO = dirname(@__DIR__)
const DATA = joinpath(REPO, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
const TELEM = joinpath(DATA, "island_3", "telemetry.csv")
const BESTVEC = joinpath(DATA, "island_3", "best_vector.csv")
const BESTMETA = joinpath(DATA, "island_3", "island_3_best_meta.txt")
const GLOBALMETA = joinpath(DATA, "global_best_meta.txt")
const OUTDIR = joinpath(REPO, "docs", "reporting", "figures", "machine-evolution-strip")

const PROPOSED = [0, 5, 10, 15, 20, 25, 26]
const SELECTED = [0, 6, 10, 18, 22, 25, 26]
const RUNID = "strip-extract-2026-10-09-best-so-far"

git_out(args...) = strip(read(Cmd(String["git", "-C", REPO, args...]), String))
sh_out(args...) = strip(read(Cmd(String[args...]), String))

function read_csv_after_comments(path)
    lines = readlines(path)
    keep = filter(l -> !startswith(l, "#") && !isempty(strip(l)), lines)
    header = split(keep[1], ",")
    rows = [split(l, ",") for l in keep[2:end]]
    return header, rows
end

function main()
    mkpath(OUTDIR)
    csvpath = joinpath(OUTDIR, "extract-best-so-far.csv")
    logpath = joinpath(OUTDIR, "extract-best-so-far.log")
    io = open(logpath, "w")
    say(x...) = (println(io, x...); println(x...); flush(io))

    say("machine-evolution-strip / extract-best-so-far")
    say("generated: ", now())
    say("run-id: ", RUNID)
    say("dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
    say("physics era: post-95c385d_wind-authority")
    say("computing commit: ", git_out("rev-parse", "HEAD"))
    dirt = git_out("status", "--porcelain")
    say("worktree: ", isempty(dirt) ? "clean" :
        "dirty (other seats' files present; this extract reads only committed data + src)")
    say("inputs: telemetry sha256 ", first(split(sh_out("sha256sum", TELEM), " ")),
        " | best_vector sha256 ", first(split(sh_out("sha256sum", BESTVEC), " ")))
    say("")

    # ---- read the island 3 telemetry ----------------------------------------
    header, rows = read_csv_after_comments(TELEM)
    col = Dict(h => i for (i, h) in enumerate(header))
    gen(r) = parse(Int, r[col["gen"]])
    idx(r) = parse(Int, r[col["idx"]])
    fit(r) = parse(Float64, r[col["fitness"]])
    isok(r) = r[col["status"]] == "ok"
    okrows = filter(isok, rows)
    say("rows: ", length(rows), " | ok: ", length(okrows),
        " | gens ", minimum(gen.(rows)), "..", maximum(gen.(rows)))

    # running best-so-far per generation (the series the strip reads)
    running = Dict{Int,Vector{String}}()
    for g in 0:30
        cands = filter(r -> gen(r) <= g, okrows)
        best = sort(cands, by = r -> (fit(r), gen(r), idx(r)))[1]
        running[g] = best
    end

    # ---- selection -----------------------------------------------------------
    say("")
    say("SELECTION")
    say("  proposed (figures seat, 2026-10-09): ", PROPOSED)
    say("  amended  (aero-validator, 2026-10-09): ", SELECTED,
        "  — the milestone cut repeats machines at M0=M5 and M10=M15")
    say("  rule: best-so-far = minimal recorded fitness among ok rows, gen <= G;")
    say("        ties -> earliest (gen, idx); no interpolation, no reconstruction")
    say("")
    say("  proposed milestones, for the record:")
    for G in PROPOSED
        b = sort(filter(r -> gen(r) <= G, okrows), by = r -> (fit(r), gen(r), idx(r)))[1]
        say(@sprintf("    M%-3d -> g%d i%d  fitness=%s", G, gen(b), idx(b), b[col["fitness"]]))
    end

    panels = Vector{Vector{String}}()
    for G in SELECTED
        push!(panels, running[G])
    end

    # winner genome byte-exact from best_vector.csv
    winvec = [strip(t) for t in split(readchomp(BESTVEC), ",")]
    @assert length(winvec) == 10 "best_vector must carry 10 slots"
    winrow = running[maximum(SELECTED)]

    # expected telemetry text for the winner genes (recorded = round to 6 dp)
    pred = [string(round(parse(Float64, v), digits = 6)) for v in winvec]
    exact = count(pred[i] == winrow[col["x$(i)"]] for i in 1:10)
    maxdelta = maximum(abs(parse(Float64, winvec[i]) - parse(Float64, winrow[col["x$(i)"]]))
                       for i in 1:10)

    say("")
    say("PANELS (selected -> source row)")
    say("  panel  selected  label       source   fitness   P_mean  FoS    n_lines rings n_active r_hub")
    for (k, G) in enumerate(SELECTED)
        b = panels[k]
        say(@sprintf("  %-6d %-9d %-11s g%-2d i%-3d %-9s %-7s %-6s %-7s %-5s %-8s %s",
            k, G, "i3-g$(gen(b))-i$(idx(b))", gen(b), idx(b),
            b[col["fitness"]], b[col["P_mean"]], b[col["FoS"]],
            b[col["n_lines"]], b[col["rings"]], b[col["n_active"]], b[col["r_hub"]]))
    end

    # ---- parity certificate --------------------------------------------------
    say("")
    say("PARITY CERTIFICATE")

    # [1] seed identity across islands
    ok1 = true
    seedstrs = String[]
    for isl in 1:3
        h2, r2 = read_csv_after_comments(joinpath(DATA, "island_$isl", "telemetry.csv"))
        c2 = Dict(h => i for (i, h) in enumerate(h2))
        s = sort(filter(r -> r[c2["gen"]] == "0" && r[c2["status"]] == "ok", r2),
                 by = r -> (parse(Float64, r[c2["fitness"]]), parse(Int, r[c2["idx"]])))[1]
        push!(seedstrs, join([s[c2["fitness"]]; [s[c2["x$(i)"]] for i in 1:10]], ","))
    end
    ok1 = all(==(seedstrs[1]), seedstrs)
    say("  [1] seed row identity across islands 1-3 (fitness + raw genes): ",
        ok1 ? "PASS" : "FAIL")

    # [2] final panel = the recorded winner
    bmeta = read(BESTMETA, String)
    gmeta = read(GLOBALMETA, String)
    fitfull = parse(Float64, match(r"fitness=([0-9.]+)", bmeta).captures[1])
    gfitfull = parse(Float64, match(r"fitness=([0-9.]+)", gmeta).captures[1])
    gisland = match(r"island=([0-9]+)", gmeta).captures[1]
    bwin = running[maximum(SELECTED)]
    ok2 = round(fitfull, digits = 3) == fit(bwin) &&
          gfitfull == fitfull && gisland == "3" &&
          gen(bwin) == parse(Int, match(r"found_gen=([0-9]+)", bmeta).captures[1])
    say("  [2] final panel is the recorded winner (g", gen(bwin), " i", idx(bwin), "): ",
        ok2 ? "PASS" : "FAIL", "  (telemetry ", bwin[col["fitness"]], "; meta ",
        fitfull, "; global marker island ", gisland, " ", gfitfull, ")")

    # [3] winner genome: best_vector vs telemetry rounding
    ok3 = maxdelta <= 1e-6
    say("  [3] winner genome: best_vector.csv == telemetry rounding: ",
        ok3 ? "PASS" : "FAIL", "  (exact format matches ", exact, "/10; max |delta| = ",
        @sprintf("%.3e", maxdelta), ")")

    # [4] running series monotone; picks ok and in window
    ok4 = all(fit(running[g]) >= fit(running[g + 1]) for g in 0:29) &&
          all(isok(running[G]) && gen(running[G]) <= G for G in SELECTED)
    say("  [4] running-best monotone non-increasing; every selected row is ok in window: ",
        ok4 ? "PASS" : "FAIL")

    # [5] convergence.csv agreement at the recorded precision (iteration i vs running at gen i)
    hc, rc = read_csv_after_comments(joinpath(DATA, "island_3", "convergence.csv"))
    cc = Dict(h => i for (i, h) in enumerate(hc))
    mism = Tuple{Int,Float64,Float64}[]
    convmax = 0
    for r in rc
        i = parse(Int, r[cc["iteration"]])
        i >= 1 && i <= 30 || continue
        convmax = max(convmax, i)
        if round(parse(Float64, r[cc["fitness"]]), digits = 3) != round(fit(running[i]), digits = 3)
            push!(mism, (i, round(parse(Float64, r[cc["fitness"]]), digits = 3),
                         round(fit(running[i]), digits = 3)))
        end
    end
    ok5 = isempty(mism) && convmax == 30
    say("  [5] convergence.csv matches the row-derived running best at gen i for i=1..",
        convmax, " (3 dp): ", ok5 ? "PASS" : "FAIL  ($(mism))")

    # [6] distinct picks; strictly decreasing fitness
    ids = [(gen(b), idx(b)) for b in panels]
    fits = fit.(panels)
    ok6 = length(unique(ids)) == length(ids) &&
          all(fits[i] > fits[i + 1] for i in 1:length(fits)-1)
    say("  [6] seven distinct panels, strictly decreasing: ", ok6 ? "PASS" : "FAIL",
        "  (", join(ids, " -> "), ")")

    # ---- write the CSV -------------------------------------------------------
    out = IOBuffer()
    println(out, "# machine-evolution-strip / extract-best-so-far.csv")
    println(out, "# run-id: ", RUNID)
    println(out, "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | data commit dd3cc6a | launch a76c5e9")
    println(out, "# provenance: era=post-95c385d_wind-authority  telemetry git=a76c5e927252118abf2b2ff6bd988395583d5113  data commit dd3cc6a")
    println(out, "# physics era: post-95c385d_wind-authority")
    println(out, "# source: island_3/telemetry.csv (310 rows, gens 0..30, idx 1..10); winner genome from island_3/best_vector.csv")
    println(out, "# selection: best-so-far at selected generation G = minimal recorded fitness among ok rows with gen <= G; ties -> earliest (gen, idx); no interpolation")
    println(out, "# selected: proposed ", PROPOSED, "; amended (aero-validator, 2026-10-09) to ", SELECTED, " — see README/log")
    println(out, "# gene slots: x1 r_hub | x2 r_bot | x3 target_Lr | x4 n_lines (clamp 3..16, round) | x5 density_profile | x6 rotor-mask proxy (clamp 1..3, round) | x7 bank_top | x8 bank_bot | x9 blade_scale_top | x10 blade_scale_bottom")
    println(out, "# computing commit: ", git_out("rev-parse", "HEAD"))
    newheader = ["panel", "selected_gen", "label", "genome_source", header...]
    println(out, join(newheader, ","))
    for (k, G) in enumerate(SELECTED)
        b = copy(panels[k])
        gsrc = "telemetry.csv"
        if G == maximum(SELECTED)   # the winner: byte-exact vector from best_vector.csv
            for i in 1:10
                b[col["x$(i)"]] = winvec[i]
            end
            gsrc = "best_vector.csv"
        end
        println(out, join([string(k), string(G), "i3-g$(gen(b))-i$(idx(b))", gsrc, b...], ","))
    end
    write(csvpath, take!(out))
    csvsha = first(split(sh_out("sha256sum", csvpath), " "))

    say("")
    say("OUTPUTS")
    say("  extract-best-so-far.csv — sha256 ", csvsha)
    say("  F-REPRO: the CSV is a pure function of the data commit, SELECTED and this")
    say("  script; a rerun at the same computing commit reproduces it byte-identically")
    say("  (the computing-commit header line tracks the tree, by design).")
    close(io)
end

main()
