#!/usr/bin/env julia
# av_fdecode_probe.jl — per-design bridle-drag fraction decode, 508 ok rows
# at data commit dd3cc6a (v13_5kw_masslift_len18.8_rotorcount_bankderate2).
#
# Lane 1 of the feedbackbot3 routing (section E, aero-validator seat):
# three f columns per row — k = 2.24, k* in the 8.4..8.9 bracket with the
# frozen 3 mm diameter, and with the sized diameter (RF-19).
#
# The decode runs the committed code path: design_from_vector_v10 with the
# campaign kwargs, exactly as the evaluator threads them
# (src/objective_evaluator.jl:832-846).  Bridle drag follows the RF-11
# geometry bound (scratch/av_bridle_drag_bound_2026-10-22.py): a cylindrical
# line element in the rotor plane, P = 0.5 rho Cd d w^3 (r_hi^4 - r_lo^4)/4,
# two bridles (outer anchor 0.49 span outboard of the blade root, inner
# anchor 0.21 span inboard), plus the full-line worst case.  Cd 1.2, d 3 mm.
# f = kappa / k with kappa geometry-only (kappa = P_drag / w^3).
using KiteTurbineDynamics, CSV, Printf, Statistics

const LENGTH = 18.8
const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const POWER_SPLIT = 0.6
const CONE_SLOPE = 22.0
const ROTOR_SPACING_FRAC = 0.8
const BLOCKING = 1.0

# ── Campaign parameter context (params_at_length from the run file) ──────
p2 = params_daisy()
geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, LENGTH,
    p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
p_base = override_params(scaled; tether_length=LENGTH)
beam_profile = PROFILE_ELLIPTICAL

@printf("h_ref %.6f  tether %.2f\n", p_base.h_ref, p_base.tether_length)

function decode_row(x::Vector{Float64})
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # n_lines (R7 10-D layout)
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # rotor count {1,2,3}
    dec = design_from_vector_v10(xr, beam_profile, p_base;
        power_W=PW, v_rated=V_RATED,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=POWER_SPLIT, cone_slope_deg=CONE_SLOPE,
        rotor_spacing_frac=ROTOR_SPACING_FRAC, blocking_factor=BLOCKING)
    return dec, xr
end

# ── Bridle drag constants ────────────────────────────────────────────────
const RHO = 1.225
const CD = 1.2
const D_FROZEN = 0.003
const K_FLAT = 2.24
const KSTAR_LO = 8.4
const KSTAR_HI = 8.9
# RF-19 sized-diameter factor (map seat). Provenance unresolved at this
# desk at probe time; the receipt routes the ask. Applied as f' = c * f.
const SIZED_LO = 0.298
const SIZED_HI = 0.321

function bridle_kappa(span, r_in)
    r_out = r_in + span                      # r_in + 0.3 span + 0.7 span
    r_a = r_in + 0.49 * span                 # outer bridle inboard anchor
    r_b = r_in - 0.21 * span                 # inner bridle outboard anchor
    quad4(x, y) = 0.5 * RHO * CD * D_FROZEN * (x^4 - y^4) / 4.0
    kappa2 = quad4(r_out, r_a) + quad4(r_in, max(r_b, 0.0))
    kappafull = quad4(r_out, r_in)
    return kappa2, kappafull
end

# ── Read the archive ─────────────────────────────────────────────────────
RD = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
rows = Any[]
for isl in (1, 2, 3)
    path = joinpath(RD, "island_$(isl)", "telemetry.csv")
    for r in CSV.File(path; comment="#")
        r.status == "ok" || continue
        push!(rows, r)
    end
end
@printf("ok rows %d\n", length(rows))

# ── Decode every row ─────────────────────────────────────────────────────
out = NamedTuple[]
nerr = 0
for r in rows
    x = [Float64(r[Symbol("x$i")]) for i in 1:10]
    try
        dec, xr = decode_row(x)
        top = dec.rotors[1]
        span = 0.75 * top.r_rotor * top.blade_scale
        ring_r = dec.radii[top.ring_idx]
        r_in = ring_r + top.blade_hub_radius          # -0.3 span offset
        r_out = ring_r + top.blade_tip_radius         # +0.7 span offset
        kappa2, kappafull = bridle_kappa(span, r_in)
        push!(out, (;
            island=r.island, gen=r.gen, idx=r.idx, status=r.status,
            fitness=Float64(r.fitness), P_end=Float64(r.P_end),
            n_lines=Int(xr[4]), rotor_count=Int(xr[6]),
            r_hub=Float64(r.r_hub), bank=top.bank_angle_deg,
            blade_scale=top.blade_scale, v_wind=top.v_wind,
            r_rotor=top.r_rotor, span=span, r_in=r_in, r_out=r_out,
            ring_z=dec.zs[top.ring_idx], ring_r=ring_r,
            kappa2=kappa2, kappafull=kappafull,
            f_k224=kappa2 / K_FLAT,
            f_kstar_lo=kappa2 / KSTAR_HI,             # k* = 8.9 (low f end)
            f_kstar_hi=kappa2 / KSTAR_LO,             # k* = 8.4 (high f end)
            f_sized_lo=kappa2 / KSTAR_HI * SIZED_LO,  # sized d, k* = 8.9
            f_sized_hi=kappa2 / KSTAR_LO * SIZED_HI,  # sized d, k* = 8.4
            f_full_k224=kappafull / K_FLAT,
        ))
    catch e
        nerr += 1
        @printf("decode error island %s gen %s idx %s: %s\n", r.island, r.gen, r.idx, sprint(showerror, e))
    end
end
@printf("decoded %d rows, %d errors\n", length(out), nerr)

CSV.write("scratch/av_fdecode_508.csv", out)

# ── Winner cross-checks ──────────────────────────────────────────────────
w = filter(o -> o.fitness ≈ 27.364, out)
if !isempty(w)
    w1 = w[1]
    @printf("winner: r_rotor %.6f span %.6f r_in %.6f r_out %.6f ring_z %.4f v_wind %.4f\n",
        w1.r_rotor, w1.span, w1.r_in, w1.r_out, w1.ring_z, w1.v_wind)
    @printf("  NR-050 expects r_rotor 2.434, span 1.499 (NR-043)\n")
    @printf("  av probe expects r_in 4.130158, r_out 5.629560\n")
    @printf("  f(k=2.24) two-bridle %.4f (RF-19 credible 0.104-0.129)  full-line %.4f (RF-19 0.177)\n",
        w1.f_k224, w1.f_full_k224)
    @printf("  f(k*) frozen: %.4f-%.4f   sized: %.4f-%.4f\n",
        w1.f_kstar_lo, w1.f_kstar_hi, w1.f_sized_lo, w1.f_sized_hi)
else
    @printf("winner fitness 27.364 not found\n")
end

# ── Fleet summary ────────────────────────────────────────────────────────
fs = sort([o.f_k224 for o in out])
@printf("fleet f(k=2.24): min %.4f median %.4f max %.4f  (n=%d)\n",
    fs[1], fs[end ÷ 2], fs[end], length(fs))
println("done")
