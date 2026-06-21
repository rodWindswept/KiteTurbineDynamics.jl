#!/usr/bin/env julia
# scripts/plot_v10_landscape.jl — V10 parameter landscape with density surface

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, CSV, DataFrames, Statistics, LinearAlgebra, DelimitedFiles

const OD = joinpath(dirname(@__DIR__), "docs", "awes-forum-diagrams")
const RD = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw")

println("Loading...")
ch = CSV.read(joinpath(RD, "convergence_history.csv"), DataFrame)
pt = CSV.read(joinpath(RD, "parameter_trace.csv"), DataFrame)
pca_mean = vec(readdlm("/tmp/v10_pca_mean.txt"))
pca_std  = vec(readdlm("/tmp/v10_pca_std.txt"))
pca_V    = readdlm("/tmp/v10_pca_V.txt")

function pc_proj(row)
    x = [row.Do_top_m, row.t_over_D, row.beam_aspect, row.Do_scale_exp,
         row.r_hub_m, row.r_bottom_m, row.target_Lr, row.n_lines,
         row.density_profile, row.rotor_mask_proxy, row.bank_top, row.bank_bottom,
         row.lambda_top, row.lambda_bottom]
    xc = (x .- pca_mean) ./ max.(pca_std, 1e-10)
    (dot(xc, pca_V[:,1]), dot(xc, pca_V[:,2]))
end

# Build grid from sample
println("Building grid...")
GRID = 200
pc1_vals, pc2_vals, mass_vals = Float64[], Float64[], Float64[]
step = 5
for i in 1:step:nrow(pt)
    pc1, pc2 = pc_proj(pt[i, :])
    cm = ch[(ch.island .== pt[i,:island]) .& (ch.iteration .== pt[i,:iteration]), :]
    mass = nrow(cm) > 0 ? cm.mass_kg[1] : NaN
    if mass < 200.0
        push!(pc1_vals, pc1); push!(pc2_vals, pc2); push!(mass_vals, mass)
    end
end
println("Points: $(length(mass_vals))")

# Grid bounds
pc1_r = quantile(pc1_vals, [0.02, 0.98])
pc2_r = quantile(pc2_vals, [0.02, 0.98])
pad = (pc1_r[2]-pc1_r[1])*0.1; pc1_r .+= [-pad, pad]
pad = (pc2_r[2]-pc2_r[1])*0.1; pc2_r .+= [-pad, pad]

grid_m = fill(NaN, GRID, GRID)
grid_n = zeros(Int, GRID, GRID)
for k in axes(mass_vals,1)
    i = clamp(floor(Int,(pc1_vals[k]-pc1_r[1])/(pc1_r[2]-pc1_r[1])*GRID)+1, 1, GRID)
    j = clamp(floor(Int,(pc2_vals[k]-pc2_r[1])/(pc2_r[2]-pc2_r[1])*GRID)+1, 1, GRID)
    if isnan(grid_m[i,j]); grid_m[i,j] = mass_vals[k]; else grid_m[i,j] += mass_vals[k]; end
    grid_n[i,j] += 1
end
for i in 1:GRID, j in 1:GRID
    if grid_n[i,j] > 0; grid_m[i,j] /= grid_n[i,j]; end
end
m_min, m_max = minimum(filter(!isnan, grid_m)), maximum(filter(!isnan, grid_m))
println("Mass range: $(round(m_min))-$(round(m_max)) kg")

# Smooth
smooth = copy(grid_m)
for i in 2:GRID-1, j in 2:GRID-1
    w = [grid_m[i+di,j+dj] for di in -1:1, dj in -1:1]
    v = filter(!isnan, vec(w))
    if length(v) >= 4; smooth[i,j] = median(v); end
end
grid_m = smooth

# Write PNG via PPM + convert
println("Writing raster...")
open(joinpath(OD, "v10_landscape.ppm"), "w") do f
    write(f, "P3\n$GRID $GRID\n255\n")
    for j in 1:GRID
        for i in 1:GRID
            m = grid_m[i, GRID-j+1]
            t = isnan(m) ? 0.0 : clamp((m-m_min)/max(m_max-m_min,1), 0, 1)
            r = round(Int, 255*clamp(t<0.5 ? t*2*0.3 : 0.3+(t-0.5)*2*0.7, 0,1))
            g = round(Int, 255*clamp(t<0.5 ? 0.1+t*2*0.7 : 0.8+(t-0.5)*2*0.2, 0,1))
            b = round(Int, 255*clamp(t<0.5 ? 1.0-t*2*0.6 : 0.4-(t-0.5)*2*0.4, 0,1))
            if isnan(m); r=g=b=13; end
            write(f, "$r $g $b ")
        end
        write(f, "\n")
    end
