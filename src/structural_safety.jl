# src/structural_safety.jl
# Ring polygon-frame compression and Euler column buckling FoS — post-process only, no ODE coupling.
#
# Failure mode: Euler column buckling of each flat polygon segment (pin-pin ends).
# This governs a pentagon (or any regular polygon) frame, NOT ring hoop Euler buckling.
# Ring hoop Euler (P = 3EI/R²) applies to a continuous circular ring and overestimates
# P_crit for a polygon frame by 5–10× at TRPT geometry.  See TRPT_Ring_Scalability_Report.docx.

const TETHER_SWL = 3500.0   # N — Dyneema 3 mm safe working load

# ── CFRP tube structural constants ────────────────────────────────────────────
# Ring frames are built from CFRP hollow tubes; see TRPT_Ring_Scalability_Report §3.
const E_CFRP = 70e9    # Pa  — conservative isotropic CFRP Young's modulus
const RHO_CFRP = 1600.0  # kg/m³ — CFRP density
const T_OVER_D = 0.05    # t/D wall ratio — aerodynamic and structural optimum
const T_MIN_WALL = 5e-4    # m   — 0.5 mm minimum manufacturable wall thickness
const FOS_DESIGN = 3.0     # column buckling factor of safety at design point

# Scaling law from analysis (exact thin-wall calibration, 10 kW rated, 5-line pentagon,
# T_line ≈ 2333 N):  Do = DO_SCALE × √R.
# Derivation: N_comp is constant across all ring radii when L_seg ∝ R (tapered TRPT),
# so I_req ∝ L_poly² ∝ R² and Do ∝ (I_req)^(1/4) ∝ R^(1/2).
# Calibrated by exact hollow-tube formula: Do = 19.7 mm at R = 2 m (vs 20.7 mm in the
# scalability report which used the thin-wall I ≈ π·t/D·D⁴/8 approximation).
const DO_SCALE = 0.01396    # m/m^0.5  →  Do = DO_SCALE × √R

const G_CFRP = 5e9    # Pa — conservative shear modulus (woven CFRP layup)
const σ_CFRP_COMPR = 600e6  # Pa — compressive strength (conservative unidirectional)

"""
    tube_props(R) → NamedTuple

Cross-section properties of the CFRP design tube for a ring of radius R.
Returns (Do, t, Di, A, I_bend, J, E, G, σ_yield) where J = 2·I_bend for a circular tube.
Uses the unified SpacerRingDesign module under the hood.
"""
function tube_props(R::Float64)
    Do = max(DO_SCALE * sqrt(R), T_MIN_WALL / T_OVER_D)
    t = max(T_OVER_D * Do, T_MIN_WALL)

    # Instantiate CircularTube (paired with DEFAULT_CFRP)
    tube = CircularTube(Do, t / Do)

    # Query properties under unit length and FixedFixedEnds (space frame joints)
    props = strut_properties(tube, 1.0, FixedFixedEnds())

    return (
        Do=Do,
        t=t,
        Di=Do - 2.0 * t,
        A=props.A,
        I_bend=props.I_min,
        J=props.J,
        E=tube.material.E,
        G=tube.material.G,
        σ_yield=tube.material.σ_yield,
    )
end

# Backward-compat wrapper — retained for external callers; internal code uses tube_props
tube_I(Do::Float64, t::Float64)::Float64 =
    strut_properties(CircularTube(Do, t / Do), 1.0, FixedFixedEnds()).I_min

"""
    ring_safety_frame(u, alpha, sys, p, t, wind_fn) → Vector{NamedTuple}

Compute per-ring polygon-segment compression and Euler column buckling FoS for one ODE frame.
Delegates to `ring_element_analysis` and flattens results into the same NamedTuple format
(`ring_id`, `radius`, `N_comp`, `P_crit`, `tube_Do_mm`, `utilisation`, `fos`, `exceeded`)
that downstream consumers (e.g. `capture_frame`) expect.
"""
function ring_safety_frame(
    u::AbstractVector,
    alpha::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    t::Float64=0.0,
    wind_fn::Union{Nothing, Function}=nothing,
)
    frames = ring_element_analysis(u, alpha, sys, p, t, wind_fn)
    return [
        (
            ring_id=f.ring_id,
            radius=f.radius,
            N_comp=maximum(b.N for b in f.beams; init=0.0),
            P_crit=maximum(b.N_crit for b in f.beams; init=1.0),
            tube_Do_mm=tube_props(f.radius).Do * 1e3,
            utilisation=f.max_util,
            fos=f.max_util > 1e-9 ? 1.0 / f.max_util : Inf,
            exceeded=(f.max_util > 1.0),
        ) for f in frames
    ]
end

"""
    ground_station_forces(u, alpha, sys, p, t=0.0, wind_fn=nothing) → NamedTuple

Compute the forces and moments acting on the ground PTO station/ring.
Returns:
- `F_net`: 3D net force vector (N) in global frame acting on the ground station.
- `F_net_mag`: Magnitude of net force (N).
- `F_vertex_max`: Maximum force magnitude on any single ground attachment point (N).
- `F_vertices`: 3×n matrix of individual vertex force vectors (N).
- `M_net`: 3D net moment vector (N·m) about the ground station center.
"""
function ground_station_forces(
    u::AbstractVector,
    alpha::AbstractVector,
    sys::KiteTurbineSystem,
    p::SystemParams,
    t::Float64=0.0,
    wind_fn::Union{Nothing, Function}=nothing,
)
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

    ring_gid = sys.ring_ids[1]
    node = sys.nodes[ring_gid]::RingNode
    R = node.radius
    α_ring = alpha[1]
    n = p.n_lines

    # Extract vertex forces from the tethers
    F_global = extract_vertex_forces(u, sys, ring_gid, alpha, p, perp1, perp2, t, wind_fn)

    # Compute net force
    F_net = sum(F_global; dims=2)[:]
    F_net_mag = norm(F_net)

    # Compute individual vertex force magnitudes and peak
    F_vertex_mags = [norm(F_global[:, j]) for j in 1:n]
    F_vertex_max = maximum(F_vertex_mags)

    # Compute moments about the center [0,0,0]
    M_net = zeros(3)
    for j in 1:n
        pa = attachment_point([0.0, 0.0, 0.0], R, α_ring, j, n, perp1, perp2)
        M_net .+= cross(pa, F_global[:, j])
    end

    return (
        F_net=F_net,
        F_net_mag=F_net_mag,
        F_vertex_max=F_vertex_max,
        F_vertices=F_global,
        M_net=M_net,
    )
end
