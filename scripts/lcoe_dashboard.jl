#!/usr/bin/env julia
# scripts/lcoe_dashboard.jl
# Standalone interactive GLMakie dashboard for TRPT kite turbine economics.
#
# Shows live LCOE, cost breakdown pie chart, competitor comparison bar chart,
# and sensitivity sliders (capacity factor, discount rate, PPA price, asset life).
#
# Usage:
#   julia --project=. scripts/lcoe_dashboard.jl

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using GLMakie
using Printf

# ── Dashboard theme ─────────────────────────────────────────────────────────────

set_theme!(theme_dark())

# Increase default font size for readability
update_theme!(; fontsize=14)

# ── Data helpers ────────────────────────────────────────────────────────────────

function format_currency(val::Float64)::String
    if abs(val) >= 1_000_000.0
        return @sprintf("£%.2fM", val / 1_000_000.0)
    elseif abs(val) >= 1_000.0
        return @sprintf("£%.0f", val)
    else
        return @sprintf("£%.0f", val)
    end
end

function compute_all_metrics(
    p,
    cm::Economics.CostModel;
    cf::Float64=0.30,
    discount_rate::Float64=0.07,
    ppa_price_p_kwh::Float64=8.0,
    life_years::Float64=20.0,
)
    lcoe = Economics.compute_lcoe(p, cm; cf, discount_rate, life_years)
    capital = Economics.compute_capital_cost(p, cm)
    annual_mwh = Economics.compute_annual_energy(p, cf)
    annual_rev = Economics.compute_annual_revenue(p, ppa_price_p_kwh, cf)
    carbon = Economics.compute_carbon(p, cm; cf, life_years)
    breakdown = Economics.compute_cost_breakdown(p, cm)

    return (;
        lcoe, capital, annual_mwh, annual_rev, carbon, breakdown, lcoe_p_kwh=lcoe / 10.0
    )
end

# ── Build dashboard ─────────────────────────────────────────────────────────────

