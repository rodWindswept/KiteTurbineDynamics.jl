# charts/theme.jl
# Makie theme and helpers implementing KTD.jl Reporting Chart Standards

module KTDTheme

using TOML
using CairoMakie
using Printf

export ktd_theme, ktd_figure, provenance_footer!, confidence_badge!, consistency_stamp!, rpm_twin_axis!
export get_design_color, get_threshold_color, get_confidence_style

const SPEC_PATH = joinpath(@__DIR__, "chart-spec.toml")

"""
    ktd_theme([spec_path]) -> Theme

Returns a Makie Theme built from the chart specifications.
"""
function ktd_theme(spec_path::String=SPEC_PATH)
    spec = TOML.parsefile(spec_path)
    font_sans = spec["fonts"]["sans"]
    min_size = spec["fonts"]["min_size"]
    
    Theme(
        font = font_sans,
        fontsize = min_size,
        Axis = (
            xgridvisible = true,
            ygridvisible = true,
            xgridcolor = (:black, 0.08),
            ygridcolor = (:black, 0.08),
            topspinevisible = false,
            rightspinevisible = false,
            bottomspinecolor = :black,
            leftspinecolor = :black,
            xlabelpadding = 5,
            ylabelpadding = 5,
        ),
        Legend = (
            framevisible = false,
            labelsize = min_size,
            titlesize = min_size,
        )
    )
end

"""
    ktd_figure([spec_path]; kwargs...) -> Figure

Creates a Makie Figure styled with the KTD theme.
"""
function ktd_figure(spec_path::String=SPEC_PATH; kwargs...)
    theme = ktd_theme(spec_path)
    # White background per PRD — set at construction; assigning a Symbol to the
    # scene's backgroundcolor Observable{RGBAf} after the fact is a type error.
    fig = with_theme(theme) do
        Figure(; backgroundcolor=:white, kwargs...)
    end
    return fig
end

"""
    provenance_footer!(fig, script_path, git_hash, csv_path, model_desc)

Adds a standardized provenance line at the bottom of the figure.
"""
function provenance_footer!(
    fig::Figure, script_path::String, git_hash::String, csv_path::String, model_desc::String
)
    date_str = Libc.strftime("%Y-%m-%d", time())
    footer_text = "$script_path @ $git_hash · $(basename(csv_path)) · $model_desc · $date_str"
    
    # Add label in a new row at the bottom spanning all columns
    Label(fig[end+1, :], footer_text, halign=:left, fontsize=8, color=:gray, padding=(5, 5, 5, 5))
end

"""
    confidence_badge!(ax, tier; [position])

Annotates the axis with a standardized confidence badge (H, M, P, or X).
"""
function confidence_badge!(ax, tier::Symbol; spec_path::String=SPEC_PATH, position=:top_right)
    spec = TOML.parsefile(spec_path)
    tier_str = string(tier)
    if !haskey(spec["confidence"], tier_str)
        error("Confidence tier :$tier not found in spec. Available: H, M, P, X")
    end
    badge_char = spec["confidence"][tier_str]["badge"]
    
    x, y = if position == :top_right
        0.95, 0.95
    elseif position == :top_left
        0.05, 0.95
    elseif position == :bottom_right
        0.95, 0.05
    elseif position == :bottom_left
        0.05, 0.05
    else
        error("Invalid position: $position")
    end
    
    align = if position == :top_right
        (:right, :top)
    elseif position == :top_left
        (:left, :top)
    elseif position == :bottom_right
        (:right, :bottom)
    elseif position == :bottom_left
        (:left, :bottom)
    end
    
    # Makie has no `fontweight` kwarg — bold is selected via font=:bold
    text!(ax, x, y, text="[$badge_char]", space=:relative, align=align,
          fontsize=10, font=:bold, color=:black)
end

"""
    consistency_stamp!(ax, type, val; [position])

Adds a consistency stamp (e.g., P/kω³ ratio or energy conservation check).
"""
function consistency_stamp!(ax, type::Symbol, val; position=:bottom_left, spec_path::String=SPEC_PATH)
    passing = true
    stamp_text = if type == :power
        # PRD §3.4: tick ONLY within tolerance; a failing stamp blocks publication
        passing = abs(val - 1.0) <= 0.01
        @sprintf("P/kω³ = %.2f %s", val, passing ? "✓" : "✗ FAIL")
    elseif type == :energy
        string(val)
    else
        string(val)
    end
    
    x, y = if position == :top_right
        0.95, 0.95
    elseif position == :top_left
        0.05, 0.95
    elseif position == :bottom_right
        0.95, 0.05
    elseif position == :bottom_left
        0.05, 0.05
    else
        error("Invalid position: $position")
    end
    
    align = if position == :top_right
        (:right, :top)
    elseif position == :top_left
        (:left, :top)
    elseif position == :bottom_right
        (:right, :bottom)
    elseif position == :bottom_left
        (:left, :bottom)
    end
    
    color = passing ? :gray30 : TOML.parsefile(spec_path)["thresholds"]["limit"]
    text!(ax, x, y, text=stamp_text, space=:relative, align=align,
          fontsize=9, color=color, font=passing ? :regular : :bold)
    return passing
end

"""
    rpm_twin_axis!(ax; axis=:x) -> Axis

Twin axis in rpm for THE ANGULAR-SPEED AXIS ONLY (PRD §3.1: the sole permitted
dual-axis use is rad/s–rpm of the same quantity). `axis=:x` twins the x-axis
(P(ω) plots); `axis=:y` only if ω is on the y-axis. Twinning a power/force
axis is a standards violation.
"""
function rpm_twin_axis!(ax; axis::Symbol=:x)
    fig = ax.parent
    # Grid position of the primary axis (ax.layoutgeom is not a Makie API)
    gc = CairoMakie.Makie.GridLayoutBase.gridcontent(ax)
    slot = fig[gc.span.rows, gc.span.cols]
    fmt = ticks -> [@sprintf("%.0f", t * 60 / (2π)) for t in ticks]

    if axis == :x
        ax_twin = Axis(slot, xaxisposition=:top)
        linkxaxes!(ax, ax_twin)
        hideydecorations!(ax_twin)
        hidespines!(ax_twin, :l, :r, :b)   # spine sides are :l/:r/:t/:b, not compass points
        ax_twin.xtickformat = fmt
        ax_twin.xlabel = "ω (rpm)"
    elseif axis == :y
        ax_twin = Axis(slot, yaxisposition=:right)
        linkyaxes!(ax, ax_twin)
        hidexdecorations!(ax_twin)
        hidespines!(ax_twin, :t, :b, :l)
        ax_twin.ytickformat = fmt
        ax_twin.ylabel = "ω (rpm)"
    else
        error("axis must be :x or :y, got :$axis")
    end
    return ax_twin
end

# Helper getters to load values dynamically from TOML

function get_design_color(design_name::Symbol, spec_path::String=SPEC_PATH)
    spec = TOML.parsefile(spec_path)
    return spec["designs"][string(design_name)]
end

function get_threshold_color(threshold_type::Symbol, spec_path::String=SPEC_PATH)
    spec = TOML.parsefile(spec_path)
    return spec["thresholds"][string(threshold_type)]
end

function get_confidence_style(tier::Symbol, spec_path::String=SPEC_PATH)
    spec = TOML.parsefile(spec_path)
    t = spec["confidence"][string(tier)]
    return (
        linestyle = Symbol(t["linestyle"]),
        marker = Symbol(t["marker"]),
        color = haskey(t, "color") ? t["color"] : nothing
    )
end

end # module
