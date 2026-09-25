# test/test_trpt_twist_limit.jl — the over-twist authority, from Tulloch (2021)
#
# The repo derived its over-twist angle from a fixed-gap kinematic and called the result
# "Tulloch's δα*". It is not his. His limit is (4.34), and for a tether shorter than the
# sum of the ring radii no limit exists at all: the lines cannot reach the axis, so they
# cannot cross (§5.3.1, §3.1.3).
#
# These tests pin the authority to the thesis and to closed forms verified before writing.
# They do not touch a call site. WP1, 2026-09-25.
using Test
using KiteTurbineDynamics

@testset "trpt_twist_limit — Tulloch (4.34)" begin
    # Tulloch's operating curve: the axial force is held, so the rings contract with the
    # twist.  τ(δ) = r_a·r_b·sin(δ) / L(δ),  L(δ)² = l_t² − r_a² − r_b² + 2·r_a·r_b·cos(δ)
    tincl(r_a, r_b, l_t, d) =
        r_a * r_b * sin(d) / sqrt(max(l_t^2 - r_a^2 - r_b^2 + 2 * r_a * r_b * cos(d), 0.0))

    # ── A. a limit exists when the tether can reach the axis ──────────────────
    # disc ≥ 0, equivalently l_t ≥ r_a + r_b.
    for (r_a, r_b, l_t, want_deg) in (
        (0.575, 0.575, 1.60, 100.36),   # live campaign seed, segments 9 and 10
        (1.175, 1.175, 3.271, 100.36),  # same ratio, larger ring
        (0.400, 0.400, 4.00, 90.58),    # large ϕ → the 90° asymptote
        (0.400, 0.400, 1.00, 104.48),   # Tulloch Fig 5.25 (R = 0.4 m, l_t = 1 m)
    )
        lim = trpt_twist_limit(r_a, r_b, l_t)
        @test lim.has_limit
        @test rad2deg(lim.dcrit) ≈ want_deg atol = 0.05
        @test 0.0 < lim.dcrit < π
    end

    # ── B. δcrit is the MAXIMUM of the operating curve ────────────────────────
    # This is the assertion the old fixed-gap formula fails: its angle is 20° low here.
    for (r_a, r_b, l_t) in
        ((0.575, 0.575, 1.60), (0.400, 0.400, 1.00), (0.400, 0.400, 4.00))
        lim = trpt_twist_limit(r_a, r_b, l_t)
        @test tincl(r_a, r_b, l_t, lim.dcrit) >
            tincl(r_a, r_b, l_t, lim.dcrit - deg2rad(3.0))
        @test tincl(r_a, r_b, l_t, lim.dcrit) >
            tincl(r_a, r_b, l_t, lim.dcrit + deg2rad(3.0))
    end

    # ── C. l_t = r_a + r_b is the boundary, and there the limit is 180° ───────
    lim2 = trpt_twist_limit(0.575, 0.575, 1.15)
    @test lim2.has_limit
    @test rad2deg(lim2.dcrit) ≈ 180.0 atol = 0.05
    # just inside the boundary there is no limit at all
    @test !trpt_twist_limit(0.575, 0.575, 1.1499).has_limit

    # ── D. a tether shorter than the sum of the radii has NO limit ────────────
    # Ten of the twelve segments on the live campaign seed sit here.
    for (r_a, r_b, l_t, want_touch_deg) in (
        (0.575, 0.575, 0.886, 100.79),   # seed segments 1–8
        (2.400, 2.400, 3.600, 97.18),    # seed segments 11–12
    )
        lim = trpt_twist_limit(r_a, r_b, l_t)
        @test !lim.has_limit
        @test lim.disc < 0
        @test isnan(lim.dcrit)
        @test isinf(trpt_torque_capacity_axial(lim, 1000.0))
        @test isinf(trpt_torque_capacity_lines(lim, 1000.0))
        # the geometry's own end stop is the rings meeting, not a crossing
        @test rad2deg(lim.d_touch) ≈ want_touch_deg atol = 0.05
        # equal radii identity: acos(1 − l_t²/2r²) == 2·asin(l_t/2r)
        @test lim.d_touch ≈ 2 * asin(l_t / (2 * r_a))
    end

    # ── E. capacity is the law evaluated at the limit, in both conventions ────
    lim = trpt_twist_limit(0.575, 0.575, 1.60)
    @test trpt_torque_capacity_axial(lim, 1000.0) ≈
        1000.0 * lim.r_a * lim.r_b * lim.sin_dcrit / lim.l_ax_dcrit
    @test trpt_torque_capacity_lines(lim, 1000.0) ≈
        1000.0 * lim.r_a * lim.r_b * lim.sin_dcrit / lim.l_t
    @test trpt_torque_capacity_axial(lim, 1000.0) ≈ 243.79 atol = 0.05
    @test lim.l_ax_dcrit ≈ 1.3340 atol = 1e-3      # the rings contract from 1.60 m
    # Tulloch Fig 5.25: 0.2 N·m per newton of axial force, so 100 N·m at his 500 N
    limfig = trpt_twist_limit(0.400, 0.400, 1.000)
    @test trpt_torque_capacity_axial(limfig, 1.0) ≈ 0.2000 atol = 1e-4
    @test trpt_torque_capacity_axial(limfig, 500.0) ≈ 100.0 atol = 0.05
    # monotone: more tether length for one ring radius is a lower limit angle
    let prev = π
        for l_t in (1.15, 1.30, 1.60, 2.40, 3.20, 8.00)
            d = trpt_twist_limit(0.575, 0.575, l_t).dcrit
            @test d < prev
            prev = d
        end
    end

    # ── F. bad geometry fails loudly, it does not return a number ─────────────
    @test_throws ArgumentError trpt_twist_limit(0.0, 0.575, 1.60)
    @test_throws ArgumentError trpt_twist_limit(0.575, -0.1, 1.60)
    @test_throws ArgumentError trpt_twist_limit(0.575, 0.575, 0.0)
    # a tether shorter than the radius difference cannot span its own attachment points
    @test_throws ArgumentError trpt_twist_limit(2.000, 0.575, 0.500)
end
