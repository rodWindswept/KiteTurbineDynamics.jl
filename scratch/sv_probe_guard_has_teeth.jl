# sv_probe_guard_has_teeth.jl — software-validator, 2026-10-02
#
# NEGATIVE CONTROL for test/test_winner_decode_invariant.jl.  A guard that cannot
# fail is worthless: reproduce the exact regression the guard exists to catch
# (a decode of the bank-derate winner that omits `rotor_count_mode=true`) and
# show the invariant `n_active == 1` BREAKS on it.  Expected: the assertion on
# the default path throws, the campaign path passes.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_guard_has_teeth.jl   (expect exit 1)

using KiteTurbineDynamics, Test, Printf

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))

const CSV = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
const x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
const L = 18.8

campaign = decode_winner(x; L=L, KW=5.0).dec

p = params_at_length(params_daisy(), L, 5.0)
xv = copy(x)
xv[4] = Float64(round(Int, clamp(xv[4], 3, 16)))
xv[6] = Float64(round(Int, clamp(xv[6], 1, 3)))
default = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=5000.0)  # NO rotor_count_mode

@printf("campaign decode (rotor_count_mode=true)  n_active=%d\n", campaign.n_active)
@printf("default  decode (rotor_count_mode=false) n_active=%d  rings=%s  banks=%s\n",
    default.n_active, string([r.ring_idx for r in default.rotors]),
    string([round(r.bank_angle_deg, digits=3) for r in default.rotors]))

@testset "negative control: a default-path decode must FAIL this invariant" begin
    @test campaign.n_active == 1                                  # must pass
    @test default.n_active == 1                                   # must FAIL
end
