# src/dashboard_panels.jl
# Panel functions for the KTD.jl dashboard — extracted from visualization.jl.
# Each panel takes a grid cell + data observable + colour palette.
# Panels are layout-agnostic: they don't know which row/column they're in.

"""
    DashboardPalette

Colour palette for dashboard panels. Passed to each panel function.
Uses the A1 Instrument dark theme.
"""
struct DashboardPalette
    BG::Any        # near-black
    PANEL::Any     # panel background
    EDGE::Any      # borders
    INK::Any       # primary text
    INK_DIM::Any   # secondary text
    INK_FAINT::Any # tertiary text
    ACCENT::Any    # cyan
    GREEN::Any     # OK
    ORANGE::Any    # warn
    RED::Any       # alarm
end

"""
    fos_str(v) -> String

Format a factor-of-safety value for readout. Infinite / NaN / very large
values render as "∞"; everything else as a 1-decimal fixed field. Module-level
so dashboard scripts (v2 standalone, --v2) can share it with the v1 HUD.
"""
fos_str(v) = (isinf(v) || isnan(v) || v > 9999) ? "   ∞" : @sprintf("%6.1f", v)


"""
    torque_chain!(gp, ext_frames_obs, palette; n_segments, seg_labels)

Vertical bar chart of the REAL transmitted torque carried by each rope segment
(ground → hub). Reads `ExtendedSimFrame.segment_torque`, which capture_extended
computes from the TRPT torsional constitutive law (τ = n·T·r²·sinΔα/chord)
evaluated on the actual per-segment tension and inter-ring twist of the frame.
This replaced an earlier ground→hub linear interpolation placeholder: the bars
now show a physically-grounded per-segment torque (steps at driving rings,
torsional dynamics), not a straight-line guess. Per-segment (S1..Sn) to align
with the tension chain beside it.
"""
function torque_chain!(gp, ext_frames_obs, palette::DashboardPalette;
                        n_segments::Int=11, seg_labels::Vector{String}=["S$i" for i in 1:n_segments])
    ax = Axis(gp; yreversed=true, backgroundcolor=palette.PANEL,
        xlabel="τ N·m", ylabel="Seg",
        xticklabelsize=7, yticklabelsize=7,
        xtickcolor=palette.INK_DIM, ytickcolor=palette.INK_DIM,
        yticklabelcolor=palette.INK)
    # Heights are a bound Observable so `heights[] = vals` updates bar LENGTHS.
    # (Setting bars[1] would move the bar POSITIONS off-axis — the old bug.)
    heights = Observable(zeros(n_segments))
    bars = barplot!(ax, 1:n_segments, heights; direction=:x,
        color=palette.ACCENT, strokewidth=0, inspectable=true,
        inspector_label=(pl, i, pos) -> (1 <= i <= length(seg_labels) ?
            "$(seg_labels[i]): $(round(heights[][i]; digits=1)) N·m" : ""))
    ylims!(ax, 0.5, n_segments+0.5)
    ax.yticks = (1:n_segments, seg_labels)

    on(ext_frames_obs) do efs
        isempty(efs) && return
        ef = efs[end]
        n = min(length(ef.segment_torque), n_segments)
        vals = abs.(ef.segment_torque[1:n])
        mx = maximum(vals; init=1.0)
        append!(vals, zeros(n_segments - n))
        heights[] = vals
        xlims!(ax, 0, mx > 0 ? mx * 1.15 : 1.0)
    end

    return ax
end

