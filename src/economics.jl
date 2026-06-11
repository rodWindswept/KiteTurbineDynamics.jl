# src/economics.jl
# Pure-functions economics module for the TRPT kite turbine.
# Computes LCOE, capital cost, carbon analysis, and competitor comparison.
# No plotting/GLMakie dependency — usable from any context.

module Economics

using DataFrames, Printf

# Local copy of Dyneema density (kg/m³) — self-contained, no parent-module dependency
const DYNEEMA_DENSITY = 970.0

# Forward-declare SystemParams for method signatures (actual type lives in parent)
# We use duck-typing: any struct with the required field names will work.
# This keeps Economics independent of the parent module's type hierarchy.

export CostModel,
    default_cost_model_2026,
    compute_capital_cost,
    compute_lcoe,
    compute_carbon,
    competitor_comparison,
    compute_cost_breakdown,
    compute_mass_breakdown,
    compute_annual_energy,
    compute_annual_revenue

# ── Cost Model ──────────────────────────────────────────────────────────────────

"""
    CostModel

All cost and carbon assumptions for a given year/scenario.
All monetary values in GBP (£).  Carbon values in kgCO2e.
"""
struct CostModel
    # Mass-based costs
    cost_per_kg_cfrp::Float64        # £/kg — CFRP tubes (pultruded, small-diameter)
    cost_per_kg_dyneema::Float64     # £/kg — Dyneema SK78 rope
    cost_per_knuckle::Float64        # £/each — machined aluminium knuckle

    # Component costs
    cost_per_kg_blade::Float64       # £/kg — GFRP rotor blades (hand layup)
    cost_per_kw_generator::Float64   # £/kW — PMG + gearbox

    # Fixed costs
    cost_ground_station_fixed::Float64  # £ — steel frame + foundation
    cost_ground_station_per_kw::Float64 # £/kW
    cost_lift_kite_fixed::Float64       # £ — ripstop nylon + bridle base
    cost_lift_kite_per_m2::Float64      # £/m²
    cost_installation::Float64          # £ — crane + crew, 1 day
    cost_grid_connection::Float64       # £ — single-phase <50kW

    # O&M
    om_rate::Float64                    # fraction of capital per year

    # Carbon
    kgco2_per_kg_cfrp::Float64      # kgCO2e/kg embodied
    kgco2_per_kg_dyneema::Float64
    kgco2_per_kg_steel::Float64
end

"""
    default_cost_model_2026()

Return a `CostModel` with 2026 cost estimates for the 10 kW kite turbine.
All values in 2026 GBP.  Based on small-batch / pilot-production pricing.
"""
function default_cost_model_2026()
    return CostModel(
        25.0,    # CFRP £/kg — pultruded small-diameter tubes
        40.0,    # Dyneema £/kg — SK78 rope
        3.0,     # knuckle £/each — machined aluminium
        120.0,   # blade £/kg — GFRP hand layup
        200.0,   # generator £/kW — PMG + gearbox
        2000.0,  # ground station fixed £
        50.0,    # ground station per-kW £/kW
        250.0,   # lift kite fixed £
        15.0,    # lift kite per-m² £/m²
        3000.0,  # installation £ — crane + crew, 1 day (10kW scale)
        2000.0,  # grid connection £ — single-phase <50kW
        0.02,    # O&M rate (2%/year)
        24.0,    # CFRP kgCO2e/kg
        5.0,     # Dyneema kgCO2e/kg
        2.0,     # Steel kgCO2e/kg
    )
end

# ── Mass Breakdown ──────────────────────────────────────────────────────────────

