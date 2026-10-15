# scratch/av_item21_environment_probe.jl — the item-2.1 environment reads (aero seat, 2026-10-15).
#
# The v0.54 scope note (author seat) leaves three §3.3 environment items outside
# the signed set: the shear law and its exponent, the shaft-elevation angle, and
# the steady-wind note for the window swing (Harris review item 2.1).
#
# This probe reads the wind authority through the shipped library:
#   - the anchor site spec (measured pair and exponent),
#   - the site profile at the reference altitudes (site mast, design hub, rung
#     reference, settled hub),
#   - the shear shape at the reference height.
# It re-checks the values the pinned tests carry (test_bem_unified.jl:202,
# test_betz_ceiling_projection.jl:205, test_wind_authority.jl:49-54) and the
# settled-basis read of register boundary note 5 (numbers-register.md:618-622).
#
# Run: scripts/ktd-julia scratch/av_item21_environment_probe.jl

using KiteTurbineDynamics
using Printf
using Dates

const D = KiteTurbineDynamics

println("av_item21_environment_probe — the item-2.1 environment reads")
println("generated: ", Dates.now(UTC), "  seat: aero-validator")
println("library: ", pathof(D))
println("base: 94f338c (branch bank-derate-cos2p65)")
println()

println("SITE_ANCHOR = ", repr(D.SITE_ANCHOR))
@printf("shear_exp   = %.17g  (1/7 = %.17g)\n", D.SITE_ANCHOR.shear_exp, 1 / 7)
println()

# The site profile at the four reference altitudes of the three rows:
#   4.8   — the measured pair (Daisy anemometer mast)
#   9.400 — the design hub altitude (18.8 m × sin 30°)
#   9.4117 — the rung reference height p.h_ref
#   8.914 — the settled hub mean z (register boundary note 5)
for h in (4.8, 9.400, 9.4117, 8.914)
    @printf("site_wind(%.4f) = %.6f\n", h, D.site_wind(h))
end
@printf("site_shear(9.4117, 9.4117) = %.12f\n", D.site_shear(9.4117, 9.4117))
@printf("site_shear(9.4117, 4.8)    = %.12f\n", D.site_shear(9.4117, 4.8))
println()

ok = true
ok &= D.SITE_ANCHOR.name == "Tulloch, Daisy (measured)"
ok &= D.SITE_ANCHOR.v_ref_ms == 10.0
ok &= D.SITE_ANCHOR.h_ref_m == 4.8
ok &= D.SITE_ANCHOR.shear_exp == 1 / 7
ok &= D.SITE_ANCHOR === D.SITE_DAISY             # the anchor is the Daisy spec
ok &= isapprox(D.site_wind(9.400), 11.0077; atol=1e-3)   # test_bem_unified.jl:202
ok &= isapprox(D.site_wind(9.4117), 11.0097; atol=1e-3)  # test_betz_ceiling_projection.jl:205
ok &= isapprox(D.site_wind(8.914), 10.9246; atol=1e-3)   # register boundary note 5 (10.924)
ok &= D.site_shear(9.4117, 9.4117) == 1.0
println(ok ? "all checks pass" : "CHECK FAILURE")
exit(ok ? 0 : 1)