"""
    ring_health!(gp, ext_frames_obs, palette; n_rings, ring_labels, exp_rings)

Per-ring structural health bars. Colour-coded: green (FoS≥2), orange (FoS≥1), red (FoS<1).
Diamond markers on expansion rotor rings.
"""
function ring_health!(gp, ext_frames_obs, palette::DashboardPalette;
                      n_rings::Int=12, ring_labels::Vector{String}=["R$i" for i in 1:n_rings],
                      exp_rings::Vector{Int}=Int[])
    ax = Axis(gp; yreversed=true, backgroundcolor=palette.PANEL,
        xlabel="buckle util (N/Pcr)", ylabel="Ring",
        xticklabelsize=7, yticklabelsize=7,
        xtickcolor=palette.INK_DIM, ytickcolor=palette.INK_DIM,
        yticklabelcolor=palette.INK, spinewidth=0.5)
    heights = Observable(zeros(n_rings))
    colors  = Observable(RGBAf[RGBAf(palette.GREEN) for _ in 1:n_rings])
    bars = barplot!(ax, 1:n_rings, heights; direction=:x, strokewidth=0, color=colors,
        inspectable=true,
        inspector_label=(pl, i, pos) -> (1 <= i <= length(ring_labels) ?
            "$(ring_labels[i]): buckle util $(round(heights[][i]; digits=2)) (N/Pcr)" : ""))
    ylims!(ax, 0.5, n_rings+0.5); xlims!(ax, 0, 1.0)
    ax.yticks = (1:n_rings, ring_labels)

    # Expansion rotor diamond markers
    for ri in exp_rings
        1 <= ri <= n_rings && scatter!(ax, [0.02], [Float64(ri)];
            color=palette.ACCENT, marker=:diamond, markersize=10)
    end

    # Live update handler — reads from ext_frames_obs
    on(ext_frames_obs) do efs
        fi = length(efs)
        fi < 1 && return
        ef = efs[end]  # latest frame
        n = min(length(ef.ring_fos), n_rings)
        vals = Float64[]
        cols = RGBAf[]
        for i in 1:n
            ratio = ef.ring_Pcrit[i] > 0 ? ef.ring_Ncomp[i] / ef.ring_Pcrit[i] : 0.0
            push!(vals, max(ratio, 0.0))
            push!(cols, ef.ring_fos[i] >= 2.0 ? palette.GREEN :
                       ef.ring_fos[i] >= 1.0 ? palette.ORANGE : palette.RED)
        end
        mx = maximum(vals; init=0.0)
        append!(vals, zeros(n_rings - n))
        append!(cols, [palette.INK_FAINT for _ in 1:(n_rings - n)])
        heights[] = vals
        colors[] = RGBAf.(cols)
        xlims!(ax, 0, max(mx * 1.25, 0.05))   # autoscale so light-load bars stay visible
    end

    return ax
end

"""
    tension_chain!(gp, ext_frames_obs, palette; n_segments, swl)

Vertical bar chart of average tension per segment. Bar colours use the SAME
`_tension_color(T, TETHER_SWL)` ramp as the 3D viewport tether lines (grey when
slack <5N, then blue→green→orange→red as T/SWL → 1.0), so a segment's bar colour
matches its line colour in the 3D scene. Dashed SWL line at the specified value.
"""
function tension_chain!(gp, ext_frames_obs, palette::DashboardPalette;
                         n_segments::Int=11, swl::Float64=15.0)
    ax = Axis(gp; yreversed=true, backgroundcolor=palette.PANEL,
        xlabel="T kN", ylabel="Seg",
        xticklabelsize=7, yticklabelsize=7,
        xtickcolor=palette.INK_DIM, ytickcolor=palette.INK_DIM,
        yticklabelcolor=palette.INK)
    seg_labels = ["S$i" for i in 1:n_segments]
    heights = Observable(zeros(n_segments))
    colors  = Observable(RGBAf[RGBAf(palette.GREEN) for _ in 1:n_segments])
    bars = barplot!(ax, 1:n_segments, heights;
        direction=:x, strokewidth=0, color=colors, inspectable=true,
        inspector_label=(pl, i, pos) -> (1 <= i <= length(seg_labels) ?
            "$(seg_labels[i]): $(round(heights[][i]; digits=2)) kN" : ""))
    ylims!(ax, 0.5, n_segments+0.5)
    ax.yticks = (1:n_segments, seg_labels)
    vlines!(ax, [swl]; color=palette.RED, linestyle=:dash, linewidth=1.5)

    on(ext_frames_obs) do efs
        fi = length(efs)
        fi < 1 && return
        ef = efs[end]
        n = min(length(ef.segment_tension), n_segments)
        Tn = ef.segment_tension[1:n]        # Newtons (for colour ramp)
        Tv = Tn ./ 1000.0                    # kN (for bar length)
        mx = maximum(Tv; init=0.0)
        # Same ramp as the 3D viewport tether lines → bar colour matches line colour.
        sc = [_tension_color(t, Float64(TETHER_SWL)) for t in Tn]
        append!(Tv, zeros(n_segments - n))
        append!(sc, [palette.INK_FAINT for _ in 1:(n_segments - n)])
        heights[] = Tv
        colors[] = RGBAf.(sc)
        xlims!(ax, 0, max(mx * 1.25, swl * 1.15))   # autoscale, keep SWL line in view
    end

    return ax
