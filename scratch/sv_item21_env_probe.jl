# scratch/sv_item21_env_probe.jl — independent library read of the item-2.1 environment values
# (science-validator seat, 2026-10-15). Companion to scratch/av_item21_environment_probe.jl:
# the signing seat reads the same values through the shipped library.
#
# The three rows for sign: the shear law and exponent, the shaft-elevation angle
# source values, the steady-wind basis. This probe covers the library values of
# the first row and the wind reads the other two rows cite.
#
# Run: scripts/ktd-julia scratch/sv_item21_env_probe.jl

using KiteTurbineDynamics
using Printf
using Dates

const D = KiteTurbineDynamics

function main()::Bool
    ok = true
    println("sv_item21_env_probe — independent read of the item-2.1 values")
    println("generated: ", Dates.now(UTC), "  seat: science-validator")
    println("library: ", pathof(D))
    println()

    a = D.SITE_ANCHOR
    @printf("SITE_ANCHOR: name=%s v_ref=%.1f h_ref=%.1f shear_exp=%.17g\n",
        a.name, a.v_ref_ms, a.h_ref_m, a.shear_exp)
    ok &= a.name == "Tulloch, Daisy (measured)"
    ok &= a.v_ref_ms == 10.0
    ok &= a.h_ref_m == 4.8
    ok &= a.shear_exp == 1.0 / 7.0
    ok &= a === D.SITE_DAISY
    println("anchor is the Daisy spec: ", a === D.SITE_DAISY)
    println()

    want = [(4.8, 10.000000), (9.400, 11.007738), (9.4117, 11.009694), (8.914, 10.924573)]
    for (h, w) in want
        got = D.site_wind(h)
        good = abs(got - w) < 5e-7
        law = 10.0 * (h / 4.8)^(1.0 / 7.0)
        lawok = abs(got - law) <= 1e-12 * max(1.0, abs(law))
        ok &= good && lawok
        @printf("site_wind(%7.4f) = %.6f  want %.6f  [%s]  law read [%s]\n",
            h, got, w, good ? "PASS" : "FAIL", lawok ? "PASS" : "FAIL")
    end
    println()

    @printf("site_shear(9.4117, 9.4117) = %.12f\n", D.site_shear(9.4117, 9.4117))
    @printf("site_shear(9.4117, 4.8)    = %.12f\n", D.site_shear(9.4117, 4.8))
    ok &= D.site_shear(9.4117, 9.4117) == 1.0
    ok &= abs(D.site_shear(9.4117, 4.8) - 0.908290428006) < 5e-11
    println()

    println(ok ? "ALL CHECKS PASS" : "CHECK FAILURE")
    return ok
end

ok = main()
exit(ok ? 0 : 1)
