# src/wind_profile.jl
# Wind speed as a function of altitude (Hellmann power law) and
# time-varying wind model constructors for simulation scenarios.

using Random

# ── The site wind standard (D1, Rod 2026-09-24) ────────────────────────────────
#
# The rated wind is the MEASURED Daisy pair: 10.0 m/s at 4.8 m, the anemometer
# height on the Daisy mast.  It is neither the 10 m meteorological standard nor
# the rotor hub altitude.  The Daisy rating reads ">1.5 kW at 10 m/s", and the
# anemometer sat on a 4.8 m mast, near the rotor centre.
#
# The 5 kW system uses that same wind through this same shear model.  Every
# machine is sited at ONE profile, so a taller rotor reads a faster inflow, and
# length is a power axis.
#
# `p.v_wind_ref` and `p.h_ref` carry the same profile re-expressed at the
# machine's own rotor altitude: `p.v_wind_ref == site_wind(p.h_ref)`.  That
# identity is what lets the ODE, the decoder and the steady estimates read one
# profile.  `test/test_bem_unified.jl` pins it for every params factory.
#
# A SITE is a measured pair plus the shear exponent that carries it to other
# heights.  The Daisy anchor is the DEFAULT, not the only site: one call re-bases
# a machine on another site, so validating an ideal system against a new site
# wind specification is data, not a code change.
#
#     p_alt = at_site(p, WindSiteSpec("site name", v, h, alpha))
#
# Recorded: `DECISIONS.md` [2026-09-24], `docs/plans/2026-09-24-phase5-multirotor-sizing.md`.

"""
    WindSiteSpec(name, v_ref_ms, h_ref_m, shear_exp)

A named MEASURED wind site: the reference pair (speed at a height) plus the
Hellmann shear exponent that carries it to other heights.

Name every spec after its measurement, never after its purpose.  The pair and the
exponent are both inputs, so neither belongs in a call site as a bare literal.
"""
struct WindSiteSpec
    name::String
    v_ref_ms::Float64
    h_ref_m::Float64
    shear_exp::Float64
end

# The ANCHOR site: the measured Daisy pair.  ">1.5 kW at 10 m/s", with the
# anemometer on the 4.8 m mast, near the rotor centre.
const SITE_DAISY = WindSiteSpec("Tulloch, Daisy (measured)", 10.0, 4.8, 1.0 / 7.0)

# Every params object sits on the anchor site unless a study re-bases it with
# `at_site`.  The anchor is named here, and only here.
const SITE_ANCHOR = SITE_DAISY

"""
    site_wind([site], h) -> Float64

The wind speed at altitude `h` (m above ground) for a named site — the anchor
site when none is given.

The anchor pair is the MEASURED Daisy rating: 10.0 m/s at 4.8 m.  A machine with
a 9.4 m hub therefore reads 11.0077 m/s, and a 5.155 m rotor centre reads
10.1025 m/s.

Returns 0.0 for any non-positive altitude, by `wind_at_altitude`.
"""
site_wind(h::Real) = site_wind(SITE_ANCHOR, h)
function site_wind(site::WindSiteSpec, h::Real)
    return wind_at_altitude(
        site.v_ref_ms, site.h_ref_m, Float64(h); hellmann_exponent=site.shear_exp
    )
end

"""
    at_site(p, site) -> SystemParams

Re-base a machine on a named site's wind.

Only the reference wind moves: the geometry, the mass and the control gain stay.
`p.v_wind_ref` is the wind at the ROTOR and `p.h_ref` is that rotor's altitude,
so this re-expresses the site standard at the same altitude — it is not a change
of scale.  The invariant `v_wind_ref == site_wind(site, h_ref)` holds on the
result, which is what makes a two-site comparison one call per site.
"""
at_site(p::SystemParams, site::WindSiteSpec) =
    override_params(p; v_wind_ref=site_wind(site, p.h_ref))

"""
    site_shear(h_ref, h) -> Float64

The site-standard shear shape: the factor that lifts a reference speed at
`h_ref` to altitude `h`, read from the ONE site spec (`SITE_ANCHOR.shear_exp`).

This is the single place the runtime shear exponent is written down.  Callers
supply their own reference speed and altitude:

    v(z) = v_ref * site_shear(h_ref, z)

It retires the ad-hoc `(z / h_ref)^(1/7)` literals that used to sit in the
runtime wind closures (`sim_runner.jl`, `visualization.jl`,
`control_map_hunt.jl`).  Those agreed with the anchor site by coincidence and
would have silently kept flying the anchor exponent after `at_site` re-bases a
machine on a different site — a second convention for one quantity, which is
the Defect-D class.  A literal cannot move with the spec; this can.

`test/test_wind_authority.jl` pins both halves: the shape moves with the spec,
and no runtime wind closure hand-writes the exponent.
"""
site_shear(h_ref::Real, h::Real) = wind_at_altitude(
    1.0, Float64(h_ref), Float64(h); hellmann_exponent=SITE_ANCHOR.shear_exp
)