end

"""
    twist_view!(gp, ext_frames_obs, palette; n_segments)

Polar view looking down the shaft axis. Each segment's cumulative twist angle is
a radial line; colour shifts from cyan (ground) to orange (hub). The title shows
the total accumulated |Δα|. Live-updates from `segment_twist_deg`.
"""
function twist_view!(gp, ext_frames_obs, palette::DashboardPalette; n_segments::Int=11)
    ax = Axis(gp; aspect=DataAspect(), backgroundcolor=palette.PANEL,
        title="Σ|Δα|=0°", titlesize=9, titlecolor=palette.INK_DIM)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -1.3, 1.3, -1.3, 1.3)

    # Reference circles
    for r in [0.3, 0.6, 0.9, 1.2]
        θ_c = range(0, 2π; length=100)
        lines!(ax, r .* cos.(θ_c), r .* sin.(θ_c);
            color=palette.EDGE, linewidth=0.5)
    end

    # Pre-create one radial line + tip marker per segment (updated live).
    seg_pts = Vector{Observable}(undef, n_segments)
    for i in 1:n_segments
        f = (i - 1) / max(n_segments - 1, 1)
        col = RGBf(0.0 + 0.7 * f, 0.8 - 0.3 * f, 1.0 - 0.5 * f)  # cyan→orange
        pts = Observable(([0.0, 0.0], [0.0, 0.0]))
        seg_pts[i] = pts
        lines!(ax, lift(q -> q[1], pts), lift(q -> q[2], pts); color=col, linewidth=2.5)
    end

    # Ground marker
    scatter!(ax, [0.0], [0.0]; color=palette.ACCENT, markersize=10, marker=:star5)
    text!(ax, 0, -0.15; text="GND", align=(:center,:center),
        fontsize=8, color=palette.INK_FAINT)

    on(ext_frames_obs) do efs
        isempty(efs) && return
        tw = efs[end].segment_twist_deg
        m = min(length(tw), n_segments)
        cum = cumsum(tw)
        for i in 1:m
            θ = deg2rad(cum[i])
            seg_pts[i][] = ([0.0, 1.2 * cos(θ)], [0.0, 1.2 * sin(θ)])
        end
        for i in (m+1):n_segments
            seg_pts[i][] = ([0.0, 0.0], [0.0, 0.0])
        end
        ax.title = @sprintf("Σ|Δα|=%.0f°", sum(abs, tw))
    end

    return ax
end

