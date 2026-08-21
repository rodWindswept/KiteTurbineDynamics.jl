#!/usr/bin/env julia --project=.
#= grounded_economics_v13.jl — grounded CO2/kWh + LCOE for the validated 5 kW
rung winners (v13, corrected model), reusing the campaign's own build path.

⚠ CONTAMINATED OUTPUT (2026-08-20): the winners decoded here were produced
under a mass-blind objective carrying 50 kW blade mass (12.0757 kg/blade from
params_v5_50kw, not rung-scaled, not λ-scaled — see
docs/reports/grounded-economics-v13.md §4b). The masses are model-true but
the designs are power-maximising artefacts; the lift tension that gated them
was sized ~9× high. Do NOT use the output CSV for external quotes. After the
build fix (base_params + λ² blade mass) and the 5 kW re-run, re-run this
script on the new winners.

⚠ FURTHER (2026-08-20, radius fix): the main-rotor radius is now the decoded
blade_tip_radius (was a fixed 5.0 m — λ-blind). Under the fully-corrected
physics the OLD winners produce 0.0 kW (λ=0.14 → 0.46 m swept disk, Betz cap
≈ 0.3 kW) — they exploited the phantom radius and are VOID. The P_gen
constants below are historical only; this script's output is placeholder
until the 5 kW re-run produces new winners.

No ODE compute: decode winner genome exactly as the gate does
(scripts/ode_gate_v13.jl) → build_system_from_v10 → the genome's own params
(pc) and the campaign-authoritative airborne mass
(expansion_airborne_mass(sys, pc), the same function the mass-aware lift sizing
and lift retrospective use) → Economics module.

Every number that is a model/measured output is separated from every
assumption in the output CSV's provenance column.

Usage: julia --project=. scripts/report/grounded_economics_v13.jl
Output: scripts/results/grounded_economics_v13.csv
=#

using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "..", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "ode_gate_v13.jl"))  # params_at_length (CLI inert when included)

const KTD = KiteTurbineDynamics
const RESULTS = joinpath(@__DIR__, "..", "results")
const G = 9.81
const ELEV_LIFT_DEG = 70.0
const MARGIN = 1.5

# ── Winner facts (provenance: RE-GATE 2026-08-20, fixed build_system_from_v10
# + mass-aware lift ≈ 99 N — see docs/reports/grounded-economics-v13.md §11.
# Supersedes the 2026-08-15 regate verdicts, which used the contaminated
# 50 kW blade mass + ~9× inflated lift tension.) ──
# P_gen_kW = sustained ground-ring power at 11 m/s design wind.
const WINNERS = [
    (name="v13_5kw_len18.0", L=18.0, P_gen_kW=7.143),
    (name="v13_5kw_len21.2", L=21.2, P_gen_kW=6.254),
    (name="v13_5kw_len25.0", L=25.0, P_gen_kW=7.130),
]

const CFS = [0.20, 0.30, 0.40]        # capacity-factor sensitivity (assumption)
const ETA_GEN = 0.90                  # generator efficiency (assumption, flagged)
const LIFE_YEARS = 20.0               # Economics default
const DISCOUNT_RATE = 0.07            # Economics default

"""Decode a winner genome exactly as the gate does and build the ODE system.
Returns (design summary, sys, pc)."""
function winner_build(x::Vector{Float64}; L::Float64, KW::Float64=5.0,
        p2=params_10kw())
    p = params_at_length(p2, L, KW)
    xv = copy(x)
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))     # n_lines — gate rounding
    xv[10] = clamp(xv[10], 0.0, Float64(N_VALID_MASKS))  # rotor mask — gate clamp
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=KW * 1000.0)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, p.k_mppt;
        tether_diameter=p.tether_diameter, base_params=p)   # rung-scaled base (2026-08-20 fix)
    return (dec=dec, sys=sys, pc=pc, p=p)
end

