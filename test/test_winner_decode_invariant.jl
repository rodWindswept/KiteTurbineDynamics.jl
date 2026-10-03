#!/usr/bin/env julia --project=.
#= test_winner_decode_invariant.jl — the single-rotor invariant for the v13 winner.

WHAT THIS LOCKS (Rod, 2026-10-02)
  The bank-derate 5 kW winner is a SINGLE-ROTOR machine.  A report that quotes
  two bank values for it ("10.7° at the top / 7.2° at the bottom") is quoting the
  two ends of a gradient gene, not two rotors.  This test pins the machine, not
  the prose: through the campaign's own decode (`decode_winner`, the single
  authority in `scripts/ode_gate_v13.jl`) the winner must yield exactly ONE
  rotor, on the TOP ring, with ZERO expansion rotors — so exactly one blade
  annulus is charged, and the bank derate is applied to it exactly once.

WHY IT IS NEEDED (measured 2026-10-02, docs/validation/2026-10-02-genome-index-and-preload-budget.md §2b)
  The winner's rotor gene is `x[6] = 1.267`, NOT 1.0.  Under
  `rotor_count_mode=true` (the campaign and the gate) that rounds to a count of
  one.  Under the DECODER DEFAULT (`rotor_count_mode=false`) the same value goes
  to `decode_rotor_mask` -> `VALID_ROTOR_MASKS[2]` = mask 9 -> TWO rotors on
  rings 10 and 7, with the "dead" `bank_bottom = 7.1830°` gene live.  So the
  invariant below is a property of the DECODE PATH, and any call site that
  hand-rolls `design_from_vector_v10` on a winner CSV silently builds the
  two-rotor machine instead.

DELIBERATELY NOT ASSERTED (canary, per @software-worker's refinement)
  The default-path disagreement is recorded in the comment above, not as a test:
  if the decoder default is ever fixed, the suite must not go red because a
  stale expectation about the BAD path stopped holding.  The spec is "the
  campaign path yields exactly one rotor".

Static (no ODE window) -> belongs in test/runtests.jl, not the acceptance file.
=#

module WinnerDecodeInvariantTests

using Test
using KiteTurbineDynamics
using Printf

# The gate's single-authority decode.  `ode_gate_v13.jl` guards its CLI with
# `abspath(PROGRAM_FILE) == @__FILE__`, so including it here defines the
# functions without running a gate.
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

const WINNERS = [
    "bank-derate winner (10-D, bank_top 10.7399°) => " =>
        joinpath(@__DIR__, "..", "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv"),
    "pre-derate winner (14-D, bank_top 19.9469°) => " =>
        joinpath(@__DIR__, "..", "scripts", "results",
            "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"),
]

read_genome(path) = [parse(Float64, s) for s in split(strip(read(path, String)), ",")]

@testset "winner decode: single-rotor invariant" begin
    for (label, csv) in WINNERS
        @testset "$label" begin
            @test isfile(csv)   # a missing winner CSV must fail loudly, not skip
            x = read_genome(csv)
            d = decode_winner(x; L=L18, KW=KW)
            dec = d.dec

            # 1. The campaign decode builds exactly one rotor.
            @test dec.n_active == 1
            @test length(dec.rotors) == 1

            # 2. That rotor is the MAIN rotor: it sits on the top ring, which is
            #    the ring the ODE models with the cp/ct disc model (ring_forces.jl).
            @test length(dec.rotors) == 1
            only_rotor = only(dec.rotors)
            @test only_rotor.ring_idx == dec.n_rings

            # 3. Bank reaches the machine as a SINGLE value.  With n_active == 1
            #    the gradient collapses (t = 0), so the operative bank is
            #    bank_top; bank_bottom must not appear anywhere in the rotor set.
            @test only_rotor.bank_angle_deg == d.xv[length(x) >= 14 ? 11 : 7]
            @test only_rotor.wind_factor == 1.0   # no downstream rotor to de-rate

            # 4. End-to-end: one main rotor, zero expansion rotors.  The
            #    hub-exclusion rule (builders_util.jl:91) drops the top-ring rotor
            #    from the expansion list, so a single top-ring rotor means the
            #    expansion list is EMPTY — no annulus is charged twice.
            sys, _u0, _pc = KiteTurbineDynamics.build_system_from_v10(
                dec, 1.0, d.k_mp;
                tether_diameter=d.p.tether_diameter, base_params=d.p,
            )
            @test length(sys.expansion_rotors) == 0
            @test sys.rotor.bank_angle_deg == only_rotor.bank_angle_deg
        end
    end
end

end # module WinnerDecodeInvariantTests
