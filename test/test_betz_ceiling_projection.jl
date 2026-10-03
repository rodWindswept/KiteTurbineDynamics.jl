#!/usr/bin/env julia --project=.
#= test_betz_ceiling_projection.jl — RED-first contract for the wind-normal (ZY)
# Betz basis.  Rod 2026-10-02; ruling @aero-worker (2026-10-02), code verified
# against the working tree by @aero-validator.
#
# THE PHYSICS (settled — do not re-open in the test)
#   Mass flux is rho*v*A with A the swept area projected onto the WIND-NORMAL
#   plane.  TWO independent projections act on the main rotor:
#     cos(elevation) — the shaft is 30 deg above horizontal wind, so the rotor
#                      plane sits 30 deg off the wind-normal plane.  This is
#                      p.elevation_angle, NOT the bank angle.
#     cos(bank)      — coning shrinks the blade OFFSETS from the ring, not the
#                      ring radius, so the swept surface is a frustum whose
#                      shaft-normal shadow is the projected annulus.
#   AGENTS.md's "banking is not elevation, not a shaft tilt" is the warning the
#   2026-10-02 thread tripped over.
#   The disc-branch POWER already carries both, each as cos^2.65 (a measured
#   total = cos^1 geometric x cos^1.65 skewed-wake/aero) — ring_forces.jl:222-223
#   — so the projection is applied ONCE in the ceiling and must NOT also be
#   multiplied into the power formula.  Stacking to cos^3.65 over-derates.
#
# THE CONTRACT (the two names the implementation must provide)
#   main_rotor_bank_projected_area(sys) -> Float64
#       Shaft-normal projected annulus of the main rotor, offset form: un-fold
#       RotorSpec (radius, blade_hub_radius) back to (r_ring, span) and return
#       BEM.annulus_area(r_ring, span; bank_deg=sys.rotor.bank_angle_deg).
#       The un-fold is the algebraic inverse of the hardcoded 70/30 fold
#       (objective_v10.jl:369-371), NOT a re-derivation of structure:
#           span  = radius - blade_hub_radius
#           r_ring = 0.3*radius + 0.7*blade_hub_radius
#   betz_wind_normal_area(sys, p) -> Float64
#       (main_rotor_bank_projected_area(sys)
#        + sum of expansion_annulus_area(er, r_ring)) * cos(p.elevation_angle)
#       — the aggregate area BOTH ceilings charge.
#
# THE TWO SITES (one ruling, two edits)
#   objective_evaluator.jl:1032-1039  the aggregate Betz ceiling and the Betz_cp
#                                     floor (the P_available gate)
#   objective_evaluator.jl:869-871    the per-rotor Betz gate, which INLINES the
#                                     raw literal instead of calling the helper —
#                                     invisible to `grep main_rotor_swept_area`
#
# THE GUARD (green before and after — this half is not the RED step)
#   main_rotor_swept_area stays RAW and bank-agnostic.  Four call sites depend on
#   it: ring_forces.jl:205 (hub thrust, cos(elev)^2.0, deliberately NO bank
#   derate), ring_forces.jl:220 (the disc-branch POWER, already projected inside
#   its exponents), ring_forces.jl:285 (expansion T_est), initialization.jl:1323
#   (the bridle-preload cut — the settle <-> ODE coupling that
#   test_settle_drag_alignment pins).  An in-helper projection would push a third
#   cos through the power formula and desync the settle scan.
#
# OUT OF SCOPE (own card, per the ruling): objective_evaluator_ramp.jl:237-241
#   still runs the retired `pi*p.rotor_radius^2 + sum(pi*tip^2*cos(bank))` model.
#   v12-only, off the v13 gate path.
#
# Static (no ODE window) -> belongs in test/runtests.jl.
=#

module BetzCeilingProjectionTests

using Test, Printf
using KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))   # decode_winner, CLI-guarded

const KW = 5.0
const L18 = 18.8

# The two machines the thread's numbers came from: the CURRENT winner (bank
# 10.74 deg) and the pre-derate winner (bank 19.95 deg — the "20 deg" at which
# AGENTS.md quotes the 15-per-cent disc-model optimism).
const WINNERS = [
    "bank-derate winner, bank 10.7399 deg" =>
        joinpath(ROOT, "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"),
    "pre-derate winner, bank 19.9469 deg" =>
        joinpath(ROOT, "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"),
]

read_genome(path) = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]

# The raw axis annulus, written out HERE so the guard does not depend on the
# function it is guarding.
raw_annulus(sys) = π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2)

