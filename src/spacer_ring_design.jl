# src/spacer_ring_design.jl
# Unified structural design abstractions for TRPT CFRP spacer rings.
# Unifies circular, elliptical, and airfoil cross-sectional shapes and capacities
# for both sizing optimization sweeps and high-fidelity dynamic FEA simulation.

module SpacerRingDesignModule

using LinearAlgebra

# Force loading SystemParams definition if needed (caller imports it)
# We don't import parameters.jl here to avoid circular inclusion, but we can declare it.
# We will accept any SystemParams-like struct that has the fields:
# trpt_hub_radius, n_rings, n_lines, tether_length.

export BeamProfile, PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL
export CFRPProfile, CircularProfile, EllipticalProfile, AirfoilProfile
export CFRPMaterial, DEFAULT_CFRP
export CFRPTube, CircularTube, EllipticalTube, AirfoilTube
export AbstractEndCondition, FixedFixedEnds, PinPinEnds, effective_length_factor
export StrutProperties, strut_properties, utilisation
export SpacerRingDesign

# ── Beam Profile Types (discrete choice for optimizer) ────────────────────────
@enum BeamProfile PROFILE_CIRCULAR=1 PROFILE_ELLIPTICAL=2 PROFILE_AIRFOIL=3

# ── CFRP Profile Abstractions ─────────────────────────────────────────────────
abstract type CFRPProfile end

struct CircularProfile <: CFRPProfile
    Do       :: Float64  # Outer diameter (m)
    t_over_D :: Float64  # Wall thickness-to-diameter ratio
end

struct EllipticalProfile <: CFRPProfile
    Do           :: Float64  # Major outer axis (m)
    t_over_D     :: Float64  # Wall thickness-to-major-axis ratio
    aspect_ratio :: Float64  # Minor/major axis aspect ratio (b/a)
end

struct AirfoilProfile <: CFRPProfile
    Do           :: Float64  # Chord length (m)
    t_over_D     :: Float64  # Wall thickness-to-chord ratio
    aspect_ratio :: Float64  # Thickness-to-chord ratio (t_max / c)
end

# ── CFRP Material Specification ───────────────────────────────────────────────
struct CFRPMaterial
    E       :: Float64  # Young's modulus (Pa)
    G       :: Float64  # Shear modulus (Pa)
    density :: Float64  # Density (kg/m³)
    σ_yield :: Float64  # Compressive strength limit (Pa)
end

# Core Windswept CFRP constants matching structural_safety.jl & trpt_optimization.jl
const DEFAULT_CFRP = CFRPMaterial(
    70e9,    # E_CFRP = 70 GPa
    5e9,     # G_CFRP = 5 GPa
    1600.0,  # RHO_CFRP = 1600 kg/m³
    600e6    # σ_CFRP_COMPR = 600 MPa
)

# ── CFRPTube Structural Member ────────────────────────────────────────────────
struct CFRPTube{P<:CFRPProfile}
    profile  :: P
    material :: CFRPMaterial
end

# Trivial zero-boilerplate constructor shortcuts
CircularTube(Do::Float64, t_over_D::Float64) = CFRPTube(CircularProfile(Do, t_over_D), DEFAULT_CFRP)
EllipticalTube(Do::Float64, t_over_D::Float64, aspect::Float64) = CFRPTube(EllipticalProfile(Do, t_over_D, aspect), DEFAULT_CFRP)
AirfoilTube(Do::Float64, t_over_D::Float64, aspect::Float64) = CFRPTube(AirfoilProfile(Do, t_over_D, aspect), DEFAULT_CFRP)

# ── End Conditions ────────────────────────────────────────────────────────────
abstract type AbstractEndCondition end
struct FixedFixedEnds <: AbstractEndCondition end
struct PinPinEnds     <: AbstractEndCondition end

effective_length_factor(::FixedFixedEnds) = 0.5  # Rigid knuckles in space frame
effective_length_factor(::PinPinEnds)     = 1.0  # Conservative optimizer proxy

# ── Caching Strut Properties ──────────────────────────────────────────────────
struct StrutProperties
    A      :: Float64  # Cross-sectional area (m²)
    I_min  :: Float64  # Minimum second moment of area (m⁴)
    J      :: Float64  # Torsional constant (m⁴)
    mass   :: Float64  # Unit mass (kg/m)
    P_crit :: Float64  # Euler buckling capacity (N)
    M_el   :: Float64  # Elastic bending capacity (N·m)
end

# Minimum manufacturable wall thickness clamp
const OPT_T_MIN_WALL = 5e-4

"""
    strut_properties(tube::CFRPTube, L::Float64, ends::AbstractEndCondition) -> StrutProperties

Computes and caches physical section properties, unit mass, buckling capacity, and 
elastic bending moment limit for a strut of the given length and end conditions.
"""
function strut_properties(tube::CFRPTube{CircularProfile}, L::Float64, ends::AbstractEndCondition)::StrutProperties
    Do = tube.profile.Do
    t  = max(tube.profile.t_over_D * Do, OPT_T_MIN_WALL)
    Di = max(Do - 2.0 * t, 0.0)
    
    A  = (π / 4.0) * (Do^2 - Di^2)
    I  = (π / 64.0) * (Do^4 - Di^4)
    J  = 2.0 * I
    
    mass   = A * tube.material.density
    K      = effective_length_factor(ends)
    P_crit = (π^2 * tube.material.E * I) / max(K * L, 1e-12)^2
    M_el   = (tube.material.σ_yield * I) / (Do / 2.0)
    
    return StrutProperties(A, I, J, mass, P_crit, M_el)