"""
    compute_mass_breakdown(p::SystemParams)

Return a named tuple with mass components (kg):
  - dyneema_kg: total Dyneema line mass
  - knuckle_count: number of aluminium knuckles (= n_rings × n_lines)
  - cfrp_tube_kg: CFRP tube mass (rings minus knuckle mass estimate)
  - blade_kg: total blade mass
  - total_airborne_kg: total airborne mass
  - ground_steel_kg: approximate ground station steel mass
"""
function compute_mass_breakdown(p)   # p is a SystemParams-like struct (duck-typed)
    # Dyneema mass: n_lines × length × cross-sectional area × density
    line_xs_area = π * (p.tether_diameter / 2.0)^2
    dyneema_kg = p.n_lines * p.tether_length * line_xs_area * DYNEEMA_DENSITY

    # Knuckle count: one per line per ring
    knuckle_count = p.n_rings * p.n_lines
    # Approximate knuckle mass ~0.015 kg each (machined aluminium, M3 clevis size)
    knuckle_mass_each = 0.015
    knuckle_kg = knuckle_count * knuckle_mass_each

    # CFRP tubes: rings are m_ring each, subtract the knuckle mass contribution
    # For polygon rings with n_lines beams: each ring has n_lines CFRP beams
    beam_per_ring_kg = p.m_ring - p.n_lines * knuckle_mass_each
    cfrp_tube_kg = p.n_rings * beam_per_ring_kg

    # Ensure non-negative (safety clamp)
    if cfrp_tube_kg < 0.0
        # Fallback: treat full ring mass as CFRP if knuckle estimate overshoots
        cfrp_tube_kg = p.n_rings * p.m_ring
        knuckle_kg = 0.0
        knuckle_count = 0
    end

    # Blades
    blade_kg = p.n_blades * p.m_blade

    # Total airborne (CFRP + Dyneema + knuckles + blades)
    total_airborne_kg = cfrp_tube_kg + dyneema_kg + knuckle_kg + blade_kg

    # Ground station steel estimate: ~15 kg/kW for frame + foundation
    ground_steel_kg = 15.0 * (p.p_rated_w / 1000.0)

    return (;
        dyneema_kg,
        knuckle_count,
        cfrp_tube_kg,
        blade_kg,
        knuckle_kg,
        total_airborne_kg,
        ground_steel_kg,
    )
end

# ── Capital Cost ────────────────────────────────────────────────────────────────

"""
    compute_capital_cost(p::SystemParams, cm::CostModel) -> Float64

Compute the total capital cost (£) for a TRPT kite turbine system.
Includes all airborne components, ground station, lift kite, installation,
and grid connection.
"""
function compute_capital_cost(p, cm::CostModel)::Float64
    mb = compute_mass_breakdown(p)

    # Airborne components
    cost_cfrp = mb.cfrp_tube_kg * cm.cost_per_kg_cfrp
    cost_dyneema = mb.dyneema_kg * cm.cost_per_kg_dyneema
    cost_knuckles = mb.knuckle_count * cm.cost_per_knuckle
    cost_blades = mb.blade_kg * cm.cost_per_kg_blade

    # Generator
    rated_kw = p.p_rated_w / 1000.0
    cost_generator = rated_kw * cm.cost_per_kw_generator

    # Ground station
    cost_ground = cm.cost_ground_station_fixed + rated_kw * cm.cost_ground_station_per_kw

    # Lift kite — area estimated from power scaling
    # Approximate: ~2 m² for 10 kW, scaling with power^0.5
    lift_area_m2 = 2.0 * sqrt(rated_kw / 10.0)
    cost_lift_kite = cm.cost_lift_kite_fixed + lift_area_m2 * cm.cost_lift_kite_per_m2

    # Fixed costs
    cost_install = cm.cost_installation
    cost_grid = cm.cost_grid_connection

    total =
        cost_cfrp +
        cost_dyneema +
        cost_knuckles +
        cost_blades +
        cost_generator +
        cost_ground +
        cost_lift_kite +
        cost_install +
        cost_grid

    return total
end

"""
    compute_cost_breakdown(p::SystemParams, cm::CostModel)

Return a named tuple with itemised costs for use in dashboard visualizations.
"""
function compute_cost_breakdown(p, cm::CostModel)
    mb = compute_mass_breakdown(p)
    rated_kw = p.p_rated_w / 1000.0
    lift_area_m2 = 2.0 * sqrt(rated_kw / 10.0)

    return (;
        cfrp_tubes=mb.cfrp_tube_kg * cm.cost_per_kg_cfrp,
        dyneema=mb.dyneema_kg * cm.cost_per_kg_dyneema,
        knuckles=mb.knuckle_count * cm.cost_per_knuckle,
        blades=mb.blade_kg * cm.cost_per_kg_blade,
        generator=rated_kw * cm.cost_per_kw_generator,
        ground_station=cm.cost_ground_station_fixed +
                       rated_kw * cm.cost_ground_station_per_kw,
        lift_kite=cm.cost_lift_kite_fixed + lift_area_m2 * cm.cost_lift_kite_per_m2,
        installation=cm.cost_installation,
        grid_connection=cm.cost_grid_connection,
        total=compute_capital_cost(p, cm),
    )