# A missing contract name must not abort the file: the RED step has to name every
# missing piece, not just the first.
const MISSING = String[]
function contract(f, name::String)
    try
        return f()
    catch e
        push!(MISSING, "$name — " * sprint(showerror, e))
        return nothing
    end
end

const CASES = Dict{String,Any}()
for (label, csv) in WINNERS
    @testset "$label" begin
        @test isfile(csv)   # a missing winner CSV must fail loudly, not skip
        x = read_genome(csv)
        d = decode_winner(x; L=L18, KW=KW)
        sys, _u0, _pc = KiteTurbineDynamics.build_system_from_v10(
            d.dec, 1.0, d.k_mp; tether_diameter=d.p.tether_diameter, base_params=d.p,
        )
        CASES[label] = (sys=sys, p=d.p, dec=d.dec)
    end
end

@testset "Betz ceiling projection — wind-normal (ZY) basis, Rod 2026-10-02" begin

@testset "1. un-fold: RotorSpec inverts to (r_ring, span) against the decoder's own r_hub" begin
    for (label, csv) in WINNERS
        sys = CASES[label].sys
        dec = CASES[label].dec
        r = sys.rotor
        span = r.radius - r.blade_hub_radius
        r_ring = 0.3 * r.radius + 0.7 * r.blade_hub_radius

        # Ground truth is the DECODER's r_hub, not a re-derivation: the un-fold
        # must land on the geometry the builder actually ring-anchored.
        @test isapprox(r_ring, dec.design.r_hub; rtol=0, atol=1e-9)
        @test isapprox(r_ring + 0.7 * span, r.radius; rtol=0, atol=1e-12)
        @test isapprox(r_ring - 0.3 * span, r.blade_hub_radius; rtol=0, atol=1e-12)
        @test span > 0.0
        @test 0.0 < r.bank_angle_deg <= 25.0   # a banked machine, inside the clamp
    end
end

@testset "2. contract: bank-projected area is the offset form, and it bites" begin
    for (label, csv) in WINNERS
        sys = CASES[label].sys
        r = sys.rotor
        span = r.radius - r.blade_hub_radius
        r_ring = 0.3 * r.radius + 0.7 * r.blade_hub_radius
        cb = cosd(r.bank_angle_deg)

        # Route A: the test's own offset-form projection, written from the physics.
        r_out = r_ring + 0.7 * span * cb
        r_in = max(r_ring - 0.3 * span * cb, 0.0)
        @test r_out > r_in > 0.0

        # Route B: the codebase's existing projected annulus (independent code).
        @test isapprox(
            KiteTurbineDynamics.BEM.annulus_area(r_ring, span; bank_deg=r.bank_angle_deg),
            π * (r_out^2 - r_in^2);
            rtol=1e-12,
        )

        # Route C: the contract function.
        A_bank = contract(
            () -> KiteTurbineDynamics.main_rotor_bank_projected_area(sys),
            "main_rotor_bank_projected_area($label)",
        )
        A_bank === nothing && continue

        @test isapprox(A_bank, π * (r_out^2 - r_in^2); rtol=1e-12)
        # The bank must actually reduce the area — a function that ignores bank
        # (or returns the raw annulus) is the bug this pins.
        @test A_bank < raw_annulus(sys)
        # ...but only by the bank term, not by elevation (that is site level).
        @test !isapprox(A_bank, raw_annulus(sys); rtol=1e-9)
        # The first-order `A*cos(bank)` is NOT the convention: it also shrinks
        # r_ring, which the offset form correctly holds fixed.  The offset form
        # is therefore a shade MORE conservative (measured 0.115 % at 10.74 deg,
        # 0.354 % at 19.95 deg).
        @test A_bank < raw_annulus(sys) * cb
    end
end

@testset "3. contract: the aggregate area is wind-normal (cos elevation once)" begin
    for (label, csv) in WINNERS
        sys = CASES[label].sys
        p = CASES[label].p
        @test length(sys.expansion_rotors) == 0   # both winners are single-rotor
        A_bank = contract(
            () -> KiteTurbineDynamics.main_rotor_bank_projected_area(sys),
            "main_rotor_bank_projected_area($label)",
        )
        A_zn = contract(
            () -> KiteTurbineDynamics.betz_wind_normal_area(sys, p),
            "betz_wind_normal_area($label)",
        )
        (A_bank === nothing || A_zn === nothing) && continue

        ce = cos(p.elevation_angle)
        @test isapprox(A_zn, A_bank * ce; rtol=1e-12)
        # Elevation is a SEPARATE projection from bank (30 deg shaft tilt vs blade
        # coning) — the area must carry both, and the same machine's published
        # A_ZY (raw * cos elev, no bank) must sit strictly above it.
        @test A_zn < raw_annulus(sys) * ce
        # Never summed into one exponent: the ceiling applies cos^1 per
        # projection, the power keeps cos^2.65 (tests 2/5 pin the split).
        @test !isapprox(A_zn, A_bank * ce * ce; rtol=1e-9)
    end