"""
    wind_at_altitude(v_ref, h_ref, h; hellmann_exponent = 1/7) -> Float64

Return the wind speed at altitude `h` using the Hellmann (power-law) wind profile:

    V(h) = V_ref × (h / h_ref)^α

where α is the Hellmann exponent (default 1/7, appropriate for open flat terrain).
Returns 0.0 for any non-positive altitude.

# Arguments
- `v_ref`             : Reference wind speed (m/s) measured at `h_ref`
- `h_ref`             : Reference altitude (m)
- `h`                 : Target altitude (m)
- `hellmann_exponent` : Terrain-dependent shear exponent α (dimensionless); default 1/7
"""
function wind_at_altitude(
    v_ref::Float64, h_ref::Float64, h::Float64; hellmann_exponent::Float64=1.0 / 7.0
)::Float64
    if h <= 0.0
        return 0.0
    end
    return v_ref * (h / h_ref)^hellmann_exponent
end

"""
    hub_altitude(tether_length, elevation_angle) -> Float64

Return the vertical altitude of the airborne rotor hub (m), computed from the
TRPT tether geometry as:

    h_hub = tether_length × sin(elevation_angle)

# Arguments
- `tether_length`   : Total TRPT tether length L₀ (m)
- `elevation_angle` : Shaft elevation angle β above horizontal (rad)
"""
function hub_altitude(tether_length::Float64, elevation_angle::Float64)::Float64
    return tether_length * sin(elevation_angle)
end

# ── Wind model constructors ────────────────────────────────────────────────────
# Each returns a closure  f(t::Float64)::Float64  giving v_ref (m/s at reference
# height p.h_ref). Pass the closure as `wind_fn` to trpt_ode_wind!.

"""
    steady_wind(v_ref) -> Function

Return a constant wind function: `v(t) = v_ref` for all t.
"""
steady_wind(v_ref::Float64) = (t::Float64) -> v_ref

"""
    wind_ramp(v_start, v_end, t_ramp_start, t_ramp_end) -> Function

Return a wind function that linearly ramps from `v_start` to `v_end` between
`t_ramp_start` and `t_ramp_end` (s). Constant outside that window.
"""
function wind_ramp(
    v_start::Float64, v_end::Float64, t_ramp_start::Float64, t_ramp_end::Float64
)
    function f(t::Float64)::Float64
        t <= t_ramp_start && return v_start
        t >= t_ramp_end && return v_end
        return v_start +
               (v_end - v_start) * (t - t_ramp_start) / (t_ramp_end - t_ramp_start)
    end
    return f
end

"""
    gust_event(v_base, v_gust, t_start, t_end) -> Function

Return a wind function with a raised-cosine (Hann-window) gust from `t_start`
to `t_end`. Peak speed is `v_gust`; baseline speed is `v_base` outside the
gust window. Smooth (C¹ continuous) at the gust edges.
"""
function gust_event(v_base::Float64, v_gust::Float64, t_start::Float64, t_end::Float64)
    function f(t::Float64)::Float64
        (t < t_start || t > t_end) && return v_base
        frac = (t - t_start) / (t_end - t_start)
        return v_base + (v_gust - v_base) * 0.5 * (1.0 - cos(2π * frac))
    end
    return f
end

"""
    turbulent_wind(v_mean, turbulence_intensity, t_max;
                   dt = 1/30, rng_seed = 42) -> Function

Return a wind function based on a first-order Markov (AR(1)) turbulence model.

- `turbulence_intensity`: σ/μ, e.g. 0.15 for 15 % TI (typical onshore Class A).
- Integral length scale: L = 340 m (IEC 61400-1 Class A at 30 m hub).
- Pre-computes a time series on `[0, t_max]` at step `dt`, then interpolates
  linearly for any query time.
- Wind speed is clamped to ≥ 0.5 m/s to prevent negative values.
"""
function turbulent_wind(
    v_mean::Float64,
    turbulence_intensity::Float64,
    t_max::Float64;
    dt::Float64=1.0 / 30.0,
    rng_seed::Int=42,
)
    σ = turbulence_intensity * v_mean
    L = 340.0               # IEC 61400-1 integral length scale (m)
    T_L = L / v_mean          # integral time scale (s)
    φ = exp(-dt / T_L)      # AR(1) autocorrelation coefficient

    rng = MersenneTwister(rng_seed)
    n = round(Int, t_max / dt) + 2
    ts = [(i - 1) * dt for i in 1:n]
    vs = zeros(Float64, n)
    vs[1] = v_mean
    w = 0.0
    for i in 2:n
        w = φ * w + sqrt(1.0 - φ^2) * randn(rng)
        vs[i] = max(0.5, v_mean + σ * w)
    end

    function interp(t::Float64)::Float64
        i = searchsortedfirst(ts, t)
        i == 1 && return vs[1]
        i > length(ts) && return vs[end]
        frac = (t - ts[i - 1]) / (ts[i] - ts[i - 1])
        return vs[i - 1] + frac * (vs[i] - vs[i - 1])
    end
    return interp
end