"""
    rotor_gauges!(gp, ext_frames_obs, palette; labels, P_rated_kw)

Concentric-arc rotor power gauges, stacked vertically (order follows `labels`,
hub first as produced by `capture_extended`). Outer cyan arc = aerodynamic
power, inner green arc = ground (delivered) power, both as a fraction of the
per-rotor rated scale (P_rated_kw / n_rotors). Centre shows delivered power in
kW (big), with an "aero X.X · η YY%" sub-line. Live-updates from
`rotor_aero_power` / `rotor_ground_power` (both kW).
"""
function rotor_gauges!(gp, ext_frames_obs, palette::DashboardPalette;
                       labels::Vector{String}=["Hub"], P_rated_kw::Float64=50.0,
                       horizontal::Bool=false)
    n = length(labels)
    max_radius = 0.42
    inner_r    = max_radius * 0.62
    θ0    = deg2rad(225.0)
    sweep = deg2rad(270.0)
    n_pts = 80
    P_scale = max(P_rated_kw / max(n, 1), 0.1)
    # Big fonts when dials sit side-by-side (horizontal); smaller when stacked in a
    # narrow column so the kW readout fits inside each dial.
    fs_kw  = horizontal ? 24 : 18
    fs_lbl = horizontal ? 13 : 11
    fs_sub = horizontal ? 10 : 8

    aero_obs   = Vector{Observable}(undef, n)
    ground_obs = Vector{Observable}(undef, n)
    kw_obs     = Vector{Observable}(undef, n)
    sub_obs    = Vector{Observable}(undef, n)

    for (i, lbl) in enumerate(labels)
        # Horizontal: dials sit side-by-side (big, readable). Vertical: stacked.
        cell = horizontal ? gp[1, i] : gp[i, 1]
        ax = Axis(cell; aspect=DataAspect(), backgroundcolor=palette.PANEL,
            xgridvisible=false, ygridvisible=false)
        hidedecorations!(ax); hidespines!(ax)
        limits!(ax, -0.55, 0.55, -0.55, 0.55)

        # Static track arc
        θ_track = range(θ0, θ0 - sweep; length=n_pts)
        lines!(ax, max_radius .* cos.(θ_track), max_radius .* sin.(θ_track);
            color=palette.EDGE, linewidth=5)

        # Outer arc = aerodynamic power (cyan); inner arc = delivered/ground power (green).
        ap = Observable(([0.0], [0.0])); aero_obs[i]   = ap
        gpts = Observable(([0.0], [0.0])); ground_obs[i] = gpts
        lines!(ax, lift(a -> a[1], ap),   lift(a -> a[2], ap);   color=palette.ACCENT, linewidth=5)
        lines!(ax, lift(g -> g[1], gpts), lift(g -> g[2], gpts); color=palette.GREEN,  linewidth=5)

        # Centre readout: delivered power in kW (big), aero + efficiency (small sub-line).
        kt = Observable("0.0"); kw_obs[i] = kt
        text!(ax, 0, 0.14; text=kt, align=(:center, :center),
            fontsize=fs_kw, color=palette.INK, font=:bold)
        text!(ax, 0, -0.04; text="kW out", align=(:center, :center),
            fontsize=fs_sub, color=palette.INK_DIM)
        st = Observable("aero 0.0 · η 0%"); sub_obs[i] = st
        text!(ax, 0, -0.20; text=st, align=(:center, :center),
            fontsize=fs_sub, color=palette.INK_FAINT)
        text!(ax, 0, -0.38; text=lbl, align=(:center, :center),
            fontsize=fs_lbl, color=palette.INK_DIM, font=:bold)
    end

    on(ext_frames_obs) do efs
        isempty(efs) && return
        ef = efs[end]
        for i in 1:n
            i > length(ef.rotor_aero_power) && continue
            aero = ef.rotor_aero_power[i]   # kW
            grnd = ef.rotor_ground_power[i] # kW (delivered)
            fa = clamp(aero / P_scale, 0.0, 1.0)
            na = max(2, round(Int, n_pts * fa))
            θa = range(θ0, θ0 - sweep * fa; length=na)
            aero_obs[i][] = (max_radius .* cos.(θa), max_radius .* sin.(θa))
            fg = clamp(grnd / P_scale, 0.0, 1.0)
            ng = max(2, round(Int, n_pts * fg))
            θg = range(θ0, θ0 - sweep * fg; length=ng)
            ground_obs[i][] = (inner_r .* cos.(θg), inner_r .* sin.(θg))
            eff = aero > 0.01 ? grnd / aero * 100.0 : 0.0
            kw_obs[i][]  = @sprintf("%.1f", grnd)
            sub_obs[i][] = @sprintf("aero %.1f · η %.0f%%", aero, eff)
        end
    end

    return nothing
