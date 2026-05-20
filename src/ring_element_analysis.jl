# src/ring_element_analysis.jl
# Per-beam-element 3D space-frame structural analysis for TRPT ring polygons.
# Replaces the whole-polygon uniform-load assumption in structural_safety.jl.
#
# Each intermediate ring is a closed n-gon of CFRP beam elements with rigid
# knuckle joints (fixed-fixed ends, effective length K=0.5).  Tether forces at
# each vertex are resolved from the ODE state; a 6n×6n stiffness system is
# assembled and solved; per-beam N, M_ip, M_oop, T are recovered and combined
# into a single interaction utilisation ratio.

using LinearAlgebra

"""
    BeamResult

Structural result for one beam element (one polygon side) of a ring frame.
`utilisation = N/N_crit + √(M_ip²+M_oop²)/M_el`; failure when ≥ 1.
"""
struct BeamResult
    N           :: Float64   # axial compression (+ve = compressive, N)
    M_ip        :: Float64   # max in-plane bending moment at either end (N·m)
    M_oop       :: Float64   # max OOP bending moment at either end (N·m)
    T_tor       :: Float64   # torsion (N·m) — tracked but not in interaction formula
    N_crit      :: Float64   # fixed-fixed critical buckling load (N)
    M_el        :: Float64   # elastic bending moment capacity (N·m)
    utilisation :: Float64   # combined interaction ratio (1.0 = limit state)
    fos         :: Float64   # 1 / utilisation
    exceeded    :: Bool
end

"""
    RingElementFrame

Per-beam structural results for one intermediate ring.
`max_util` is the worst-beam scalar used by the HUD and warning flags.
"""
struct RingElementFrame
    ring_id  :: Int
    radius   :: Float64
    beams    :: Vector{BeamResult}   # length = n_lines
    max_util :: Float64              # maximum utilisation across all beams
end
