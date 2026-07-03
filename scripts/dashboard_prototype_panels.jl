#!/usr/bin/env julia
#= scripts/dashboard_prototype_panels.jl
Prototype panels for KTD.jl dashboard redesign.
=#

using KiteTurbineDynamics
using CairoMakie
using LinearAlgebra
using Printf

const BG        = RGBf(0.039, 0.047, 0.063)
const PANEL     = RGBf(0.071, 0.086, 0.114)
const EDGE      = RGBf(0.133, 0.165, 0.208)
const INK       = RGBf(0.910, 0.933, 0.965)
const INK_DIM   = RGBf(0.604, 0.655, 0.714)
const INK_FAINT = RGBf(0.392, 0.447, 0.518)
const ACCENT    = RGBf(0.224, 0.816, 0.847)
const GREEN     = RGBf(0.2,   0.8,   0.3)
const ORANGE    = RGBf(0.95,  0.55,  0.1)
const RED       = RGBf(0.95,  0.2,   0.2)

# ── Functions ──────────────────────────────────────────────────────────

function rotor_gauge!(gp, P_aero_kw, P_ground_kw, P_rated_kw, label::String; max_radius=0.40)
    ax = Axis(gp; aspect=DataAspect(), backgroundcolor=PANEL, xgridvisible=false, ygridvisible=false)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -0.55, 0.55, -0.55, 0.55)
    θ0 = deg2rad(225.0); sweep = deg2rad(270.0); n_pts = 80
    P_scale = max(P_rated_kw, 0.1)
    θ_track = range(θ0, θ0 - sweep; length=n_pts)
    lines!(ax, max_radius .* cos.(θ_track), max_radius .* sin.(θ_track); color=EDGE, linewidth=5)
    f_aero = clamp(P_aero_kw / P_scale, 0.0, 1.0)
    n_a = max(2, round(Int, n_pts * f_aero))
    lines!(ax, max_radius .* cos.(range(θ0, θ0 - sweep*f_aero; length=n_a)), max_radius .* sin.(range(θ0, θ0 - sweep*f_aero; length=n_a)); color=ACCENT, linewidth=5)
    inner_r = max_radius * 0.62
    f_ground = clamp(P_ground_kw / P_scale, 0.0, 1.0)
    n_g = max(2, round(Int, n_pts * f_ground))
    lines!(ax, inner_r .* cos.(range(θ0, θ0 - sweep*f_ground; length=n_g)), inner_r .* sin.(range(θ0, θ0 - sweep*f_ground; length=n_g)); color=GREEN, linewidth=5)
    eff = P_aero_kw > 0.01 ? P_ground_kw / P_aero_kw * 100.0 : 0.0
    text!(ax, 0, 0.06; text=@sprintf("%.0f%%", eff), align=(:center,:center), fontsize=14, color=INK, font=:bold)
    text!(ax, 0, -0.32; text=label, align=(:center,:center), fontsize=10, color=INK_DIM)
    return ax
end

function ring_health_bars!(gp, fos, Ncomp, Pcrit, exp_rings, ring_labels)
    n = length(fos)
    ax = Axis(gp[1, 1]; yreversed=true, backgroundcolor=PANEL,
              xlabel="N/Pcr", xlabelcolor=INK_DIM, xticklabelsize=8, yticklabelsize=8,
              xtickcolor=INK_DIM, ytickcolor=INK_DIM, yticklabelcolor=INK, spinewidth=0.5)
    ylims!(ax, 0.5, n + 0.5); xlims!(ax, 0, 1.5)
    vals = Float64[]; cols = RGBAf[]
    for i in 1:n
        ratio = Pcrit[i] > 0 ? Ncomp[i] / Pcrit[i] : 0.0
        push!(vals, clamp(ratio, 0.0, 1.5))
        push!(cols, fos[i] >= 2.0 ? GREEN : fos[i] >= 1.0 ? ORANGE : RED)
    end
    barplot!(ax, 1:n, vals; direction=:x, color=cols, width=22, strokewidth=0)
    for i in 1:n
        text!(ax, vals[i] + 0.05, Float64(i); text=@sprintf("%.1f", fos[i]), align=(:left,:center), fontsize=7, color=cols[i])
    end
    for ri in exp_rings; 1 <= ri <= n && scatter!(ax, [0.02], [Float64(ri)]; color=ACCENT, marker=:diamond, markersize=10); end
    ax.yticks = (1:n, ring_labels)
    return ax
end

