# scratch/probe_axial_gap_compare.jl
#
# Island 1 vs 2 vs 3 — axial-gap and ring-attachment diagnosis (2026-09-22).
#
# Rod's question: island 1's hub must not be able to surge up-shaft into the
# bearing faster than the lift kite lifts the sky anchor.  If it does, the extra
# travel is a kinematic artifact, not physics.  This probe measures the axial gap
# and the hub's axial force budget from the FIRST frame, and A/B tests the three
# ring-attachment artifacts behind the RING_ATTACHMENT toggle in rope_forces.jl.
#
# Measurements per sample:
#   z_gap      = (p_bear − p_hub) · ŝ        ŝ = hub_pos/|hub_pos| (the model's
#                                            own dynamic shaft direction)
#   L_off_nom  = r_hub / tan(31°)            the design bearing offset
#   hub_lat    = hub's perpendicular distance from the DESIGN shaft axis
#                (the dynamic ŝ is defined BY the hub, so it cannot measure it)
#   bear_lat   = bearing's perpendicular distance from the dynamic ŝ
#   tilt_deg   = min(0.1·bear_lat_perp, 30°), the synthetic ring-plane tilt
#   F_thrust   = main-rotor thrust (up-shaft)
#   F_bridle   = Σ bridle tension, axial component (up-shaft)
#   F_trpt     = top-bay tension, axial component (down-shaft)
#   F_grav     = m_hub·g·sin(beta) (down-shaft)
#   F_net_pred = F_thrust + F_bridle − F_trpt − F_grav
#   F_net_meas = m_hub · (du_hub · ŝ)        cross-check, from multibody_ode!
#
# Usage:
#   julia --project=. scratch/probe_axial_gap_compare.jl <island> [config] [T_s]
#   config ∈ default | notilt | bridletilt | notorque | notilt_notorque

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KTD = KiteTurbineDynamics
const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)
const ISLAND = length(ARGS) >= 1 ? ARGS[1] : "island_1"
const CONFIG = length(ARGS) >= 2 ? ARGS[2] : "default"
const T_S = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 2.0
const SAMPLE_DT = 0.01

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]

function apply_config!(name)
    b = if name == "default"
        # Canonical: one ring plane for every attachment (Rod's 2026-09-22 ruling),
        # bridle axial torque on, both expansion rotors fully aerodynamic.
        KTD.RingAttachmentPhysics()
    elseif name == "notilt"
        KTD.RingAttachmentPhysics(; tilt_enabled=false)
    elseif name == "notorque"
        KTD.RingAttachmentPhysics(; bridle_axial_torque=false)
    elseif name == "noexp_aero"
        # PROBE A: aero vs structural.  F_axial and tau_net are zeroed for BOTH
        # expansion rotors.  Ring mass, assembly inertia J_rotor and geometry stay,
        # so the column is structurally identical.
        KTD.RingAttachmentPhysics(; expansion_aero=false)
    elseif name == "ring9only"
        # PROBE B: ring 8's aero off, so ring 9 (upper) drives alone.
        KTD.RingAttachmentPhysics(; expansion_aero_off=[8])
    elseif name == "ring8only"
        # PROBE B: ring 9's aero off, so ring 8 (lower) drives alone.
        KTD.RingAttachmentPhysics(; expansion_aero_off=[9])
    elseif name == "tilt_hub_only"
        # PROBE C: the synthetic tilt applies to the hub ring only.
        KTD.RingAttachmentPhysics(; tilt_scope=:hub)
    else
        error("unknown config $name")
    end
    KTD.set_ring_attachment!(b)
    return b
end

CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")
p0 = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(
    xv,
    PROFILE_ELLIPTICAL,
    p0;
    power_W=5000.0,
    cylinder_cone=true,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=bf,
)
cfg = KTD.ObjectiveConfig(;
    power_W=5000.0,
    v_rated=11.0,
    p_floor_kw=5.0,
    fos_target=2.5,
    fos_hard=2.5,
    min_wall_m=2e-3,
    t_over_D=0.055,
    rotor_count_mode=true,
    power_split=0.6,
    blocking_factor=bf,
)
sizing = KTD.size_beams_closed_form(dec, p0, cfg)
sys, u0, p = KTD.build_system_from_v10(
    dec,
    1.0,
    K_MPPT_5KW_HONEST;
    tether_diameter=p0.tether_diameter,
    base_params=p0,
    min_wall_m=2e-3,
    beam_sizing=sizing,
)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, p)
wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]

b = apply_config!(CONFIG)
u = settle_to_operational_state(
    sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
)

N, Nr = sys.n_total, sys.n_ring
hub_gid, bear_gid, sky_gid = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
β = p.elevation_angle
design_shaft = [cos(β), 0.0, sin(β)]
R_hub = (sys.nodes[hub_gid]::RingNode).radius
L_off_nom = KTD.bridle_bearing_offset(R_hub)

const DT = KTD.stable_dt_for_system(sys, p)