end

function strut_properties(tube::CFRPTube{EllipticalProfile}, L::Float64, ends::AbstractEndCondition)::StrutProperties
    Do = tube.profile.Do
    t  = max(tube.profile.t_over_D * Do, OPT_T_MIN_WALL)
    
    a  = Do / 2.0
    b  = max(tube.profile.aspect_ratio, 0.1) * a
    ai = max(a - t, 0.0)
    bi = max(b - t, 0.0)
    
    A  = π * (a * b - ai * bi)
    
    # Second moments of area about major and minor axes
    I_minor = (π / 4.0) * (a * b^3 - ai * bi^3)  # bending about major (weaker, out-of-plane)
    I_major = (π / 4.0) * (a^3 * b - ai^3 * bi)  # bending about minor (stronger, in-plane)
    I_min   = min(I_minor, I_major)
    
    # Torsional constant J using thin-wall Bredt's approximation
    perim = π * (a + b) * (1.0 + 3.0 * ((a - b) / (a + b))^2 / (10.0 + sqrt(4.0 - 3.0 * ((a - b) / (a + b))^2)))
    J     = 4.0 * (π * a * b)^2 * t / max(perim, 1e-9)
    
    mass   = A * tube.material.density
    K      = effective_length_factor(ends)
    P_crit = (π^2 * tube.material.E * I_min) / max(K * L, 1e-12)^2
    M_el   = (tube.material.σ_yield * I_min) / (Do / 2.0)
    
    return StrutProperties(A, I_min, J, mass, P_crit, M_el)
end

function strut_properties(tube::CFRPTube{AirfoilProfile}, L::Float64, ends::AbstractEndCondition)::StrutProperties
    c     = tube.profile.Do  # chord
    t_c   = max(tube.profile.aspect_ratio, 0.05)
    t_max = t_c * c
    t_w   = max(tube.profile.t_over_D * c, OPT_T_MIN_WALL)
    
    # Thin-walled aerodynamic shell parameters (NACA-like symmetric airfoil shell)
    perim  = 2.03 * c * (1.0 + 0.25 * t_c^2)
    A      = perim * t_w
    I_flap = 0.073 * c * t_max^2 * t_w
    I_min  = I_flap
    
    # Enclosed area for Bredt's thin-wall torsion constant
    A_encl = 0.685 * c * t_max
    J      = 4.0 * A_encl^2 * t_w / max(perim, 1e-9)
    
    mass   = A * tube.material.density
    K      = effective_length_factor(ends)
    P_crit = (π^2 * tube.material.E * I_min) / max(K * L, 1e-12)^2
    M_el   = (tube.material.σ_yield * I_min) / (c / 2.0)
    
    return StrutProperties(A, I_min, J, mass, P_crit, M_el)
end

# ── Stress Utilisation ────────────────────────────────────────────────────────
"""
    utilisation(tube::CFRPTube, props::StrutProperties, N::Float64, M_ip::Float64, M_oop::Float64) -> Float64

Calculates combined axial compression and biaxial bending stress utilisation index.
Clamps tensile axial loads (N < 0) to 0.0 since buckling is purely a compressive failure.
"""
function utilisation(tube::CFRPTube, props::StrutProperties, N::Float64, M_ip::Float64, M_oop::Float64)::Float64
    N_term = max(N, 0.0) / max(props.P_crit, 1e-9)
    M_term = sqrt(M_ip^2 + M_oop^2) / max(props.M_el, 1e-9)
    return N_term + M_term
end

# ── Spacer Ring Design Struct ─────────────────────────────────────────────────
"""
    SpacerRingDesign

Full airframe structural description, matching optimizer configuration.
Exposes core E, density, σ_yield to allow custom materials.
"""
struct SpacerRingDesign
    profile         :: BeamProfile
    Do_top          :: Float64
    t_over_D        :: Float64
    aspect_ratio    :: Float64
    Do_scale_exp    :: Float64
    r_hub           :: Float64
    taper_ratio     :: Float64
    n_rings         :: Int
    n_lines         :: Int
    tether_length   :: Float64
    knuckle_mass    :: Float64
    
    # Core Material Properties
    E               :: Float64
    density         :: Float64
    σ_yield         :: Float64
end

# Trivial default constructor from SystemParams
function SpacerRingDesign(p)
    # Default circular design matching baseline
    Do_top = 0.01396 * sqrt(p.trpt_hub_radius)
    r_bot_guess = 0.48 * p.trpt_hub_radius
    taper_ratio = r_bot_guess / p.trpt_hub_radius
    return SpacerRingDesign(
        PROFILE_CIRCULAR,
        Do_top,
        0.05,                  # baseline t/D
        1.0,                   # aspect ratio unused for circular
        0.5,                   # Do_scale_exp
        p.trpt_hub_radius,
        taper_ratio,
        p.n_rings,
        p.n_lines,
        p.tether_length,
        0.050,                 # knuckle_mass_kg = 50 g
        70e9,                  # E = 70 GPa
        1600.0,                # density = 1600 kg/m³
        600e6                  # σ_yield = 600 MPa
    )
end

end  # module SpacerRingDesignModule