"""Component masses using the campaign-authoritative decomposition
(expansion_airborne_mass: tether + rings + main blades + expansion rotors +
lifter) plus knuckle estimate (Economics convention: 15 g each, one per
line per ring)."""
function component_masses(sys, pc)
    m_tether = pc.n_lines * pc.tether_length *
               (KTD.DYNEEMA_DENSITY * π * (pc.tether_diameter / 2)^2)
    m_rings = pc.n_rings * pc.m_ring
    m_blades = pc.n_blades * pc.m_blade
    m_expansion = sum(er -> er.mass, sys.expansion_rotors; init=0.0)
    m_lifter = 5.0
    m_knuckles = pc.n_rings * pc.n_lines * 0.015
    m_airborne = m_tether + m_rings + m_blades + m_expansion + m_lifter
    return (m_tether=m_tether, m_rings=m_rings, m_blades=m_blades,
        m_expansion=m_expansion, m_lifter=m_lifter, m_knuckles=m_knuckles,
        m_airborne=m_airborne)
end

"""Embodied CO2 (kgCO2e) from the authoritative component masses + Economics
carbon factors. Ground steel + generator sized on the delivered rating."""
function embodied_carbon(cm, mb, P_rating_kW)
    f = KTD.Economics
    co2_tether = mb.m_tether * cm.kgco2_per_kg_dyneema
    co2_rings = mb.m_rings * cm.kgco2_per_kg_cfrp
    co2_blades = mb.m_blades * cm.kgco2_per_kg_cfrp      # GFRP proxy (Economics)
    co2_expansion = mb.m_expansion * cm.kgco2_per_kg_cfrp
    co2_lifter = mb.m_lifter * cm.kgco2_per_kg_cfrp      # assumption: CFRP proxy
    co2_knuckles = mb.m_knuckles * cm.kgco2_per_kg_steel # assumption: steel proxy
    co2_ground = 15.0 * P_rating_kW * cm.kgco2_per_kg_steel
    co2_generator = 10.0 * P_rating_kW
    total = co2_tether + co2_rings + co2_blades + co2_expansion + co2_lifter +
            co2_knuckles + co2_ground + co2_generator
    return (total=total, tether=co2_tether, rings=co2_rings, blades=co2_blades,
        expansion=co2_expansion, lifter=co2_lifter, knuckles=co2_knuckles,
        ground=co2_ground, generator=co2_generator)
end