"Tension of every sub-seg, tagged by family, plus the hub's axial budget."
function sample(u)
    h = pos(u, hub_gid)
    bp = pos(u, bear_gid)
    sh = h ./ norm(h)
    # design-axis lateral offset of the hub
    hub_lat = norm(h .- dot(h, design_shaft) .* design_shaft)
    berr = bp .- h
    bear_perp = norm(berr .- dot(berr, sh) .* sh)
    z_gap = dot(bp .- h, sh)

    # ── forces on the hub node ──
    T_thrust = 0.0
    v_hub = norm(wf(h, 0.0)) * sys.rotor.wind_factor
    if v_hub > 0.1
        ω_r = u[6N + Nr + hub_ri]
        λ = abs(ω_r) * sys.rotor.radius / v_hub
        T_thrust =
            0.5 *
            p.rho *
            v_hub^2 *
            KTD.main_rotor_swept_area(sys) *
            KTD.ct_at_tsr(λ) *
            cos(atan(h[3], hypot(h[1], h[2])))^2
    end

    F_bridle = 0.0
    F_trpt = 0.0
    cone = zeros(p.n_lines)
    cone_ring = zeros(p.n_lines)

    # Reproduce the FORCE PATH's attachment geometry exactly (rope_forces.jl):
    # TRPT ring ends use the (tilted) ring basis, bridle ring ends use the shaft
    # basis unless the toggle says otherwise.  Using ring CENTRES here would make
    # the budget disagree with the forces the integrator actually applies.
    perp1_shaft, perp2_shaft = KTD.shaft_perp_basis(sh)
    pp1t, pp2t = KTD._tilted_ring_basis(u, sys, hub_gid, hub_ri)
    if !KTD.RING_ATTACHMENT[].tilt_enabled
        pp1t, pp2t = perp1_shaft, perp2_shaft
    end
    alph = @view u[(6N + 1):(6N + Nr)]
    hub_ri_p = (sys.nodes[hub_gid]::RingNode).ring_idx
    attach = function (ss, se)
        if se.is_ring
            node = sys.nodes[se.node_id]::RingNode
            ri = node.ring_idx
            R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
            # Mirror the FORCE PATH exactly: one ring plane per ring, gated by the
            # same `tilt_applies` scope (the dual-plane exception is retired).
            p1, p2 = if KTD.tilt_applies(ri, hub_ri_p)
                (pp1t, pp2t)
            else
                (perp1_shaft, perp2_shaft)
            end
            return KTD.attachment_point(
                pos(u, se.node_id), R, alph[ri], se.line_idx, p.n_lines, p1, p2
            )
        else
            return collect(pos(u, se.node_id))
        end
    end

    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        touches_hub = (na == hub_gid) || (nb == hub_gid)
        touches_hub || continue
        pa = attach(ss, ss.end_a)
        pb = attach(ss, ss.end_b)
        d = pb .- pa
        L = norm(d)
        L <= 0 && continue
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        dhat = d ./ L
        # Force ON the hub along the rope: it pulls the hub TOWARD the other end.
        # end_a = hub  -> +T*dhat (dhat points hub -> other)
        # end_b = hub  -> -T*dhat (dhat points other -> hub)
        sgn = (na == hub_gid) ? 1.0 : -1.0
        ax = sgn * T * dot(dhat, sh)
        if na == bear_gid || nb == bear_gid
            F_bridle += ax
            li = ss.end_a.is_ring ? ss.end_a.line_idx : ss.end_b.line_idx
            cone[li] += T
        else
            F_trpt += -ax            # down-shaft pull, positive magnitude
            li = ss.end_a.is_ring ? ss.end_a.line_idx : ss.end_b.line_idx
            cone_ring[li] += T
        end
    end
    F_grav = (sys.nodes[hub_gid]::RingNode).mass * 9.81 * sin(β)
    F_pred = T_thrust + F_bridle - F_trpt - F_grav

    du = zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    m_hub = (sys.nodes[hub_gid]::RingNode).mass
    F_meas = m_hub * dot(du[(3N + 3 * (hub_gid - 1) + 1):(3N + 3 * hub_gid)], sh)

    tilt_deg = rad2deg(min(bear_perp * 0.1, π / 6))
    return (;
        z_gap,
        hub_lat,
        bear_perp,
        tilt_deg,
        T_thrust,
        F_bridle,
        F_trpt,
        F_grav,
        F_pred,
        F_meas,
        cone_total=sum(cone),
        cone_max=maximum(cone),
        topbay=sum(cone_ring),
        ring_per_line=copy(cone_ring),
    )
end

rows = NamedTuple[]
n_steps = round(Int, T_S / DT)
n_samp = round(Int, T_S / SAMPLE_DT)
samp_every = max(1, round(Int, SAMPLE_DT / DT))

@printf("═══ %s  config=%s  T=%.1f s  dt=%.3e ═══\n", ISLAND, CONFIG, T_S, DT)
@printf(
    "toggles: tilt_enabled=%s tilt_scope=%s bridle_axial_torque=%s expansion_aero=%s off=%s\n",
    b.tilt_enabled,
    b.tilt_scope,
    b.bridle_axial_torque,
    b.expansion_aero,
    b.expansion_aero_off
)
@printf(
    "L_off_nom = r_hub/tan(31deg) = %.4f m   r_hub = %.3f   m_hub = %.4f kg\n",
    L_off_nom,
    R_hub,
    (sys.nodes[hub_gid]::RingNode).mass
)