function twist_view!(gp, twists_deg, ring_labels)
    n = length(twists_deg); cum_twist = cumsum(twists_deg)
    ax = Axis(gp[1, 1]; aspect=DataAspect(), backgroundcolor=PANEL, title="Twist", titlesize=9, titlecolor=INK_DIM)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -1.3, 1.3, -1.3, 1.3)
    for r in [0.3, 0.6, 0.9, 1.2]
        θ_c = range(0, 2π; length=100)
        lines!(ax, r .* cos.(θ_c), r .* sin.(θ_c); color=EDGE, linewidth=0.5)
    end
    colours = [RGBf(0.0+0.7*(i-1)/max(n,1), 0.8-0.3*(i-1)/max(n,1), 1.0-0.5*(i-1)/max(n,1)) for i in 1:n+1]
    for i in 1:(n+1)
        θ = i <= n ? deg2rad(cum_twist[i]) : deg2rad(cum_twist[end])
        lines!(ax, [0.0, 1.2*cos(θ)], [0.0, 1.2*sin(θ)]; color=colours[i], linewidth=2.5)
        i <= n && scatter!(ax, [0.9*cos(θ)], [0.9*sin(θ)]; color=colours[i], markersize=6)
    end
    scatter!(ax, [0.0], [0.0]; color=ACCENT, markersize=10, marker=:star5)
    text!(ax, 0, -0.15; text="GND", align=(:center,:center), fontsize=8, color=INK_FAINT)
    text!(ax, 0, 1.15; text=@sprintf("Σ|Δα|=%.0f°", sum(abs, twists_deg)), align=(:center,:center), fontsize=9, color=INK_DIM)
    return ax
end

# ── Synthetic data ────────────────────────────────────────────────────
n_rings = 12; ring_labels = ["R$i" for i in 1:n_rings]
fos_vals    = [Inf, 4.2, 3.1, 2.8, 2.1, 1.8, 2.5, 3.0, 4.0, 5.5, Inf, Inf]
Ncomp_vals  = [0.0, 1200.0, 2400.0, 3100.0, 4500.0, 5200.0, 3800.0, 2900.0, 1800.0, 800.0, 0.0, 0.0]
Pcrit_vals  = [Inf, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, 5000.0, Inf, Inf]
exp_rings   = [4, 7, 10]
twists_deg  = [2.3, 5.1, 3.8, -1.2, 4.5, 6.2, 3.0, -0.8, 1.5, 2.0, 0.5]
rotor_labels  = ["Hub", "R4", "R7", "R10"]
P_aero_kw     = [8.5, 3.2, 2.1, 1.4]
P_ground_kw   = [7.8, 2.4, 1.3, 0.6]
# Stack bottom-to-top on the turbine: ground → R10 → R7 → R4 → Hub
rotor_labels_v = reverse(rotor_labels)
P_aero_kw_v    = reverse(P_aero_kw)
P_ground_kw_v  = reverse(P_ground_kw)
P_rated_total = 15.0

# ═══════════════════════════════════════════════════════════════════════
# BUILD — 4 content rows, full-width
# Row 1: Cockpit (all cols)
# Row 2-3: [Torque][Ring Health][Rotor Stack][Config & Controls]
# Row 4-5: [Twist ×2][Tension Chain][3D Viewport]
# Row 6: Event Log + Controls
# ═══════════════════════════════════════════════════════════════════════

println("=== KTD.jl Dashboard Prototype ===")
fig = Figure(size=(1500, 880), backgroundcolor=BG)

# ROW 1 — Cockpit (full width) ────────────────────────────────────────
rowsize!(fig.layout, 1, Fixed(46))
strip = GridLayout(fig[1, 1:4])
kpi_data = [("8.5 kW","POWER"),("180 rpm","Ω HUB"),("4.2","FoS"),("0.62","UTIL"),
            ("11","WIND"),("68°","TWIST"),("12.5s","TIME")]
for (i,(val,lbl)) in enumerate(kpi_data)
    Label(strip[1,i], val; fontsize=16, font=:bold, color=INK, halign=:left)
    Label(strip[2,i], lbl; fontsize=8, color=INK_DIM, halign=:left)
    colsize!(strip, i, Fixed(130))
end

# ROW 2 — Headers (full width) ────────────────────────────────────────
for (col,hdr) in [(1,"TORQUE CHAIN"),(2,"RING HEALTH"),(3,"ROTOR POWER (ground→sky)"),(4,"CONFIG & CONTROLS")]
    Label(fig[2,col], hdr; fontsize=9, color=INK_DIM, halign=:center)
end

# ROW 3 — Torque chain ─────────────────────────────────────────────────
ax_tq = Axis(fig[3,1]; yreversed=true, backgroundcolor=PANEL,
    xlabel="τ N·m", xticklabelsize=7, yticklabelsize=7,
    xtickcolor=INK_DIM, ytickcolor=INK_DIM, yticklabelcolor=INK)
tau_vals = [0,120,250,450,680,950,1100,1150,1080,950,800,700]
barplot!(ax_tq,1:n_rings,Float64.(tau_vals); direction=:x,
         color=[ACCENT for _ in 1:n_rings], width=35, strokewidth=0)
ylims!(ax_tq,0.5,12.5); ax_tq.yticks=(1:n_rings,ring_labels)

