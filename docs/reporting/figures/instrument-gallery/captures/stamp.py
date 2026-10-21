#!/usr/bin/python3
"""stamp.py — the provenance stamp for Figure 12's four-panel instrument gallery.

Reads the four capture files in this directory, hashes them and the three
renderers that made them, and writes `stamp.json` (machine) and `captures.md`
(the line that travels with the plate). Nothing here draws.

One pass at one commit: all four frames were rendered from the tree at the
commit this stamp records, and each row carries the renderer it came from and
that renderer's own hash, so a reader can re-run any one panel without
re-running the others.

Run:
    /usr/bin/python3 docs/reporting/figures/instrument-gallery/captures/stamp.py
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]

ERA = "post-95c385d_wind-authority"

# The one panel that reads a campaign row: the winner cartography decodes its
# ring stack from this archive. It prints no value from it (the title carries
# geometry only), but the row is hashed so the drawn object is pinned.
ARCHIVE = REPO / "scripts/results/trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv"

# The chooser's input set, named. `collect_telemetry_csvs` scans `v13_5kw_len*`
# one level deep under the directory it is given, so the set is what the glob
# selects in `scripts/results` and not whichever copy a shell happened to hand
# it. The frame's own `2784 / 2784 matching` counts rows across these files
# (3 x 928), and the stamp has to name them or that count is a citation.
TELEMETRY = [
    REPO / "scripts/results/v13_5kw_len18.0/telemetry.csv",
    REPO / "scripts/results/v13_5kw_len21.2/telemetry.csv",
    REPO / "scripts/results/v13_5kw_len25.0/telemetry.csv",
]

RENDERERS = {
    "v1_v2": HERE / "render-captures-head.jl",
    "chooser": REPO / "scripts/view_campaign_genomes.jl",
    "cartography": REPO / "scripts/render_winners_clean.jl",
}

# Printed geometry: box 85 x 59.89 mm, fit by the binding dimension, nothing
# cropped and nothing upsampled. Row 1 is v1 + v2, row 2 is chooser + 3D,
# flush to 0 and 174.00 mm inside a 174 mm measure with a 4 mm gutter.
BOX_MM = [85.0, 59.89]
MEASURE_MM = 174.0
GUTTER_MM = 4.0

CAPTURES = {
    "dashboard-v1-head.png": dict(
        interface="v1 dashboard",
        renderer="v1_v2",
        px_per_unit=1.25,
        shot="1600 x 950 logical units, saved at px_per_unit 1.25",
        row=1,
        flags="No flags. The defaults of render-captures-head.jl print this frame.",
        note="byte-identical to Figure 11's member; reproduced at this commit as the re-stamp control",
    ),
    "dashboard-v2-head.png": dict(
        interface="v2 cockpit",
        renderer="v1_v2",
        px_per_unit=1.0,
        shot="1780 x 1180 logical units, one frame of a 1.0 s canonical run (50 frames, SAVE_EVERY 500, DT 4e-5)",
        row=1,
        flags="No flags. The defaults of render-captures-head.jl print this frame.",
        note="byte-identical to Figure 11's member; reproduced at this commit as the re-stamp control",
    ),
    "genome-chooser-head.png": dict(
        interface="genome chooser (view_campaign_genomes.jl --smoke)",
        renderer="chooser",
        px_per_unit=2,
        shot="1250 x 900 logical units at px_per_unit 2",
        row=2,
        flags=(
            "--smoke=<prefix> scripts/results. The --smoke path sets card_text "
            "style=:identity. The interactive browser keeps :full."
        ),
        note=(
            "loads the three telemetry CSVs named under chooser_inputs and prints no value "
            "from one: the cards carry island/gen/idx, the genome fingerprint and decoded "
            "geometry (n_lines/n_rings/n_active, r_hub, tether) only"
        ),
    ),
    "winner-10kw-cartography-head.png": dict(
        interface="10 kW winner cartography (render_winners_clean.jl)",
        renderer="cartography",
        px_per_unit=2,
        shot=(
            "2000 x 1409 logical units at px_per_unit 2; Axis3 aspect (1,1,3.5) pins the "
            "data box, so the canvas sets the margins and not the projection"
            " (tower ink h/w 3.122 at the script's portrait default, 3.113 here)"
        ),
        row=2,
        flags=(
            "KTD_WINNER_FIG_W=2000 KTD_WINNER_FIG_H=1409 KTD_WINNER_AX_W=1880 "
            "KTD_WINNER_AX_H=1330 KTD_WINNER_TITLE=geometry KTD_WINNER_OUT=<dir>. "
            "The script default is TITLE=full."
        ),
        note=(
            "title mode geometry: design tag and object descriptors only, no mass and no "
            "min_fos; draws its ring stack from elite_archive.csv at the pin"
        ),
    ),
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def px(path: Path) -> list[int]:
    with Image.open(path) as im:
        return list(im.size)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, capture_output=True, text=True, check=True
    ).stdout.strip()


def fitted_mm(w_px: int, h_px: int) -> tuple[float, float, float]:
    """Fit into BOX_MM by the binding dimension; return (w, h, dpi)."""
    bw, bh = BOX_MM
    if h_px / w_px <= bh / bw:          # width binds
        w = bw
        h = round(w * h_px / w_px, 2)
    else:                                # height binds
        h = bh
        w = round(h * w_px / h_px, 2)
    dpi = round(w_px / (w / 25.4))
    return w, h, dpi


def main() -> None:
    head = git("rev-parse", "HEAD")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    head_time = git("log", "-1", "--format=%ad", "--date=iso")

    renderers = {k: {"path": str(p.relative_to(REPO)), "sha256": sha256(p)}
                 for k, p in RENDERERS.items()}
    archive = {"path": str(ARCHIVE.relative_to(REPO)), "sha256": sha256(ARCHIVE),
               "tracked": git("ls-files", str(ARCHIVE.relative_to(REPO))) != ""}
    telemetry = [{"path": str(t.relative_to(REPO)), "sha256": sha256(t),
                  "tracked": git("ls-files", str(t.relative_to(REPO))) != ""}
                 for t in TELEMETRY]

    captures = {}
    for name, kwargs in CAPTURES.items():
        path = HERE / name
        w_px, h_px = px(path)
        pw, ph, dpi = fitted_mm(w_px, h_px)
        rk = kwargs.pop("renderer")
        captures[name] = {
            "path": str(path.relative_to(REPO)),
            "pixels": [w_px, h_px],
            "sha256": sha256(path),
            "renderer": renderers[rk]["path"],
            "renderer_sha256": renderers[rk]["sha256"],
            "prints_mm": [pw, ph],
            "dpi": dpi,
            **kwargs,
        }

    rows = {1: [], 2: []}
    for c in captures.values():
        rows[c["row"]].append(c["prints_mm"][1])
    row_h = {r: max(v) for r, v in rows.items() if v}
    block = round(sum(row_h.values()) + GUTTER_MM * (len(row_h) - 1), 2)

    stamp = {
        "slug": "figure-12-instrument-gallery",
        "purpose": (
            "The four-panel instrument gallery of Figure 12 (section 9): v1 dashboard, "
            "v2 cockpit, genome chooser, 10 kW winner cartography. One pass, one commit."
        ),
        "head": head,
        "branch": branch,
        "head_commit_time": head_time,
        "era": ERA,
        "reads_dataset": True,
        "dataset_note": (
            "Two panels read no dataset: v1 and v2 render the 10 kW canonical system from "
            "the tree (params_10kw(), settled at V = 11 m/s). Two read campaign files at the "
            "pin and print no value from either. The chooser loads the three telemetry CSVs "
            "named under chooser_inputs (the set the renderer's own glob selects in "
            "scripts/results, 3 x 928 = 2784 rows) and its cards carry identity and decoded "
            "geometry only, because the --smoke path sets card_text style=:identity, which "
            "drops P_mean, FoS, fitness and status. The cartography decodes its ring stack "
            "from elite_archive.csv and its title carries the design tag and geometry "
            "descriptors only. No panel in the four prints a campaign result, and no value "
            "elsewhere in the report is taken from any capture."
        ),
        "archive_input": archive,
        "chooser_inputs": telemetry,
        "provenance_note": (
            "Each capture names its invocation under `flags`, because two of the four do "
            "not print their shipped frame under the renderer's defaults. The chooser's "
            "identity-only cards come from the --smoke path, and the cartography's geometry "
            "title is set by KTD_WINNER_TITLE=geometry; a reader holding the commit, the "
            "renderer and the input hashes still needs those flags to rebuild the frame. "
            "Figure 11's captures directory is tracked from fa91a8e, so both figures' kits "
            "now carry a renderer in the tree."
        ),
        "toolchain": {"julia": "1.12.6", "glmakie": "0.13", "python": "3.12.3"},
        "print": {
            "box_mm": BOX_MM,
            "measure_mm": MEASURE_MM,
            "gutter_mm": GUTTER_MM,
            "row_1": "v1 + v2, flush from 0.00 mm",
            "row_2": "chooser + cartography, flush from 0.00 mm; the 1.82 mm the chooser "
                     "leaves inside its cell reads as the row's trailing gutter",
            "row_heights_mm": row_h,
            "block_mm": block,
        },
        "captures": captures,
    }
    (HERE / "stamp.json").write_text(json.dumps(stamp, indent=2) + "\n")

    lines = [
        "# Figure 12 instrument gallery: provenance",
        "",
        f"Rendered at `{head[:7]}` ({branch}), {head_time}. Era `{ERA}`. One pass, one commit.",
        "",
        "| capture | pixels | prints | dpi | sha256 |",
        "|---|---|---|---|---|",
    ]
    for name, c in captures.items():
        lines.append(
            f"| `{name}` | {c['pixels'][0]} x {c['pixels'][1]} "
            f"| {c['prints_mm'][0]:.2f} x {c['prints_mm'][1]:.2f} mm | {c['dpi']} "
            f"| `{c['sha256']}` |"
        )
    lines += [
        "",
        "Renderers, hashed in this kit:",
        "",
        "| renderer | sha256 |",
        "|---|---|",
    ]
    for r in renderers.values():
        lines.append(f"| `{r['path']}` | `{r['sha256']}` |")
    lines += [
        "",
        "Invocation, per capture. Two frames need flags beyond the script defaults. "
        "The flags are part of the receipt:",
        "",
        "| capture | invocation |",
        "|---|---|",
    ]
    for name, c in captures.items():
        lines.append(f"| `{name}` | {c['flags']} |")
    lines += [
        "",
        f"Cartography input: `{archive['path']}`. Its hash is `{archive['sha256'][:16]}...`. "
        f"The file is tracked at the pin: {archive['tracked']}.",
        "",
        "Chooser inputs: the set the renderer's own glob selects in `scripts/results`.",
        "",
        "| input | sha256 | tracked |",
        "|---|---|---|",
    ]
    for t in telemetry:
        lines.append(f"| `{t['path']}` | `{t['sha256'][:16]}...` | {t['tracked']} |")
    lines += [
        "",
        "The first pass ran before this kit held a tracked renderer for v1 and v2. "
        "This kit carries a byte-identical copy of that renderer (`c1e7e35f...`). "
        "Each renderer named here sits in the tree from the landing commit onward. "
        "The captures directory of Figure 11 is tracked from `fa91a8e`. "
        "Both figures now carry their renderer.",
        "",
        "The two dashboard frames repeat the Figure 11 members byte for byte at this commit. "
        "That repetition is the re-stamp control. A scripts-only diff cannot move them. "
        "A move would break the one-pass claim in the caption.",
        "",
        "Print geometry is an 85 x 59.89 mm box. Each frame fits by the binding dimension. "
        "No panel is cropped. No panel is upsampled. Row 1 holds v1 and v2 at 56.35 mm. "
        f"Row 2 holds the chooser and the cartography at 59.89 mm. The block is {block} mm. "
        "It sits in a 174 mm measure with a 4 mm gutter. The rows run flush from 0.00 mm.",
        "",
        "Type at these widths: v1 2.17 pt, v2 2.98 pt, chooser 2.36 pt, cartography "
        "2.59 pt. The cartography title band is 43 px at 85 mm. The smallest labels are "
        "1.22 pt in v2 and 1.13 pt in the chooser filter column. The card strip does not "
        "touch that column. The tallest chooser line was 2.92 pt before the strip. It is "
        "2.36 pt after, because the line carrying P_mean reached highest. The set ceiling "
        "is v2 at 2.98 pt either way.",
        "",
        "Source line for the plate:",
        "",
        f"> captures: four instrument frames at `{head[:7]}`. v1 and v2 come from "
        f"`render-captures-head.jl`. The chooser comes from `view_campaign_genomes.jl "
        f"--smoke` over the three `v13_5kw_len*` telemetry sets, with cards in "
        f"identity+geometry style. The cartography comes from `render_winners_clean.jl` "
        f"with `KTD_WINNER_TITLE=geometry`. Era `{ERA}`. The cartography geometry reads "
        "from `trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. No value "
        "prints from either input.",
        "",
    ]
    (HERE / "captures.md").write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
