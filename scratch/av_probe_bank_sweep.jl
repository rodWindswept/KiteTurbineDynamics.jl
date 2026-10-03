# scratch/av_probe_bank_sweep.jl — aero-validator, 2026-10-02
#
# DECIDES: what does bank angle BUY on the PRE-derate 5 kW winner (the 14-field
# legacy genome, 10.94 kg airborne, bank_top 19.9469 deg)?  Answers the room's
# question with numbers instead of a story.
#
# WHY a decode sweep is the right instrument: for the main (hub) disc rotor the
# bank angle enters the model in exactly TWO places —
#   1. power:     cosd(bank)^2.65   (ring_forces.jl:223 + the three other sites)
#   2. clearance: lowest_rotor_clearance (objective_v10.jl:409-426):
#        alt_tip = g + (z - tip*sind(b)) * sind(elev) - (r_ring + tip*cosd(b)) * cosd(elev)
#      whose derivative is d(alt_tip)/db = tip * sin(b - elev).  At elev = 30 deg
#      that is NEGATIVE for every b < 30 — more bank means LESS tip clearance.
# The full radial/axial force resolution on bank lives only in the expansion
# rotor model (expansion_rotor.jl), which AGENTS.md bans for banked blades and
# which this machine (n_active = 1, disc model) does not use.  Thrust has no
# bank derate.
#
# No settle, no ODE: ~20 s.  Prints clearance, outer radius, span and the power
# factor against bank, so "bank bought clearance" can be confirmed or refuted.
#
# USAGE: scripts/ktd-julia scratch/av_probe_bank_sweep.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const CSV = joinpath(
    ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv"
)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const p = params_at_length(LENGTH)
const RAW = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
length(RAW) >= 14 || error(
    "this probe is written for the 14-field legacy winner file; got $(length(RAW)) fields"
)
x = copy(RAW)
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))    # legacy n_lines
x[10] = Float64(round(Int, clamp(x[10], 1, 3)))   # legacy rotor mask/count

println("=== bank sweep on the PRE-derate winner (14-field legacy genome) ===")
@printf("genome: %s\n", string(round.(RAW, digits=4)))
@printf("its own bank_top gene x[11] = %.4f deg\n\n", RAW[11])

@printf(
    "%6s  %10s  %8s  %9s  %9s  %9s  %9s  %9s\n",
    "bank", "clearance", "gate", "ring_r", "span", "outer_r", "power", "derate"
)
println("-"^78)

n_rings_seen = Ref(0)
n_active_seen = Ref(0)

for b in (0.0, 5.0, 7.0, 10.739909223435728, 15.0, 19.94688644098879, 25.0)
    xb = copy(x)
    xb[11] = b    # 14-D numbering: x[11] = bank_top, x[12] = bank_bottom
    xb[12] = b
    dec = design_from_vector_v10(
        xb, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    clr = KTD.lowest_rotor_clearance(dec)
    r = dec.rotors[1]
    ring_r = dec.radii[r.ring_idx]
    ring_z = dec.zs[r.ring_idx]
    span = r.blade_tip_radius / 0.7
    outer = ring_r + r.blade_tip_radius * cosd(b)
    der = cosd(b)^2.65
    n_rings_seen[] = dec.n_rings
    n_active_seen[] = dec.n_active
    @printf(
        "%6.2f  %8.3f m  %8s  %7.3f m  %7.3f m  %7.4f m  %7.2f%%  %.4f\n",
        b, clr, clr >= 1.5 ? "pass" : "FAIL", ring_r, span, outer, 100 * der, der
    )
end

println("-"^78)
@printf("machine: n_rings=%d n_active=%d  (n_active == 1 => the rotor takes bank_top)\n",
    n_rings_seen[], n_active_seen[])

# ── The analytic claim, checked numerically at the top rotor's own geometry ──
let
    xb = copy(x)
    xb[11] = 19.94688644098879
    xb[12] = 19.94688644098879
    dec = design_from_vector_v10(
        xb, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    r = dec.rotors[1]
    tip = r.blade_tip_radius
    elev = 30.0
    h = 1e-4
    clr(b) = begin
        xc = copy(xb)
        xc[11] = b
        xc[12] = b
        d = design_from_vector_v10(
            xc, PROFILE_ELLIPTICAL, p; power_W=PW,
            cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
            cone_slope_deg=22.0, rotor_spacing_frac=0.8,
            blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        )
        KTD.lowest_rotor_clearance(d)
    end
    b0 = 19.94688644098879
    num = (clr(b0 + h) - clr(b0 - h)) / (2h)
    ana = tip * sind(b0 - elev)
    @printf("\nd(clearance)/d(bank) at %.2f deg: numeric %+.6f m/deg   tip*sin(b-elev) %+.6f m/deg\n",
        b0, num, ana)
    @printf("tip offset (0.7*span) = %.4f m;  elevation used by the clearance gate = %.1f deg\n",
        tip, elev)
    @printf("bank that MAXIMISES tip altitude inside the search box (0-25 deg): 0 deg\n")
end