s = sample(u)
push!(rows, merge((t=0.0,), s))
@printf(
    "\n%7s %9s %9s %9s %8s %9s %9s %9s %9s %9s %9s\n",
    "t",
    "z_gap",
    "gap-Loff",
    "hub_lat",
    "tilt",
    "F_thrust",
    "F_bridle",
    "F_trpt",
    "F_grav",
    "F_pred",
    "F_meas"
)
@printf(
    "%7.3f %9.4f %+9.4f %9.4f %8.3f %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f\n",
    rows[end].t,
    s.z_gap,
    s.z_gap - L_off_nom,
    s.hub_lat,
    s.tilt_deg,
    s.T_thrust,
    s.F_bridle,
    s.F_trpt,
    s.F_grav,
    s.F_pred,
    s.F_meas
)

# ── integrate with the CANONICAL loop ────────────────────────────────────────
# CLAUDE.md: "Always use `run_canonical_sim!()` for headless simulation, never
# hand-roll integrators."  A hand-rolled copy silently omitted the twist update
# (`dα/dt = ω`, simulation.jl:185) and made the cone look healthy, so this probe
# now uses the canonical loop.  `lin_damp = 0.0` is the governing envelope;
# `breaks_enabled = false` because this is a short startup window, not an
# operational break test (see the run_canonical_sim! docstring).
function record!(rows, u, t, L_off_nom)
    sm = sample(u)
    push!(rows, merge((t=t,), sm))
    if length(rows) <= 11 || length(rows) % 25 == 0
        @printf(
            "%7.3f %9.4f %+9.4f %9.4f %8.3f %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f\n",
            t,
            sm.z_gap,
            sm.z_gap - L_off_nom,
            sm.hub_lat,
            sm.tilt_deg,
            sm.T_thrust,
            sm.F_bridle,
            sm.F_trpt,
            sm.F_grav,
            sm.F_pred,
            sm.F_meas
        )
    end
    return nothing
end

cb = function (uu, tt, step)
    if step % samp_every == 0
        record!(rows, uu, tt, L_off_nom)
    end
    return nothing
end

run_canonical_sim!(
    u,
    sys,
    p,
    wf,
    n_steps,
    DT;
    lift_device=lift,
    lin_damp=0.0,
    callback=cb,
    breaks_enabled=false,
)

z = [r.z_gap for r in rows]
hl = [r.hub_lat for r in rows]
ct = [r.cone_total for r in rows]
tt = [r.t for r in rows]
first_dead = findfirst(<(1.0), ct)
tilt = [r.tilt_deg for r in rows]
@printf("\n── summary ──\n")
@printf(
    "z_gap  t=0 %.4f  min %.4f (t=%.2f)  max %.4f (t=%.2f)  final %.4f\n",
    z[1],
    minimum(z),
    tt[argmin(z)],
    maximum(z),
    tt[argmax(z)],
    z[end]
)
@printf(
    "gap deficit vs L_off_nom: min %+.4f  max %+.4f\n",
    minimum(z) - L_off_nom,
    maximum(z) - L_off_nom
)
@printf(
    "hub_lat t=0 %.4f  max %.4f (t=%.2f)  final %.4f\n",
    hl[1],
    maximum(hl),
    tt[argmax(hl)],
    hl[end]
)
@printf(
    "tilt_deg max %.3f   cone_total min %.2f  final %.2f\n",
    maximum(tilt),
    minimum(ct),
    ct[end]
)
if first_dead === nothing
    @printf("cone never drops below 1.0 N\n")
else
    @printf(
        "cone first < 1.0 N at t=%.2f s (then dead %.0f%% of samples)\n",
        tt[first_dead],
        100 * count(<(1.0), ct[(first_dead + 1):end]) / max(length(ct) - first_dead, 1)
    )
end
resid = [r.F_pred - r.F_meas for r in rows]
@printf("axial budget residual: max |F_pred − F_meas| = %.2f N\n", maximum(abs.(resid)))

csv = joinpath(@__DIR__, "..", ".julia_depot", "logs", "axialgap_$(ISLAND)_$(CONFIG).csv")
open(csv, "w") do io
    println(
        io,
        "t,z_gap,hub_lat,bear_perp,tilt_deg,F_thrust,F_bridle,F_trpt,F_grav,F_pred,F_meas,cone_total,topbay",
    )
    for r in rows
        @printf(
            io,
            "%.4f,%.6f,%.6f,%.6f,%.4f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n",
            r.t,
            r.z_gap,
            r.hub_lat,
            r.bear_perp,
            r.tilt_deg,
            r.T_thrust,
            r.F_bridle,
            r.F_trpt,
            r.F_grav,
            r.F_pred,
            r.F_meas,
            r.cone_total,
            r.topbay
        )
    end
end
println("csv: $csv")
println("=== done ===")
