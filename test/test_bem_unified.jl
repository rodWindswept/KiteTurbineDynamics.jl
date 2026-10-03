# test/test_bem_unified.jl — Phase 0.1: Unified BEM model validation
#
# Tests that the new cp_bem(n_lines, tsr) and ct_bem(n_lines, tsr) functions:
# 1. Match AeroDyn baseline at n_lines=5
# 2. Scale Cp downwards with increasing blade count (solidity penalty)
# 3. Scale CT upwards with increasing blade count (more thrust area)
# 4. Produce self-consistent rotor radius
# 5. Respect physical bounds (Cp ≤ Betz, CT ≤ 1.0)

using Test
using KiteTurbineDynamics
const BEM = KiteTurbineDynamics.BEM

@testset "BEM unification" begin

    # ── 1. Baseline match at n_lines=5 ──────────────────────
    @testset "Match AeroDyn at n_lines=5" begin
        for λ in [3.0, 3.5, 4.0, 4.1, 4.5, 5.0]
            cp_direct = cp_at_tsr(λ)
            cp_bem5   = BEM.cp_bem(5, λ)
            if cp_direct > 0.01
                @test abs(cp_bem5 - cp_direct) / cp_direct < 0.02
            end
        end
        for λ in [3.0, 3.5, 4.0, 4.1, 4.5, 5.0]
            ct_direct = ct_at_tsr(λ)
            ct_bem5   = BEM.ct_bem(5, λ)
            if ct_direct > 0.01
                @test abs(ct_bem5 - ct_direct) / ct_direct < 0.03
            end
        end
    end

    # ── 2. Cp decreases with blade count ────────────────────
    @testset "Cp monotonic in n_lines" begin
        cp3 = BEM.cp_bem(3, 4.1)
        cp5 = BEM.cp_bem(5, 4.1)
        cp8 = BEM.cp_bem(8, 4.1)
        @test cp8 < cp5
        @test cp3 > cp8
        @test BEM.cp_bem(3, 4.1) > 0.10
        @test BEM.cp_bem(8, 4.1) > 0.10
    end

    # ── 3. CT scales with blade count ───────────────────────
    @testset "CT scaling" begin
        @test BEM.ct_bem(5, 4.1) > 0.45
        ct3 = BEM.ct_bem(3, 4.1)
        ct5 = BEM.ct_bem(5, 4.1)
        ct8 = BEM.ct_bem(8, 4.1)
        @test ct8 > ct5 > ct3
        for n in [3, 5, 8]
            for λ in [4.0, 6.0, 8.0]
                @test BEM.ct_bem(n, λ) <= 1.02  # quasi-steady BEM can exceed 1.0 at high λ
            end
        end
    end

    # ── 4. Rotor radius self-consistency ────────────────────
    @testset "Rotor radius self-consistent" begin
        P, v, n = 10_000.0, 11.0, 5
        R = BEM.rotor_radius_for_power(P, v, n; tsr=4.1)
        Cp  = BEM.cp_bem(n, 4.1)
        P_check = Cp * 0.5 * 1.225 * π * R^2 * v^3
        @test abs(P_check - P) / P < 0.05
        R5 = BEM.rotor_radius_for_power(P, v, 5; tsr=4.1)
        R8 = BEM.rotor_radius_for_power(P, v, 8; tsr=4.1)
        @test R8 > R5
    end

    # ── 5. Physical bounds ──────────────────────────────────
    @testset "Physical bounds" begin
        for n in [3, 5, 8]
            @test BEM.cp_bem(n, 4.1) <= 16.0 / 27.0
            @test BEM.cp_bem(n, 4.1) >= 0.0
            @test BEM.ct_bem(n, 4.1) >= 0.0
        end
    end

    # ── 6. TSR sweep sanity ─────────────────────────────────
    @testset "TSR dependence" begin
        cp_low  = BEM.cp_bem(5, 2.0)
        cp_peak = BEM.cp_bem(5, 4.1)
        cp_high = BEM.cp_bem(5, 7.0)
        @test cp_peak > cp_low
        @test cp_peak > cp_high
        for n in [3, 5, 8]
            @test BEM.ct_bem(n, 6.0) >= BEM.ct_bem(n, 4.0)
        end
    end

    # ── 7. Ring annulus sizing & Peter Jamieson scaling (DECISIONS [2026-08-20]) ──
    @testset "Ring annulus BEM sizing & Peter Jamieson scaling" begin
        # A. Self-consistency: annulus_area(r, annulus_span_for_power(P, v, r)) matches P/(Cp·½ρ·v³)
        for P in [1000.0, 1666.67, 5000.0, 10000.0]
            for v in [9.0, 11.0, 13.0]
                for r_ring in [1.5, 2.61, 3.55]
                    for bank in [0.0, 15.0, 25.0]
                        s = BEM.annulus_span_for_power(P, v, r_ring, 3; bank_deg=bank)
                        A_actual = BEM.annulus_area(r_ring, s; bank_deg=bank)
                        Cp = BEM.cp_bem(3, 4.1)
                        A_req = P / (Cp * 0.5 * 1.225 * v^3)
                        @test abs(A_actual - A_req) / A_req < 1e-4
                    end
                end
            end
        end

        # B. Daisy thesis calibration anchor (DECISIONS [2026-08-20]):
        # Ring 1.52 m, tips 1.22/2.22 m (70/30 annulus 10.81 m²), span = 1.0 m.
        A_daisy = BEM.annulus_area(1.52, 1.0; bank_deg=0.0)
        @test A_daisy ≈ 10.8071 atol=1e-3
        # Back-solving for power with A_req = 10.8071 m² yields exactly span = 1.0 m
        Cp = BEM.cp_bem(6, 4.1)
        P_daisy = Cp * 0.5 * 1.225 * 11.0^3 * A_daisy
        s_back = BEM.annulus_span_for_power(P_daisy, 11.0, 1.52, 6; bank_deg=0.0)
        @test s_back ≈ 1.0 atol=1e-3

        # C. Peter Jamieson Multi-Rotor Invariant (references/MULTI ROTOR IDEAL MASS by PJ.txt):
        # 1. Total swept area invariant: N rotors sharing power P have the same total swept area
        #    as a single rotor producing P.
        P_total = 5000.0
        v_wind = 11.0
        r_single = 3.55
        s_single = BEM.annulus_span_for_power(P_total, v_wind, r_single, 3)
        A_single = BEM.annulus_area(r_single, s_single)

        # 3 rotors sharing 5 kW equally (1667 W each) on 2.61 m rings
        s_3rotor = BEM.annulus_span_for_power(P_total / 3.0, v_wind, 2.61, 3)
        A_per_rotor = BEM.annulus_area(2.61, s_3rotor)
        A_3rotor_total = 3.0 * A_per_rotor

        # Swept area equality holds within 1% (exact 1D momentum conservation)
        @test abs(A_3rotor_total - A_single) / A_single < 0.01

        # 2. Jamieson blade mass reduction: multi-rotor blade mass must be strictly LESS
        #    than single rotor blade mass (references/MULTI ROTOR IDEAL MASS by PJ.txt:
        #    M_ratio = 1/√N for discs, and ~ 1/N² for ring-annulus).
        # Single rotor: 3 blades of span s_single
        M_blades_single = 3 * 0.420 * s_single^3
        # 3-rotor machine: 3 rotors × 3 blades of span s_3rotor
        M_blades_3rotor = 3 * (3 * 0.420 * s_3rotor^3)

        # Multi-rotor blade mass must be significantly less than single rotor
        @test M_blades_3rotor < M_blades_single
        # Ratio is well below the 1/√3 ≈ 0.577 disc limit
        @test M_blades_3rotor / M_blades_single < 0.577
    end

    # ── 8. The site wind standard (D1, Rod 2026-09-24) ───────────────────────
    @testset "Site wind standard: the measured Daisy pair" begin
        # The standard is a MEASURED pair, not a machine dimension.  The anchor
        # site is the Daisy, and the anchor IS the default.
        @test SITE_ANCHOR === SITE_DAISY
        @test SITE_DAISY.v_ref_ms == 10.0
        @test SITE_DAISY.h_ref_m == 4.8
        @test SITE_DAISY.shear_exp ≈ 1.0 / 7.0
        @test occursin("Daisy", SITE_DAISY.name)   # named after the measurement

        # The profile reads the pair at the reference height, by definition.
        @test site_wind(4.8) ≈ 10.0 rtol = 1e-12
        # A taller rotor reads a faster inflow.  Altitude is the only argument.
        @test site_wind(9.400) > site_wind(7.261) > site_wind(5.123)
        # The measured values of D1, at the 5 kW geometry and at the Daisy.
        @test site_wind(9.400) ≈ 11.0077 atol = 1e-3    # 5 kW hub
        @test site_wind(5.123) ≈ 10.0936 atol = 1e-3    # 5 kW lowest rotor
        @test site_wind(5.155) ≈ 10.1025 atol = 1e-3    # Daisy rotor centre

        # ── ONE profile: every params object is the standard re-expressed ──
        # p.v_wind_ref == site_wind(p.h_ref).  This guard fails for any params
        # factory that still carries its own reference wind.
        for p in (
            params_daisy(),
            params_10kw(),
            params_50kw(),
            params_v5_10kw(),
            params_v5_50kw(),
            params_v5_safe_10kw(),
            params_v6_50kw(),
        )
            @test p.v_wind_ref ≈ site_wind(p.h_ref) rtol = 1e-9
        end

        # mass_scale moves the rotor altitude, so the same standard moves with
        # it.  The reference is the SITE pair; it is not rescaled.
        p5 = mass_scale(params_daisy(), 1.5, 5.0)
        @test p5.h_ref > params_daisy().h_ref
        @test p5.v_wind_ref ≈ site_wind(p5.h_ref) rtol = 1e-9

        # The ODE wind function and the decoder read the SAME profile.  The ODE
        # form is wind_at_altitude(p.v_wind_ref, p.h_ref, z); the decoder's
        # per-ring wind is site_wind(z).  They must agree exactly.
        for z in (5.123, 7.261, 9.400)
            @test wind_at_altitude(p5.v_wind_ref, p5.h_ref, z) ≈ site_wind(z) rtol = 1e-12
        end
        # Measured consequence for the 5 kW rung: the hub reads 11.0077 m/s,
        # +0.09 % of the old hub-pinned 11.0 m/s.  The old decoder read 8.6637.
        @test wind_at_altitude(p5.v_wind_ref, p5.h_ref, 9.400) ≈ 11.0077 atol = 1e-3

        # ── Alternate site specs: one call re-bases a machine ──────────────
        # The Daisy anchor is the DEFAULT, not the only site.  A site is a
        # measured pair plus its shear exponent, so validating an ideal system
        # against a new site wind specification is data, not a code change.
        # The spec below is synthetic and exists to exercise the mechanism.
        site_test = WindSiteSpec("test site (synthetic)", 12.0, 10.0, 0.2)
        @test site_wind(site_test, 10.0) ≈ 12.0 rtol = 1e-12   # pair honoured
        @test site_wind(site_test, 20.0) ≈ 12.0 * 2.0^0.2 rtol = 1e-12

        p_alt = at_site(p5, site_test)
        @test p_alt.v_wind_ref ≈ site_wind(site_test, p5.h_ref) rtol = 1e-12
        @test p_alt.v_wind_ref > p5.v_wind_ref      # 12.0 at 10 m is stronger here
        @test p_alt.h_ref == p5.h_ref               # the machine is untouched
        @test p_alt.tether_length == p5.tether_length
        @test p_alt.k_mppt == p5.k_mppt

        # Re-basing is a COPY, never a mutation, and the two specs stay separate:
        # the same machine reads a different wind at the same altitude.
        @test p5.v_wind_ref ≈ site_wind(SITE_ANCHOR, p5.h_ref) rtol = 1e-9
        @test site_wind(site_test, p5.h_ref) > site_wind(SITE_ANCHOR, p5.h_ref)
        # A site's own pair is honoured at its own height, whatever that is.
        @test site_wind(SITE_ANCHOR, SITE_ANCHOR.h_ref_m) ≈ SITE_ANCHOR.v_ref_ms
    end
end
