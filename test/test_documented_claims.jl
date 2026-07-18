# test/test_documented_claims.jl
#
# Guards the load-bearing numbers quoted in external-facing documents.
# Each assertion cites WHERE the claim was communicated. If one of these
# fails, a documented claim has silently gone stale — update the cited
# docs, don't just fix the test.
#
# Born from the 2026-07-18 doc-staleness audit
# (docs/reports/2026-07-18-doc-staleness-audit.md): three staleness cliffs
# (830950c aero-table swap, ADR-0004 settle fix, 7d43455 builder fix) each
# falsified a class of documented numbers with nothing failing loudly.
# Prose can't fail; this test can.

@testset "documented external claims" begin
    root = dirname(@__DIR__)

    @testset "legacy triangle anchor (Strathclyde disclosure)" begin
        # 167.474 kW @ (blade_scale 0.85, k=2.0) — pre-fix kickstart number
        # shared externally; provenance archived in commit 4170782.
        # If this row changes, the externally quoted number loses its
        # provenance trail.
        f = joinpath(root, "scripts", "results", "control_maps", "legacy",
                     "kickstart_sweep_triangle_legacy.csv")
        @test isfile(f)
        anchor = filter(r -> startswith(r, "0.85,2.0,"), readlines(f))
        @test length(anchor) == 1
        p_kw = parse(Float64, split(anchor[1], ",")[3])
        @test isapprox(p_kw, 167.47438958286824; rtol=1e-9)
    end

    @testset "V10 Tight builder fingerprint (strathclyde_qa_verified.md)" begin
        # Claimed externally: 12-line dodecagon, r_hub 2.889 m, r_bottom 2.0 m,
        # decoded from best_vector.csv in v4 field order (fields 5, 6, 8).
        # Guards the artifact the builder reads post-7d43455.
        f = joinpath(root, "scripts", "results", "v10_campaign_50kw",
                     "best_vector.csv")
        @test isfile(f)
        x = parse.(Float64, split(readline(f), ","))
        @test length(x) >= 14
        # n_lines: the single authoritative clamp is the v4 decoder's [3,12]
        # (design_from_vector_v4, src/ring_spacing.jl:408) — raw 13.21 → 12.
        # (builders_util's duplicate pre-clamp was removed 2026-07-18; see
        # DECISIONS.md "Single-authority clamp".)
        @test clamp(round(Int, x[8]), 3, 12) == 12        # n_lines — the 12-gon
        @test isapprox(x[5], 2.8885; atol=1e-3)           # r_hub (m)
        @test isapprox(x[6], 2.0; atol=1e-3)              # r_bottom (m)
    end

    @testset "V6.2 recovered optimum (awes-forum-v62-report.md)" begin
        # The −71% mass headline (74.17 kg, n_lines=12) — artifact was
        # overwritten at HEAD by a v6.3 smoke test, recovered from 3fcc795
        # (see scripts/results/v6_2_campaign_50kw/RECOVERY_NOTE.md).
        f = joinpath(root, "scripts", "results", "v6_2_campaign_50kw",
                     "best_design_v62_true_optimum_recovered_from_3fcc795.json")
        @test isfile(f)
        txt = read(f, String)
        @test occursin("\"n_lines\"", txt)
        @test occursin("74.17", txt)
    end

    @testset "params_10kw internal consistency (2026-04-19 validation doc)" begin
        p = params_10kw()
        # "one blade per polygon vertex" (parameters.jl) — same invariant as
        # builders Gate 1c (n_blades = n_lines).
        @test p.n_blades == p.n_lines
        # m_blade: 11 kg TOTAL blade mass — the repo invariant (m_blade_total
        # = 11.0 defaults in objective_v5/ring_spacing/trpt_axial_profiles).
        # Corrected from the DRR transcription remnant 11/3 on 2026-07-18
        # (DECISIONS "m_blade = 11/5 ratified"); params_10kw/params_50kw
        # results predating that embed 18.3 kg airborne blade mass. Guard
        # the value so any change forces a deliberate decision.
        @test isapprox(p.m_blade, 11.0 / 5.0; rtol=1e-12)
        @test isapprox(p.n_blades * p.m_blade, 11.0; rtol=1e-12)
    end
end