# ROW 3 — Ring health ──────────────────────────────────────────────────
ring_health_bars!(GridLayout(fig[3,2]), fos_vals, Ncomp_vals, Pcrit_vals, exp_rings, ring_labels)

# ROW 3 — Rotor power stack (vertical, ground→sky) ─────────────────────
rg = GridLayout(fig[3,3])
for (i,lbl) in enumerate(rotor_labels_v)
    # Larger circles, stacked: R10(top) R7 R4 Hub(bottom)
    rotor_gauge!(rg[i,1], P_aero_kw_v[i], P_ground_kw_v[i],
                 P_rated_total/length(rotor_labels_v), lbl; max_radius=0.42)
end

# ROW 3 — Config & Controls ────────────────────────────────────────────
cf = GridLayout(fig[3,4])
Label(cf[1,1],"⚙ CONFIG"; fontsize=10,color=ACCENT,font=:bold,halign=:left)
Label(cf[2,1],"Design:  [V10 Tight ▼]"; fontsize=9,color=INK,halign=:left)
Label(cf[3,1],"Scenario:[Cruise ▼]  V_ref:11.0  Dur:10s"; fontsize=9,color=INK,halign=:left)
Label(cf[4,1],"Gen ctrl: [Standard ▼]  k_mppt:1.5×"; fontsize=9,color=INK,halign=:left)
Label(cf[5,1],"Payout: [25m Extended ▼]  dt:4×10⁻⁵"; fontsize=9,color=INK,halign=:left)
Label(cf[6,1],"── Run Peaks ──"; fontsize=10,font=:bold,color=INK,halign=:left)
Label(cf[7,1],"P 8.52kW · ω 1770rpm · T 4820N"; fontsize=8,color=INK_DIM,halign=:left)
Label(cf[8,1],"FoS 3.11 · V 11.2 · Slack 0/500"; fontsize=8,color=INK_DIM,halign=:left)
Label(cf[9,1],"── Regen Controls ──"; fontsize=10,font=:bold,color=INK,halign=:left)
Label(cf[10,1],"Active Winch: [OFF]  Stall Gov: [OFF]"; fontsize=8,color=INK_DIM,halign=:left)
Label(cf[11,1],"Field IMU: [OFF]  Depower Seq: [1]"; fontsize=8,color=INK_DIM,halign=:left)
Label(cf[12,1],"Auto-Ramp: [OFF]  State: IDLE"; fontsize=8,color=INK_DIM,halign=:left)

# ROW 4 — Headers ──────────────────────────────────────────────────────
for (col,hdr) in [(1,"TWIST VIEW"),(2,"TENSION CHAIN"),(3,"3D VIEWPORT")]
    Label(fig[4,col]; text=hdr, fontsize=9, color=INK_DIM, halign=:center)
end

# ROW 5 — Twist view (spans 2 cols for readability) ────────────────────
twist_view!(GridLayout(fig[5,1]), twists_deg, ring_labels[1:end-1])

# ROW 5 — Tension chain ────────────────────────────────────────────────
ax_tn = Axis(fig[5,2]; yreversed=true, backgroundcolor=PANEL,
    xlabel="T kN", xticklabelsize=7, yticklabelsize=7,
    xtickcolor=INK_DIM, ytickcolor=INK_DIM, yticklabelcolor=INK)
Tv = Float64[15,14.2,13.1,11.8,10.5,9.2,8,7.1,6.5,6,5.8]
sc = [t > 10 ? GREEN : t > 5 ? ORANGE : RED for t in Tv]
barplot!(ax_tn,1:11,Tv; direction=:x, color=sc, width=22, strokewidth=0)
ylims!(ax_tn,0.5,11.5); ax_tn.yticks=(1:11,["S$i" for i in 1:11])
vlines!(ax_tn,[15.0]; color=RED, linestyle=:dash, linewidth=1.5)

# ROW 5 — 3D viewport ─────────────────────────────────────────────────
ax_3d = Axis3(fig[5,3:4]; backgroundcolor=PANEL,
    title="TRPT — KiteTurbineDynamics.jl", titlesize=10, titlecolor=INK_DIM)
hidedecorations!(ax_3d)
text!(ax_3d,0,0,0; text="3D viewport\n(integrate build_dashboard)",
      align=(:center,:center), fontsize=14, color=INK_FAINT)

# ROW 6 — Event log + Regen controls ──────────────────────────────────
Label(fig[6,1:2],"EVENT LOG  |  CRUISE  |  11m/s  |  k=1.5×  |  Brake OFF  |  ✓ No warnings";
      fontsize=9,color=INK_DIM,halign=:left)
Label(fig[6,3:4],"◄◄ ► ►►  |  247/500  |  [Run]  [Stop]  |  Scenarios ▼";
      fontsize=9,color=INK_DIM,halign=:right)

save("scripts/results/dashboard_prototype_panels.png", fig; px_per_unit=1.8)
println("✓ Saved to scripts/results/dashboard_prototype_panels.png")