end

# ── LCOE ────────────────────────────────────────────────────────────────────────

"""
    compute_lcoe(p::SystemParams, cm::CostModel;
                 cf::Float64 = 0.30,
                 discount_rate::Float64 = 0.07,
                 life_years::Float64 = 20.0) -> Float64

Compute the Levelized Cost of Energy in £/MWh.

# Arguments
- `p`: System parameters for the turbine configuration.
- `cm`: Cost model with material and component pricing.
- `cf`: Capacity factor (0–1).  Default 0.30 (30%).
- `discount_rate`: Annual discount rate.  Default 0.07 (7%).
- `life_years`: Asset lifetime in years.  Default 20.

# Returns
LCOE in £/MWh.  Divide by 10 to get p/kWh.
"""
function compute_lcoe(
    p,
    cm::CostModel;
    cf::Float64=0.30,
    discount_rate::Float64=0.07,
    life_years::Float64=20.0,
)::Float64
    capital_total = compute_capital_cost(p, cm)

    # Capital Recovery Factor
    if discount_rate ≈ 0.0
        crf = 1.0 / life_years
    else
        crf =
            discount_rate * (1.0 + discount_rate)^life_years /
            ((1.0 + discount_rate)^life_years - 1.0)
    end

    annual_capital = capital_total * crf
    annual_om = capital_total * cm.om_rate
    total_annual = annual_capital + annual_om

    # Annual energy production
    rated_mw = p.p_rated_w / 1_000_000.0   # MW
    hours_per_year = 365.25 * 24.0          # 8766 h
    annual_mwh = rated_mw * cf * hours_per_year

    if annual_mwh <= 0.0
        return Inf
    end

    return total_annual / annual_mwh   # £/MWh
end

"""
    compute_annual_energy(p::SystemParams, cf::Float64=0.30) -> Float64

Compute the annual energy production in MWh.
"""
function compute_annual_energy(p, cf::Float64=0.30)::Float64
    rated_mw = p.p_rated_w / 1_000_000.0
    hours_per_year = 365.25 * 24.0
    return rated_mw * cf * hours_per_year
end

"""
    compute_annual_revenue(p::SystemParams, ppa_price_p_kwh::Float64, cf::Float64=0.30) -> Float64

Compute the annual revenue (£) at a given PPA price (p/kWh).
"""
function compute_annual_revenue(p, ppa_price_p_kwh::Float64, cf::Float64=0.30)::Float64
    annual_mwh = compute_annual_energy(p, cf)
    return annual_mwh * ppa_price_p_kwh * 10.0   # MWh → kWh, p → £
end

# ── Carbon Analysis ─────────────────────────────────────────────────────────────

