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

    @testset "expansion blade mass — volume law, measured anchor" begin
        # 6-blade Daisy assembly at λ=1: 6 × 420 g = 2.52 kg (Rod 2026-08-22)
        @test expansion_blade_mass(0.7, 1.0, 6) ≈ 6 * 0.420 atol=1e-12
        # no n_blades → legacy 3-blade assembly convention
        @test expansion_blade_mass(0.7, 1.0) ≈ 3 * 0.420 atol=1e-12
        # volume law: λ=0.5 → ⅛ of λ=1 mass
        @test expansion_blade_mass(0.7, 0.5, 6) ≈ 6 * 0.420 * 0.5^3 atol=1e-12
        # tip radius does NOT enter the law (similarity scaling through λ)
        @test expansion_blade_mass(2.37, 0.85, 3) ≈ 3 * 0.420 * 0.85^3 atol=1e-12
        # the dead CFRP constants must be gone (0.37 kg at tip 0.7, λ=1)
        @test !isapprox(expansion_blade_mass(0.7, 1.0, 3), 0.37; atol=1e-9)
    end

    @testset "build_system_from_v10 — main rotor scales λ³" begin
        include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
        x = seed_genome(5.0)
        x[10] = 0.6                    # 2 rotors: hub + 1 intermediate expansion
        x[13] = 0.5; x[14] = 0.5      # blade_scale_top/bottom → λ_eff = 0.5
        base = params_daisy()
        result = design_from_vector_v10(
            x, PROFILE_ELLIPTICAL, base; power_W=5000.0, v_rated=11.0
        )
        λ_eff = result.rotors[1].blade_scale
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            result, 1.0, 5.39; base_params=base
        )
        # per-blade mass = rung base × λ³ (volume), NOT λ² (area)
        @test pc.m_blade ≈ base.m_blade * λ_eff^3 rtol=1e-9
        @test !isapprox(pc.m_blade, base.m_blade * λ_eff^2; rtol=1e-9)

        # HUB EXCLUSION (2026-08-22): the hub rotor (ring_idx == n_rings) is
        # the MAIN rotor — no expansion entry, no double-modelled annulus,
        # no double-counted mass.  Only INTERMEDIATE rotors become expansion
        # entries, one per decoded rotor with ring_idx != n_rings.
        non_hub = filter(r -> r.ring_idx != result.n_rings, result.rotors)
        @test length(sys.expansion_rotors) == length(non_hub)
        hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
        @test all(er.ring_idx != hub_ri for er in sys.expansion_rotors)
        for (er, rotor) in zip(sys.expansion_rotors, non_hub)
            λ_er = rotor.blade_scale
            @test er.mass ≈ er.n_blades * base.m_blade * λ_er^3 rtol=1e-9
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
        @test total ≈ sum(er.mass for er in sys.expansion_rotors; init=0.0) rtol=1e-9
        @test !isapprox(total, sum(er.mass * er.n_blades for er in sys.expansion_rotors); rtol=1e-9)
    end
end

println("\n✓ unified blade-mass law tests complete")