end
run(`python3 -c "from PIL import Image; Image.open('$(joinpath(OD,"v10_landscape.ppm"))').save('$(joinpath(OD,"v10_landscape.png"))'"`)
println("Raster done")

# Trace trajectories (island 30 + best island + a few others)
println("Trajectories...")
traj_data = Dict{Int,Vector{Tuple{Float64,Float64,Float64}}}()
for island in [30, 41, 46, 9, 12, 18, 32, 56, 1, 5, 10, 15, 20, 25, 35, 40, 45, 50, 55, 60]
    pt_i = pt[pt.island .== island, :]
    if nrow(pt_i) < 20; continue; end
    tr = Tuple{Float64,Float64,Float64}[]
    for k in 1:20:nrow(pt_i)
        pc1, pc2 = pc_proj(pt_i[k, :])
        cm = ch[(ch.island .== island) .& (ch.iteration .== pt_i[k,:iteration]), :]
        m = nrow(cm) > 0 ? cm.mass_kg[1] : NaN
        push!(tr, (pc1, pc2, m))
    end
    if length(tr) > 2; traj_data[island] = tr; end
end
println("Traced $(length(traj_data)) islands")

# TikZ overlay
function pc_xy(pc1, pc2)
    (1.5 + (pc1-pc1_r[1])/(pc1_r[2]-pc1_r[1])*16.0,
     1.5 + (pc2-pc2_r[1])/(pc2_r[2]-pc2_r[1])*12.0)
end

