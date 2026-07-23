#!/usr/bin/env julia
# Stage 1b attribution: test 12-gon static evaluability with LEGACY_PHYSICS pin.
# If it works under legacy but fails under corrected, the unevaluability is
# caused by corrected physics (clean finding). If it still fails, suspect harness.
using KiteTurbineDynamics

const X12 = [0.075,0.01,1.0,0.5,3.7,2.0,2.5,12.0,0.0,8.0,15.0,5.0,0.5,0.3,log10(60.0)]
const BEAM = KiteTurbineDynamics.PROFILE_ELLIPTICAL

function test_static(legacy_physics)
    if legacy_physics
        KiteTurbineDynamics.EXPANSION_PHYSICS[].induction = false
        KiteTurbineDynamics.EXPANSION_PHYSICS[].blade_inertia = false
        KiteTurbineDynamics.EXPANSION_PHYSICS[].corrected_mass = false
    end
    p = KiteTurbineDynamics.params_v5_50kw()
    f10 = KiteTurbineDynamics.objective_v10(X12[1:14], BEAM, p; power_W=50000.0, v_rated=11.0)
    penalty_saturated = f10 > 1_000_000.0
    println("  f_v10=$f10  penalty_saturated=$penalty_saturated")
    return !penalty_saturated
end

println("=== Stage 1b attribution: 12-gon static evaluability ===\n")

println("LEGACY physics:")
ok_legacy = test_static(true)
println()

# Restore corrected physics
KiteTurbineDynamics.EXPANSION_PHYSICS[].induction = true
KiteTurbineDynamics.EXPANSION_PHYSICS[].blade_inertia = true
KiteTurbineDynamics.EXPANSION_PHYSICS[].corrected_mass = true

println("CORRECTED physics:")
ok_corrected = test_static(false)

println()
if ok_legacy && !ok_corrected
    println("Verdict: corrected physics makes the 12-gon unevaluable in static solver.")
    println("  This is a clean finding — not a harness bug.")
elseif ok_legacy && ok_corrected
    println("Verdict: 12-gon evaluable under both.  Script bug suspected for fos_pairs.")
else
    println("Verdict: 12-gon unevaluable under both.  Harness bug or design fundamentally unevaluable.")
end
