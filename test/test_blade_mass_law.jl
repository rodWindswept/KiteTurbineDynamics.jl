# test/test_blade_mass_law.jl — unified blade-mass law: m = m_ref · λ³ (2026-08-22)
#
# Rod (2026-08-22): rigid-foam blades scale with VOLUME (λ³), not area (λ²).
# The main-rotor λ² term and the CFRP (0.3 + 0.1·tip) expansion constants are
# rejected. The measured Daisy blade (420 g) is the anchor — the Gate 1c
# renormalisation to 210 g is REVERSED (the 6-blade machine carries
# 6 × 420 g = 2.52 kg/ring). Knuckle mass (≥ 0.050 kg/blade, approved
# 2026-04-20) enters the airborne mass (DE score + lift sizing).
#
# RED on HEAD pre-fix; GREEN after the law lands. See
# docs/plans/2026-08-22-blade-mass-volume-law.md.
using Test
using KiteTurbineDynamics
import KiteTurbineDynamics: expansion_blade_mass, geometry_fingerprint

@testset "unified blade-mass law (2026-08-22)" begin

    @testset "reference anchor" begin
        @test KiteTurbineDynamics.M_BLADE_REF_KG == 0.420
        # Measured Daisy blade restored (was 0.210 under Gate 1c)
        @test params_daisy().m_blade == 0.420
    end

    @testset "expansion blade mass — span³ volume law, measured anchor" begin
        # Daisy reference: span 1.0 m (tips 1.22/2.22, ring 1.52) → 420 g.
        # 6-blade assembly at span 1.0: 6 × 420 g = 2.52 kg (Rod 2026-08-22).
        @test expansion_blade_mass(1.0, 6) ≈ 6 * 0.420 atol=1e-12
        # no n_blades → legacy 3-blade assembly convention
        @test expansion_blade_mass(1.0) ≈ 3 * 0.420 atol=1e-12
        # volume law: half span → ⅛ mass
        @test expansion_blade_mass(0.5, 6) ≈ 6 * 0.420 * 0.5^3 atol=1e-12
        # THE EXPLOIT GUARD (2026-08-22, 5 kW campaign winners VOID): the DE
        # chose small λ (0.497) with the BEM-sized r_rotor (3.32 m) → decoded
        # span 1.238 m, priced by the old λ³ law at 0.262 kg/blade.  The law
        # must price the ACTUAL span: 0.42·1.238³ = 0.797 kg/blade.
        @test expansion_blade_mass(1.238, 3) ≈ 3 * 0.420 * 1.238^3 rtol=1e-9
        @test !isapprox(expansion_blade_mass(1.238, 3), 3 * 0.420 * 0.497^3; rtol=1e-9)
        # the dead CFRP constants must be gone (0.37 kg at tip 0.7, λ=1)
        @test !isapprox(expansion_blade_mass(1.0, 3), 0.37; atol=1e-9)
    end

    @testset "build_system_from_v10 — main rotor prices the decoded span" begin
        include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
        x = seed_genome(5.0)
        x[10] = 0.6                    # 2 rotors: hub + 1 intermediate expansion
        x[13] = 0.5; x[14] = 0.5      # blade_scale_top/bottom
        base = params_daisy()
        result = design_from_vector_v10(
            x, PROFILE_ELLIPTICAL, base; power_W=5000.0, v_rated=11.0
        )
        hub = first(r for r in result.rotors if r.ring_idx == result.n_rings)
        span_hub = hub.blade_tip_radius - hub.blade_hub_radius
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            result, 1.0, 5.39; base_params=base
        )
        # per-blade mass = M_BLADE_REF_KG · (decoded span)³ — NOT λ³, NOT
        # λ².  The decoder span = 0.75·r_rotor·λ (r_rotor from the BEM power
        # sizing) — the mass law must price that span or the DE exploits
        # small λ with large r_rotor (15× under-price on the winners).
        @test pc.m_blade ≈ 0.420 * span_hub^3 rtol=1e-9
        @test !isapprox(pc.m_blade, base.m_blade * hub.blade_scale^3; rtol=1e-9)

        # HUB EXCLUSION (2026-08-22): the hub rotor (ring_idx == n_rings) is
        # the MAIN rotor — no expansion entry, no double-modelled annulus,
        # no double-counted mass.  Only INTERMEDIATE rotors become expansion
        # entries, one per decoded rotor with ring_idx != n_rings.
        non_hub = filter(r -> r.ring_idx != result.n_rings, result.rotors)
        @test length(sys.expansion_rotors) == length(non_hub)
        hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
        @test all(er.ring_idx != hub_ri for er in sys.expansion_rotors)
        for (er, rotor) in zip(sys.expansion_rotors, non_hub)
            span_er = rotor.blade_tip_radius - rotor.blade_hub_radius
            # span³ law: n_blades · 0.420 · (decoded span)³ — prices the
            # blade volume, NOT λ³ (the winners-exploit form).
            @test er.mass ≈ er.n_blades * 0.420 * span_er^3 rtol=1e-9
        end
    end

    @testset "knuckle floor + full airborne accounting" begin
        include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
        x = seed_genome(5.0)
        x[10] = 0.6                    # hub + 1 expansion rotor
        base = params_daisy()
        result = design_from_vector_v10(
            x, PROFILE_ELLIPTICAL, base; power_W=5000.0, v_rated=11.0
        )
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            result, 1.0, 5.39; base_params=base
        )
        m_air = expansion_airborne_mass(sys, pc; include_lifter=false)

        knuckle_kg = KiteTurbineDynamics.OPT_KNUCKLE_MASS_KG
        m_knuckles = (pc.n_blades + sum(er.n_blades for er in sys.expansion_rotors)) * knuckle_kg
        m_tether = pc.n_lines * pc.tether_length *
            (KiteTurbineDynamics.DYNEEMA_DENSITY * π * (pc.tether_diameter / 2)^2)
        m_rings = (sys.n_ring - 1) * pc.m_ring      # ALL airborne rings (incl. hub)
        m_main = pc.n_blades * pc.m_blade
        m_exp = sum(er.mass for er in sys.expansion_rotors; init=0.0)

        @test m_air ≈ m_tether + m_rings + m_main + m_exp + m_knuckles rtol=1e-9
        @test m_knuckles > 0.0
    end

    @testset "geometry_fingerprint does not double-count blade mass" begin
        include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
        x = seed_genome(5.0)
        x[10] = 0.6                    # hub + 1 expansion rotor (non-vacuous)
        base = params_daisy()
        result = design_from_vector_v10(
            x, PROFILE_ELLIPTICAL, base; power_W=5000.0, v_rated=11.0
        )
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            result, 1.0, 5.39; base_params=base
        )
        @test length(sys.expansion_rotors) == 1   # non-vacuous guard
        fp = KiteTurbineDynamics.geometry_fingerprint(
            sys, pc, result.design; blade_scale=1.0
        )
        line = first(filter(l -> occursin("total_blade_mass=", l), split(fp, "\n")))
        m = match(r"[-+]?[0-9]*\.?[0-9]+", split(line, "total_blade_mass=")[2])
        total = parse(Float64, m.match)
        # er.mass is the ASSEMBLY total — summing er.mass must NOT multiply
        # by n_blades again (the old bug did er.mass × er.n_blades).
        @test total ≈ sum(er.mass for er in sys.expansion_rotors; init=0.0) atol=0.001
        @test !isapprox(total, sum(er.mass * er.n_blades for er in sys.expansion_rotors); rtol=1e-9)
    end
end

println("\n✓ unified blade-mass law tests complete")