"""
    compute_carbon(p::SystemParams, cm::CostModel;
                   grid_intensity::Float64 = 0.233) -> NamedTuple

Compute the carbon footprint and offset for a TRPT kite turbine.

# Arguments
- `grid_intensity`: Grid carbon intensity in kgCO2e/kWh.
  Default 0.233 = UK 2026 projected grid average.

# Returns
Named tuple with:
  - embodied_kg: total embodied carbon (kgCO2e)
  - annual_offset_kg: annual carbon offset vs grid (kgCO2e)
  - payback_months: carbon payback time (months)
  - embodied_per_kwh: embodied carbon per kWh over lifetime (gCO2e/kWh)
"""
function compute_carbon(
    p,
    cm::CostModel;
    grid_intensity::Float64=0.233,
    cf::Float64=0.30,
    life_years::Float64=20.0,
)
    mb = compute_mass_breakdown(p)

    # Embodied carbon by material
    co2_cfrp = mb.cfrp_tube_kg * cm.kgco2_per_kg_cfrp
    co2_dyneema = mb.dyneema_kg * cm.kgco2_per_kg_dyneema
    co2_steel = mb.ground_steel_kg * cm.kgco2_per_kg_steel
    # Blades: GFRP — use CFRP carbon factor as conservative proxy
    co2_blades = mb.blade_kg * cm.kgco2_per_kg_cfrp
    # Electronics/PMG: ~10 kgCO2e/kg estimated
    co2_generator = 10.0 * (p.p_rated_w / 1000.0)

    embodied_kg = co2_cfrp + co2_dyneema + co2_steel + co2_blades + co2_generator

    # Annual grid offset
    annual_mwh = compute_annual_energy(p, cf)
    annual_offset_kg = annual_mwh * 1000.0 * grid_intensity   # MWh → kWh

    # Payback in months
    if annual_offset_kg > 0.0
        payback_years = embodied_kg / annual_offset_kg
        payback_months = payback_years * 12.0
    else
        payback_months = Inf
    end

    # Lifetime carbon intensity
    lifetime_kwh = annual_mwh * 1000.0 * life_years
    embodied_per_kwh = lifetime_kwh > 0.0 ? (embodied_kg * 1000.0) / lifetime_kwh : Inf
    # gCO2e/kWh

    return (;
        embodied_kg,
        annual_offset_kg,
        payback_months,
        embodied_per_kwh,        # gCO2e/kWh
        breakdown=(;
            cfrp=co2_cfrp,
            dyneema=co2_dyneema,
            steel=co2_steel,
            blades=co2_blades,
            generator=co2_generator,
        ),
    )
end

# ── Competitor Comparison ───────────────────────────────────────────────────────

"""
    competitor_comparison() -> DataFrame

Return a DataFrame comparing LCOE, carbon intensity, and capacity factor
for kite turbines vs other generation technologies.

Source data: Lazard LCOE 2024, BEIS 2023, Windswept internal estimates.
"""
function competitor_comparison()
    return DataFrame(;
        Technology=[
            "Kite Turbine\n(TRPT 10kW)",
            "Kite Turbine\n(TRPT 50kW)",
            "Rooftop Solar PV\n(50kWp)",
            "Onshore Wind\n(1 MW)",
            "Offshore Wind\n(10 MW)",
            "Gas Peaker\n(OCGT)",
            "Nuclear\n(EPR)",
        ],
        LCOE_p_kWh=[
            4.8,    # TRPT 10kW — ~5p/kWh target
            3.5,    # TRPT 50kW — scale benefits
            7.0,    # Rooftop solar ~7p/kWh
            5.5,    # Onshore wind
            9.0,    # Offshore wind
            15.0,   # Gas peaker
            12.0,   # Nuclear
        ],
        Carbon_g_kWh=[
            0.17,   # TRPT — ultra-low materials
            0.12,   # TRPT 50kW — lower per-kW embodied
            41.0,   # Solar PV
            11.0,   # Onshore wind
            12.0,   # Offshore wind
            490.0,  # Gas (CCGT ~350–490)
            12.0,   # Nuclear
        ],
        Capacity_Factor=[
            0.30,   # Kite 10kW — higher altitude wind
            0.35,   # Kite 50kW — larger swept area, higher altitude
            0.11,   # Solar UK ~11%
            0.30,   # Onshore wind
            0.45,   # Offshore wind
            0.10,   # Gas peaker (dispatchable but low utilisation)
            0.90,   # Nuclear baseload
        ],
        Annual_MWh=[
            26.3,   # 10kW × 30% × 8766h
            153.4,  # 50kW × 35% × 8766h
            44.0,   # 50kWp × 11% × 8766h ≈ 48 MWh (rounded)
            2628.0, # 1MW × 30% × 8766h
            39420.0,# 10MW × 45% × 8766h
            876.0,  # 100MW × 10% × 8766h ... but per-unit
            7884.0, # 1GW × 90% × 8766h ... but per-unit, scaled
        ],
    )
end

end # module Economics