open(joinpath(OD, "diagram-v10-landscape.tex"), "w") do f
    write(f, raw"""\documentclass{article}
\usepackage[margin=0cm,paperwidth=32cm,paperheight=22cm]{geometry}
\usepackage{tikz,xcolor,graphicx}
\usetikzlibrary{decorations.pathreplacing,shapes.arrows}
\pagestyle{empty}
\begin{document}
\begin{tikzpicture}[scale=1.0]
\fill[black!95] (0,0) rectangle (32,22);
\node[anchor=south west,inner sep=0] at (1.5,1.5) {\includegraphics[width=16cm,height=12cm]{v10_landscape.png}};
\draw[white!30,line width=0.5pt] (1.5,1.5) rectangle (17.5,13.5);
""")

    # Trajectories
    colors = ["blue!25","cyan!25","green!25","yellow!25","orange!25","red!25","magenta!25",
              "blue!35","cyan!35","green!35","yellow!35","orange!35","red!35","magenta!35"]
    for (k, (isl, tr)) in enumerate(sort(collect(traj_data), by=x->x[1]))
        col = colors[mod1(k, length(colors))]
        lw = isl == 41 ? "2.0pt" : "0.4pt"
        write(f, "\\draw[$col!white,line width=$lw]")
        for (j, t) in enumerate(tr)
            x, y = pc_xy(t[1], t[2])
            j == 1 ? write(f, "($(round(x,2)),$(round(y,2)))") : write(f, " -- ($(round(x,2)),$(round(y,2)))")
            if j % 6 == 0; write(f, "\n  "); end
        end
        write(f, ";\n")
    end

    # Best trajectory highlight
    if haskey(traj_data, 41)
        tr = traj_data[41]
        write(f, "\\draw[white!85,line width=2.5pt]")
        for (j, t) in enumerate(tr)
            x, y = pc_xy(t[1], t[2])
            j == 1 ? write(f, "($(round(x,2)),$(round(y,2)))") : write(f, " -- ($(round(x,2)),$(round(y,2)))")
            if j % 6 == 0; write(f, "\n  "); end
        end
        write(f, ";\n")
        sx, sy = pc_xy(tr[1][1], tr[1][2])
        ex, ey = pc_xy(tr[end][1], tr[end][2])
        write(f, "\\fill[cyan!80] ($(round(sx,2)),$(round(sy,2))) circle (3pt);\n")
        write(f, "\\fill[yellow] ($(round(ex,2)),$(round(ey,2))) circle (5pt);\n")
        write(f, "\\node[yellow,font=\\footnotesize\\bfseries,right] at ($(round(ex,2))+0.2,$(round(ey,2))) {76.75 kg};\n")
    end

    # Labels
    write(f, raw"""\node[white,font=\large] at (9.5,1.0) {PC1 — Structural scale (r\textsubscript{hub}, D\textsubscript{top}, t/D, \lambda)};
\node[white,font=\large,rotate=90] at (0.8,7.5) {PC2 — Configuration (L\textsubscript{r}, rotors, bank)};
""")

    # Mass legend
    for (t, y, label) in [(0.0,14.8,"120"),(0.25,15.6,"110"),(0.5,16.4,"90"),(0.75,17.2,"80"),(1.0,18.0,"77")]
        r = round(Int,255*clamp(t<0.5 ? t*2*0.3 : 0.3+(t-0.5)*2*0.7,0,1))
        g = round(Int,255*clamp(t<0.5 ? 0.1+t*2*0.7 : 0.8+(t-0.5)*2*0.2,0,1))
        b = round(Int,255*clamp(t<0.5 ? 1.0-t*2*0.6 : 0.4-(t-0.5)*2*0.4,0,1))
        write(f, "\\fill[rgb]{$r,$g,$b} (18.5,$y) rectangle (19.0,$(y+0.5));\n")
        write(f, "\\node[white,font=\\tiny,right] at (19.1,$(y+0.25)) {$label kg};\n")
    end

    # Inset: parameter guides
    write(f, raw"""% Right-side insets
\fill[black!85] (20,8) rectangle (31,14);
\node[white,font=\footnotesize\bfseries] at (25.5,13.6) {What PC1 means};
\node[white!70,font=\tiny,align=left] at (22,12.8) {
  Larger r\textsubscript{hub}, D\textsubscript{top}, t/D, $\lambda$ \\
  $\rightarrow$ positive PC1 (right) \\
  = heavier, bigger structure
};
\node[white!70,font=\tiny,align=left] at (28,12.8) {
  Smaller, lighter structure \\
  $\rightarrow$ negative PC1 (left) \\
  = lower mass potential
};

\fill[black!85] (20,1.5) rectangle (31,7.5);
\node[white,font=\footnotesize\bfseries] at (25.5,7.1) {What PC2 means};
\node[white!70,font=\tiny,align=left] at (22,6.2) {
  Higher L\textsubscript{r}, more rotors, \\
  steeper bank $\rightarrow$ positive PC2 (up) \\
  = expansion-dominant config
};
\node[white!70,font=\tiny,align=left] at (28,6.2) {
  Compact, few rotors, \\
  shallow bank $\rightarrow$ negative PC2 (down) \\
  = thrust-dominant config
};

% Start ⟶ End arrow for best trajectory
\fill[black!85] (20,14.3) rectangle (31,18);
\node[white,font=\footnotesize\bfseries] at (25.5,17.6) {Journey: Island 41};
\fill[cyan!80] (21,17.0) circle (3pt);
\node[white!70,font=\tiny,right] at (21.3,17.0) {Start: random design $\sim$130 kg};
\fill[yellow] (21,16.2) circle (3pt);
\node[white!70,font=\tiny,right] at (21.3,16.2) {End: optimum 76.75 kg};
\node[white!50,font=\tiny] at (25.5,15.5) {310K evaluations across 60 islands};
\node[white!40,font=\tiny] at (25.5,15.0) {PCA captures 33\% of 14-D variance};
""")

    write(f, raw"""% Title
\node[white,font=\LARGE\bfseries] at (16,21.5) {V10 Campaign — Optimisation Landscape};
\node[white!60,font=\small] at (16,20.9) {14-DoF DE, 60 islands, 310K evaluations, PCA projection};
""")

    write(f, "\n\\end{tikzpicture}\n\\end{document}\n")
end
println("TikZ: $(joinpath(OD,"diagram-v10-landscape.tex"))")
println("Done — compile with: cd docs/awes-forum-diagrams && pdflatex diagram-v10-landscape.tex")