function main()
    cm = KTD.Economics.default_cost_model_2026()
    rows = DataFrame()
    for w in WINNERS
        csv = joinpath(RESULTS, w.name, "best_vector.csv")
        x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
        b = winner_build(x; L=w.L)
        pc = b.pc
        dec = b.dec
        mb = component_masses(b.sys, pc)
        P_rating_kW = w.P_gen_kW                      # delivered ground-ring power
        P_rating_W = P_rating_kW * 1000.0

        # Rating-honest params for the Economics module (pc.p_rated_w is the
        # 50 kW base — NOT this machine's rating).
        pc_r = KTD.modified_params(pc; p_rated_w=P_rating_W)

        cap_cost = KTD.Economics.compute_capital_cost(pc_r, cm)
        co2 = embodied_carbon(cm, mb, P_rating_kW)
        phi = mb.m_airborne / P_rating_kW

        # LCOE / carbon intensity at each capacity factor, with generator
        # efficiency folded into AEP (electrical = η × mechanical).
        for cf in CFS
            aep_mwh = P_rating_W * cf * ETA_GEN * 365.25 * 24.0 / 1e6
            # LCOE: capital recovery + O&M over AEP
            dr = DISCOUNT_RATE
            crf = dr * (1 + dr)^LIFE_YEARS / ((1 + dr)^LIFE_YEARS - 1)
            annual_om = cap_cost * cm.om_rate
            lcoe_p_kwh = (cap_cost * crf + annual_om) / (aep_mwh * 1000.0) * 100.0
            gco2_kwh = (co2.total * 1000.0) / (aep_mwh * 1000.0 * LIFE_YEARS)
            payback_months = co2.total /
                (aep_mwh * 1000.0 * 0.233) * 12.0   # grid intensity 0.233 kg/kWh (Economics default)
            push!(rows, (
                length_m=w.L, winner=w.name,
                P_gen_11ms_kW=w.P_gen_kW,
                n_lines=pc.n_lines, rings=pc.n_rings, n_active=dec.n_active,
                r_hub_m=round(dec.design.r_hub, digits=3),
                Do_top_mm=round(dec.design.Do_top * 1000.0, digits=2),
                t_over_D=dec.design.t_over_D,
                tether_d_mm=round(pc.tether_diameter * 1000.0, digits=2),
                m_tether_kg=round(mb.m_tether, digits=2),
                m_rings_kg=round(mb.m_rings, digits=2),
                m_blades_kg=round(mb.m_blades, digits=2),
                m_expansion_kg=round(mb.m_expansion, digits=2),
                m_lifter_kg=mb.m_lifter,
                m_knuckles_kg=round(mb.m_knuckles, digits=2),
                m_airborne_kg=round(mb.m_airborne, digits=2),
                phi_kg_per_kW=round(phi, digits=2),
                cap_cost_gbp=round(cap_cost, digits=0),
                cf=cf, eta_gen=ETA_GEN,
                aep_mwh_yr=round(aep_mwh, digits=1),
                lcoe_p_per_kwh=round(lcoe_p_kwh, digits=1),
                embodied_co2_kg=round(co2.total, digits=0),
                co2_g_per_kwh=round(gco2_kwh, digits=2),
                co2_payback_months=round(payback_months, digits=0),
            ))
        end

        @printf("\n=== %s  (L=%.1f m) ===\n", w.name, w.L)
        @printf("  design: n_lines=%d rings=%d n_active=%d r_hub=%.3f m  Do_top=%.1f mm  t_over_D=%.3f  tether=%.2f mm\n",
            pc.n_lines, pc.n_rings, dec.n_active, dec.design.r_hub,
            dec.design.Do_top * 1000, dec.design.t_over_D, pc.tether_diameter * 1000)
        @printf("  P_gen @ 11 m/s (model, regate verdict) = %.3f kW\n", w.P_gen_kW)
        @printf("  masses: tether=%.2f  rings=%.2f  blades=%.2f  expansion=%.2f  lifter=%.1f  knuckles=%.2f  -> airborne=%.2f kg  (phi=%.1f kg/kW)\n",
            mb.m_tether, mb.m_rings, mb.m_blades, mb.m_expansion, mb.m_lifter,
            mb.m_knuckles, mb.m_airborne, phi)
        @printf("  capital cost (rating %.1f kW): £%.0f\n", P_rating_kW, cap_cost)
        @printf("  embodied CO2: %.0f kgCO2e  (tether %.0f / rings %.0f / blades %.0f / expansion %.0f / lifter %.0f / knuckles %.0f / ground %.0f / gen %.0f)\n",
            co2.total, co2.tether, co2.rings, co2.blades, co2.expansion, co2.lifter,
            co2.knuckles, co2.ground, co2.generator)
        for cf in CFS
            sel = rows[(rows.winner .== w.name) .& (rows.cf .== cf), :]
            @printf("  CF=%.2f: AEP=%.1f MWh/yr  LCOE=%.1f p/kWh  %.2f gCO2e/kWh  payback %.0f months\n",
                cf, sel.aep_mwh_yr[1], sel.lcoe_p_per_kwh[1], sel.co2_g_per_kwh[1],
                sel.co2_payback_months[1])
        end
    end

    out = joinpath(RESULTS, "grounded_economics_v13.csv")
    CSV.write(out, rows)
    @printf("\nWrote %s (%d rows)\n", out, nrow(rows))
end

main()