function build_lcoe_dashboard()
    # Base parameters — v5 optimized 10 kW octagon
    p = params_v5_10kw()
    cm = Economics.default_cost_model_2026()

    # Initial slider values
    cf0 = 0.30
    discount_rate0 = 0.07
    ppa0 = 8.0   # p/kWh
    life0 = 20.0  # years

    metrics = compute_all_metrics(
        p, cm; cf=cf0, discount_rate=discount_rate0, ppa_price_p_kwh=ppa0, life_years=life0
    )

    # ── Figure layout ───────────────────────────────────────────────────────

    fig = Figure(; size=(1600, 900))

    # Title
    Label(
        fig[1, 1:2],
        "TRPT Kite Turbine — Economics Dashboard";
        fontsize=24,
        font=:bold,
        color=:white,
    )
    Label(
        fig[2, 1:2],
        "V5 Optimized 10 kW Octagon · 8 lines · 1.60 m hub · 30 m tether";
        fontsize=14,
        color=:gray70,
    )

    # ── LEFT PANEL: Key Metrics ─────────────────────────────────────────────

    metrics_ax = Axis(
        fig[3, 1];
        title="Key Metrics",
        xgridvisible=false,
        ygridvisible=false,
        xticklabelsvisible=false,
        yticklabelsvisible=false,
        leftspinevisible=false,
        rightspinevisible=false,
        topspinevisible=false,
        bottomspinevisible=false,
    )
    xlims!(metrics_ax, 0, 1)
    ylims!(metrics_ax, 0, 1)

    # Create metric text labels
    metric_texts = [
        ("LCOE", @sprintf("%.2f p/kWh", metrics.lcoe_p_kwh)),
        ("Capital Cost", format_currency(metrics.capital)),
        ("Annual Energy", @sprintf("%.0f MWh", metrics.annual_mwh)),
        ("Annual Revenue", format_currency(metrics.annual_rev)),
        ("CO₂ Offset", @sprintf("%.1f t/yr", metrics.carbon.annual_offset_kg / 1000.0)),
        ("Carbon Payback", @sprintf("%.0f months", metrics.carbon.payback_months)),
        ("Embodied CO₂", @sprintf("%.2f g/kWh", metrics.carbon.embodied_per_kwh)),
    ]

    metric_labels = Vector{Any}(undef, length(metric_texts))
    metric_values = Vector{Any}(undef, length(metric_texts))

    y_positions = range(0.85, 0.15; length=length(metric_texts))
    for (i, (label, value)) in enumerate(metric_texts)
        metric_labels[i] = Label(
            fig[3, 1][i, 1], label; font=:bold, color=:gray60, halign=:left, fontsize=14
        )
        metric_values[i] = Label(
            fig[3, 1][i, 2], value; color=:white, font=:bold, halign=:right, fontsize=18
        )
    end

    colsize!(fig.layout, 1, Relative(0.22))

    # ── CENTER-TOP: Cost Breakdown Pie ──────────────────────────────────────

    breakdown_ax = Axis(fig[3, 2]; title="Capital Cost Breakdown", aspect=DataAspect())

    # Cost breakdown data
    bd = metrics.breakdown
    cost_items = [
        ("CFRP Tubes", bd.cfrp_tubes),
        ("Dyneema Lines", bd.dyneema),
        ("Knuckles", bd.knuckles),
        ("Rotor Blades", bd.blades),
        ("Generator", bd.generator),
        ("Ground Station", bd.ground_station),
        ("Lift Kite", bd.lift_kite),
        ("Installation", bd.installation),
        ("Grid Connect", bd.grid_connection),
    ]

    # Filter out near-zero items for cleaner display
    cost_items_filtered = [(l, v) for (l, v) in cost_items if v > 1.0]
    cost_labels = [l for (l, _) in cost_items_filtered]
    cost_values = [v for (_, v) in cost_items_filtered]

    pie_colors = Makie.wong_colors()
    pie = pie!(
        breakdown_ax,
        cost_values;
        color=pie_colors[1:length(cost_values)],
        strokecolor=:black,
        strokewidth=1.5,
    )
    # Hide axis decorations on pie
    hidedecorations!(breakdown_ax)
    hidespines!(breakdown_ax)

    # Pie legend
    Legend(
        fig[4, 2],
        pie,
        cost_labels;
        orientation=:horizontal,
        nbanks=3,
        labelsize=11,
        rowgap=2,
    )

    rowsize!(fig.layout, 4, Relative(0.06))

    # ── CENTER-BOTTOM: Competitor Comparison Bar Chart ───────────────────────

    comp_ax = Axis(
        fig[5, 1:2];
        title="LCOE Competitor Comparison",
        ylabel="LCOE (p/kWh)",
        xticklabelrotation=pi/6,
        xticklabelsize=11,
    )

    comp_df = Economics.competitor_comparison()
    n_comp = nrow(comp_df)

    # Color palette — green shades for kites, standard for others
    comp_colors = [
        :lightgreen,    # Kite 10kW
        :green3,        # Kite 50kW
        :gold,          # Solar
        :deepskyblue,   # Onshore Wind
        :steelblue,     # Offshore Wind
        :tomato,        # Gas
        :mediumpurple,  # Nuclear
    ]

    # Remove newlines from labels for display
    tech_labels = replace.(comp_df.Technology, "\n" => " ")

    barplot!(
        comp_ax,
        1:n_comp,
        comp_df.LCOE_p_kWh;
        color=comp_colors[1:n_comp],
        strokecolor=:white,
        strokewidth=1,
    )

    # Annotate LCOE values on top of bars
    for i in 1:n_comp
        text!(
            comp_ax,
            i,
            comp_df.LCOE_p_kWh[i] + 0.5;
            text=@sprintf("%.1fp", comp_df.LCOE_p_kWh[i]),
            align=(:center, :bottom),
            fontsize=11,
            color=:white,
        )
    end

    comp_ax.xticks = (1:n_comp, tech_labels)
    ylims!(comp_ax, 0, 18)

    # ── RIGHT PANEL: Sensitivity Sliders ────────────────────────────────────

    slider_label_ax = Axis(
        fig[3, 3];
        title="Sensitivity",
        xgridvisible=false,
        ygridvisible=false,
        xticklabelsvisible=false,
        yticklabelsvisible=false,
        leftspinevisible=false,
        rightspinevisible=false,
        topspinevisible=false,
        bottomspinevisible=false,
    )
    xlims!(slider_label_ax, 0, 1)
    ylims!(slider_label_ax, 0, 1)

    # Slider container — use the Figure's layout grid
    sg = SliderGrid(
        fig[4, 3],
        (label="Capacity Factor", range=0.15:0.01:0.50, startvalue=cf0, format="{:.0f}%"),
        (
            label="Discount Rate",
            range=0.03:0.005:0.15,
            startvalue=discount_rate0,
            format="{:.1f}%",
        ),
        (label="PPA Price (p/kWh)", range=3.0:0.5:15.0, startvalue=ppa0, format="{:.1f}p"),
        (label="Asset Life (years)", range=10:1:30, startvalue=life0, format="{:.0f} yr"),
    )

    set_close_to!(sg.sliders[1].slider, cf0)
    set_close_to!(sg.sliders[2].slider, discount_rate0)
    set_close_to!(sg.sliders[3].slider, ppa0)
    set_close_to!(sg.sliders[4].slider, life0)

    # Display slider readouts
    slider_readouts = Vector{Any}(undef, 4)
    for i in 1:4
        slider_readouts[i] = Label(
            fig[4, 3][i, 2],
            sg.sliders[i].value_formatter(sg.sliders[i].slider.value);
            color=:white,
            font=:bold,
            fontsize=16,
        )
    end

    # ── Connect sliders to metric updates ───────────────────────────────────

    on(sg.sliders[1].slider.value) do v
        cf_val = v / 100.0   # stored as percentage
        m = compute_all_metrics(
            p,
            cm;
            cf=cf_val,
            discount_rate=sg.sliders[2].slider.value[] / 100.0,
            ppa_price_p_kwh=sg.sliders[3].slider.value[],
            life_years=sg.sliders[4].slider.value[],
        )
        _update_metrics!(metric_values, m)
        _update_pie!(pie, m.breakdown)
        # update readout
        return slider_readouts[1].text = @sprintf("%.0f%%", v)
    end

    on(sg.sliders[2].slider.value) do v
        dr_val = v / 100.0
        m = compute_all_metrics(
            p,
            cm;
            cf=sg.sliders[1].slider.value[] / 100.0,
            discount_rate=dr_val,
            ppa_price_p_kwh=sg.sliders[3].slider.value[],
            life_years=sg.sliders[4].slider.value[],
        )
        _update_metrics!(metric_values, m)
        return slider_readouts[2].text = @sprintf("%.1f%%", v)
    end

    on(sg.sliders[3].slider.value) do v
        m = compute_all_metrics(
            p,
            cm;
            cf=sg.sliders[1].slider.value[] / 100.0,
            discount_rate=sg.sliders[2].slider.value[] / 100.0,
            ppa_price_p_kwh=v,
            life_years=sg.sliders[4].slider.value[],
        )
        _update_metrics!(metric_values, m)
        return slider_readouts[3].text = @sprintf("%.1fp", v)
    end

    on(sg.sliders[4].slider.value) do v
        m = compute_all_metrics(
            p,
            cm;
            cf=sg.sliders[1].slider.value[] / 100.0,
            discount_rate=sg.sliders[2].slider.value[] / 100.0,
            ppa_price_p_kwh=sg.sliders[3].slider.value[],
            life_years=Float64(v),
        )
        _update_metrics!(metric_values, m)
        return slider_readouts[4].text = @sprintf("%.0f yr", v)
    end

    # ── Row sizing ──────────────────────────────────────────────────────────

    rowsize!(fig.layout, 1, Relative(0.06))
    rowsize!(fig.layout, 2, Relative(0.03))
    rowsize!(fig.layout, 3, Relative(0.40))
    rowsize!(fig.layout, 5, Relative(0.38))

    colsize!(fig.layout, 3, Relative(0.18))

    return fig