end

"""
    config_panel!(gp, ext_frames_obs, palette; config_name, scenario_name, v_ref) -> NamedTuple

Config & controls panel. Interactive `Menu` widgets for the active design /
scenario / generator / payout, plus a live "Run Peaks" line (current P, ω, T
from the base frame) and a live regen-state line (brake + warning flags).

Returns `(design=…, scenario=…, generator=…, payout=…, peak_lbl=…, state_lbl=…)`
so the caller can wire menu `.selection` observables (e.g. to the event log or a
live rerun). The menus are selectable now; live rerun wiring is deferred.
"""
function config_panel!(gp, ext_frames_obs, palette::DashboardPalette;
                       config_name::String="V10 Tight",
                       scenario_name::String="Cruise",
                       v_ref::Float64=11.0)
    lblkw = (; fontsize=9, color=palette.INK_DIM, halign=:left, tellwidth=false)
    Label(gp[1, 1:2], "⚙ CONFIG"; fontsize=10, color=palette.ACCENT, font=:bold, halign=:left, tellwidth=false)

    Label(gp[2, 1], "Design"; lblkw...)
    design_menu = Menu(gp[2, 2]; options=unique([config_name, "V10 Tight", "V5 Baseline", "Canonical 5-line"]),
                       default=config_name, fontsize=9, width=120)
    Label(gp[3, 1], "Scenario"; lblkw...)
    scenario_m  = Menu(gp[3, 2]; options=["Cruise", "Gust", "Ramp-up", "Depower", "Storm"],
                       default=scenario_name, fontsize=9, width=120)
    Label(gp[4, 1], "Generator"; lblkw...)
    gen_menu    = Menu(gp[4, 2]; options=["Standard", "High-k MPPT", "Stall-regulated"],
                       default="Standard", fontsize=9, width=120)
    Label(gp[5, 1], "Payout"; lblkw...)
    payout_menu = Menu(gp[5, 2]; options=["25 m", "40 m", "60 m"],
                       default="25 m", fontsize=9, width=120)

    Label(gp[6, 1:2], "── Run Peaks ──"; fontsize=9, font=:bold, color=palette.INK, halign=:left, tellwidth=false)
    peak_lbl  = Label(gp[7, 1:2], "P 0kW · ω 0rpm · T 0N"; fontsize=8, color=palette.INK_DIM, halign=:left, tellwidth=false)
    fos_lbl   = Label(gp[8, 1:2], "FoS ∞ · V 0 · Slack 0"; fontsize=8, color=palette.INK_DIM, halign=:left, tellwidth=false)
    Label(gp[9, 1:2], "── Regen State ──"; fontsize=9, font=:bold, color=palette.INK, halign=:left, tellwidth=false)
    state_lbl = Label(gp[10, 1:2], "Brake:OFF  Buckle:OK  Slack:OK  State:IDLE"; fontsize=8, color=palette.INK_DIM, halign=:left, tellwidth=false)

    on(ext_frames_obs) do efs
        isempty(efs) && return
        b = efs[end].base
        rpm = abs(b.omega_hub) * 60 / (2π)
        peak_lbl.text[] = @sprintf("P %.2fkW · ω %.0frpm · T %.0fN", b.P_kw, rpm, b.T_max)
        fos_lbl.text[]  = @sprintf("FoS %s · V %.1f · Slack %d", fos_str(b.fos_tether), b.V_hub, b.n_slack)
        state_lbl.text[] = @sprintf("Brake:%s  Buckle:%s  Slack:%s  State:%s",
            b.brake_engaged ? "ON" : "OFF",
            b.buckling_risk ? "WARN" : "OK",
            b.line_slack ? "WARN" : "OK",
            b.brake_engaged ? "BRAKE" : "RUN")
    end

    return (design=design_menu, scenario=scenario_m, generator=gen_menu,
            payout=payout_menu, peak_lbl=peak_lbl, state_lbl=state_lbl)
end