end

@testset "4. reconciliation: the code agrees with the published score breakdown" begin
    # island 3 winner — report/island_3_score_breakdown.txt (Hermes, 2026-10-02):
    #   r_out 4.7786 / r_in 3.4301, A_axial 34.7767, A_ZY 30.1175
    # and the campaign winner CSV at the head of the thread.
    label = "bank-derate winner, bank 10.7399 deg"
    sys = CASES[label].sys
    p = CASES[label].p
    @test isapprox(sys.rotor.radius, 4.7786452387; rtol=1e-9)
    @test isapprox(sys.rotor.blade_hub_radius, 3.4301130937; rtol=1e-9)
    @test isapprox(sys.rotor.bank_angle_deg, 10.7399092234; rtol=1e-9)
    @test isapprox(raw_annulus(sys), 34.7767221889; rtol=1e-9)
    @test isapprox(p.elevation_angle, π / 6; rtol=1e-12)
    # The published A_ZY = 34.7767 * cos(30 deg) = 30.1175 — reproduced exactly,
    # which is what makes it the right CROSS-CHECK and the wrong CEILING: it
    # omits cos(bank).
    @test isapprox(raw_annulus(sys) * cos(p.elevation_angle), 30.117525; rtol=2e-6)
    A_zn = contract(
        () -> KiteTurbineDynamics.betz_wind_normal_area(sys, p),
        "betz_wind_normal_area($label)",
    )
    if A_zn !== nothing
        @test isapprox(A_zn, 29.555903; rtol=2e-6)   # the correct ceiling basis
        @test A_zn < 30.117525
        # What the two gates charge, at the campaign's rated wind.  The 1.1x
        # tripwire drops 18.4935 -> 15.7172 kW; nothing re-baselines, because the
        # 5.11 kW operating point sits at 32.5 % of the FIXED tripwire.
        @test isapprox(0.593 * 0.5 * p.rho * raw_annulus(sys) * 11.0^3 / 1000.0, 16.8123; rtol=2e-6)
        @test isapprox(0.593 * 0.5 * p.rho * A_zn * 11.0^3 / 1000.0, 14.2884; rtol=2e-6)
    else
        @test false   # the contract name must exist: no silent skip
    end
end

@testset "5. GUARD: main_rotor_swept_area stays raw and bank-agnostic" begin
    for (label, csv) in WINNERS
        sys = CASES[label].sys
        # Bit-identical to the expression written independently in this file.  If
        # anyone projects inside the shared helper, this fires for BOTH machines
        # (banks 10.74 deg and 19.95 deg) — whichever of the four call sites they
        # were trying to serve.
        @test KiteTurbineDynamics.main_rotor_swept_area(sys) == raw_annulus(sys)
        # The projection lives in the NEW function, not in the old one.
        A_bank = contract(
            () -> KiteTurbineDynamics.main_rotor_bank_projected_area(sys),
            "main_rotor_bank_projected_area($label)",
        )
        A_bank === nothing && continue
        @test KiteTurbineDynamics.main_rotor_swept_area(sys) > A_bank
    end
end

@testset "6. source guard: both gate sites route through the contract" begin
    src = read(joinpath(ROOT, "src", "objective_evaluator.jl"), String)
    flat = replace(src, r"\s+" => "")
    # (a) the per-rotor gate's inlined raw literal is gone — invisible to
    #     `grep main_rotor_swept_area`, so only a source check catches it.
    @test !occursin("π*(sys.rotor.radius^2-sys.rotor.blade_hub_radius^2)", flat)
    # (b) the aggregate ceiling AND the Betz_cp floor both charge the projected
    #     area (two occurrences, one file).
    @test count("betz_wind_normal_area", flat) >= 2
    # (c) the per-rotor gate uses the bank-projected primitive.
    @test count("main_rotor_bank_projected_area", flat) >= 1
    # (d) the retired aggregate model is not what the ceiling prices.
    @test !occursin("A_total=main_rotor_swept_area(sys)", flat)
end

@testset "7. RED report: missing contract names" begin
    for m in MISSING
        @info "missing contract" m
    end
    @test isempty(MISSING)
end

end  # outer: "Betz ceiling projection — wind-normal (ZY) basis"

end # module BetzCeilingProjectionTests
