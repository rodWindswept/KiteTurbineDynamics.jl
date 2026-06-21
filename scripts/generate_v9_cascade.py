# Generate TikZ convergence cascade diagram from V9.0 campaign data
import csv

# Read convergence data
data = {}
with open("scripts/results/v9_0_campaign_50kw/convergence_cascade.csv") as f:
    for row in csv.DictReader(f):
        isl = int(row["island"])
        if isl not in data:
            data[isl] = []
        data[isl].append((int(row["iteration"]), float(row["mass_kg"])))

# Colors per island group
basin_a = {59, 53, 17, 45}
basin_b = {15, 38, 48, 10}
outliers = {11, 40, 52}

def color(isl):
    if isl in basin_a:
        return "green!60!black"
    elif isl in basin_b:
        return "orange!70"
    else:
        return "red!50"

def label(isl):
    if isl in basin_a:
        return f"Basin A ({isl})"
    elif isl in basin_b:
        return f"Basin B ({isl})"
    else:
        return f"Outlier ({isl})"

# Compute coordinate bounds
all_masses = []
for pts in data.values():
    for _, m in pts:
        all_masses.append(m)
y_min, y_max = 44.0, max(all_masses) + 2

# TikZ coordinate mapping
# x: log10(iteration), range log10(1) to log10(10000) = 0 to 4
# y: mass, range y_min to y_max
x_scale = 6.0  # cm per log10 unit
y_scale = 0.35  # cm per kg

# Generate TikZ paths
paths = []
for isl in sorted(data.keys()):
    pts = data[isl]
    coords = []
    for it, mass in pts:
        if mass < 100:  # feasible only
            x = max(0, __import__('math').log10(max(it, 1))) * x_scale
            y = (mass - y_min) * y_scale
            coords.append(f"({x:.2f},{y:.2f})")
    if coords:
        c = color(isl)
        paths.append(f"  \\draw[{c}, thick] plot coordinates {{ {' '.join(coords)} }};")

# Annotations at endpoint
annotations = []
for isl in sorted(data.keys()):
    pts = data[isl]
    if pts:
        _, final_mass = pts[-1]
        if final_mass < 100:
            x = __import__('math').log10(max(pts[-1][0], 1)) * x_scale
            y = (final_mass - y_min) * y_scale
            c = color(isl)
            annotations.append(
                f"  \\node[font=\\tiny, {c}, anchor=west] at ({x:.2f},{y:.2f}) "
                f"{{ {label(isl)}: {final_mass:.1f} kg }};"
            )

height = (y_max - y_min) * y_scale + 2
width = 4 * x_scale + 5

print(f"""% Auto-generated from convergence_cascade.csv
\\documentclass{{article}}
\\usepackage{{tikz}}
\\usepackage[paperwidth={width:.0f}cm,paperheight={height:.0f}cm,margin=0.5cm]{{geometry}}
\\pagestyle{{empty}}

\\begin{{document}}
\\begin{{tikzpicture}}[scale=1.0]

% Axes
\\draw[->, thick] (0, 0) -- (0, {height-2:.1f}) node[above] {{\\small Mass (kg)}};
\\draw[->, thick] (0, 0) -- ({width-2:.1f}, 0) node[right] {{\\small Iterations (log scale)}};

% X-axis ticks
\\foreach \\x/\\label in {{0.0/1, {x_scale:.1f}/10, {2*x_scale:.1f}/100, {3*x_scale:.1f}/1k, {4*x_scale:.1f}/10k}} {{
  \\draw (\\x, -0.1) -- (\\x, 0.1);
  \\node[below, font=\\tiny] at (\\x, -0.2) {{\\label}};
}}

% Y-axis ticks
{chr(10).join(f'  \\draw (-0.1, {(m - y_min)*y_scale:.1f}) -- (0.1, {(m - y_min)*y_scale:.1f});' + chr(10) + f'  \\node[left, font=\\tiny] at (-0.2, {(m - y_min)*y_scale:.1f}) {{{m}}};' for m in range(int(y_min) + (-int(y_min) % 5), int(y_max) + 5, 5))}

% Horizontal guide at 44.52
\\draw[gray!40, dashed] (0, {(44.52 - y_min)*y_scale:.1f}) -- ({4*x_scale:.1f}, {(44.52 - y_min)*y_scale:.1f});
\\node[font=\\tiny, gray] at ({4*x_scale:.1f}, {(44.52 - y_min)*y_scale:.1f}) [anchor=south east] {{44.52 kg}};

% Convergence traces
{chr(10).join(paths)}

% Endpoint annotations (offset for readability)
{chr(10).join(annotations)}

% Legend
\\node[font=\\small\\bfseries, anchor=north west] at ({4*x_scale - 1:.1f}, {height - 2.5:.1f}) {{Legend}};
\\draw[green!60!black, thick] ({4*x_scale - 1:.1f}, {height - 3:.1f}) -- ({4*x_scale - 0.3:.1f}, {height - 3:.1f});
\\node[font=\\tiny, anchor=west] at ({4*x_scale - 0.2:.1f}, {height - 3:.1f}) {{Basin A (<45 kg)}};
\\draw[orange!70, thick] ({4*x_scale - 1:.1f}, {height - 3.5:.1f}) -- ({4*x_scale - 0.3:.1f}, {height - 3.5:.1f});
\\node[font=\\tiny, anchor=west] at ({4*x_scale - 0.2:.1f}, {height - 3.5:.1f}) {{Basin B (45--47 kg)}};
\\draw[red!50, thick] ({4*x_scale - 1:.1f}, {height - 4:.1f}) -- ({4*x_scale - 0.3:.1f}, {height - 4:.1f});
\\node[font=\\tiny, anchor=west] at ({4*x_scale - 0.2:.1f}, {height - 4:.1f}) {{Outlier (>60 kg)}};

% Title
\\node[font=\\Large\\bfseries] at ({(4*x_scale)/2:.1f}, {height - 1:.1f}) {{V9.0 Convergence Cascade: 30 Islands to 44.5 kg}};

% Annotation box
\\fill[black!3, draw=gray!40, rounded corners=4pt] ({4*x_scale - 3:.1f}, {height - 7.5:.1f}) rectangle ({4*x_scale + 1.5:.1f}, {height - 3.8:.1f});
\\node[font=\\tiny, text width=4.2cm, align=left, anchor=north west] at ({4*x_scale - 2.8:.1f}, {height - 4.0:.1f}) {{
30/59 islands converge to Basin A\\\
(44.5 kg) -- a genuine attractor.\\\
Two outliers explore n=19-21\\\
strategy at 68-70 kg.\\\
Dashed line = global best.
}};

\\end{{tikzpicture}}
\\end{{document}}
""")