end

# ── Update helpers ──────────────────────────────────────────────────────────────

function _update_metrics!(metric_values, m)
    new_vals = [
        @sprintf("%.2f p/kWh", m.lcoe_p_kwh),
        format_currency(m.capital),
        @sprintf("%.0f MWh", m.annual_mwh),
        format_currency(m.annual_rev),
        @sprintf("%.1f t/yr", m.carbon.annual_offset_kg / 1000.0),
        @sprintf("%.0f months", m.carbon.payback_months),
        @sprintf("%.2f g/kWh", m.carbon.embodied_per_kwh),
    ]
    for (i, val) in enumerate(new_vals)
        metric_values[i].text = val
    end
end

function _update_pie!(pie, bd)
    cost_items = [
        bd.cfrp_tubes,
        bd.dyneema,
        bd.knuckles,
        bd.blades,
        bd.generator,
        bd.ground_station,
        bd.lift_kite,
        bd.installation,
        bd.grid_connection,
    ]
    filtered = [v for v in cost_items if v > 1.0]
    pie[1][] = filtered
    return notify(pie[1])
end

# ── Main ────────────────────────────────────────────────────────────────────────

function main()
    println("Building TRPT Economics Dashboard...")
    println("  Configuration: V5 optimized 10 kW octagon")
    println("  Cost model: 2026 pilot-production pricing")

    cm = Economics.default_cost_model_2026()
    p = params_v5_10kw()
    lcoe = Economics.compute_lcoe(p, cm)
    println(
        "  Baseline LCOE: £$(round(lcoe, digits=2))/MWh = $(round(lcoe/10, digits=2))p/kWh"
    )

    capital = Economics.compute_capital_cost(p, cm)
    println("  Capital cost:  $(format_currency(capital))")
    println()

    fig = build_lcoe_dashboard()
    display(fig)
    println("Dashboard open. Adjust sliders to explore sensitivities. Ctrl+C to quit.")
    return wait(fig.scene)
end

main()
