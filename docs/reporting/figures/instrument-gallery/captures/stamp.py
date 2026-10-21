#!/usr/bin/python3
"""stamp.py — the provenance stamp for Figure 12's three-panel instrument gallery.

Reads the three capture files in this directory, hashes them and the
renderers that made them, and writes `stamp.json` (machine) and `captures.md`
(the line that travels with the plate). Nothing here draws.

One pass at one commit: all three frames were rendered from the tree at the
commit this stamp records, and each row carries the renderer it came from and
that renderer's own hash, so a reader can re-run any one panel without
re-running the others.

The plate composes those frames and re-renders none of them, so a recomposition
leaves every frame hash and the pass commit alone. Change `PASS` only when a
frame is re-rendered.

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

# The one render pass that produced these frame bytes. A recomposition of the
# plate reads them and re-renders nothing, so the stamp records the pass and
# not the tree it happens to run in; `git show 4749828` is the check.
PASS = "87e6b10"

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
    "twisted_state": HERE / "render-twisted-state-head.jl",
    "twisted_crop": HERE / "crop-twisted-cell.py",
    "chooser": REPO / "scripts/view_campaign_genomes.jl",
    "cartography": REPO / "scripts/render_winners_clean.jl",
}

# Printed geometry: box 85 x 59.89 mm, fit by the binding dimension, nothing
# upsampled. Row 1 is v2 + the twisted-state viewport; row 2 is the 3D
# cartography alone, centred, because a third panel in two 85 mm columns leaves
# one cell empty. The grid is flush to 0 and 174.00 mm inside a 174 mm measure
# with a 4 mm gutter.
BOX_MM = [85.0, 59.89]
MEASURE_MM = 174.0
GUTTER_MM = 4.0

CAPTURES = {
    "dashboard-v2-head.png": dict(
        interface="v2 cockpit",
        picture="whole window",
        renderer="v1_v2",
        px_per_unit=1.0,
        shot="1780 x 1180 logical units, one frame of a 1.0 s canonical run (50 frames, SAVE_EVERY 500, DT 4e-5)",
        row=1,
        flags="No flags. The defaults of render-captures-head.jl print this frame.",
        note=(
            "byte-identical to Figure 11's member; reproduced at this commit as "
            "the re-stamp control. It is the set's one whole cockpit window"
        ),
    ),
    "dashboard-twisted-state-head.png": dict(
        interface="dashboard 3D viewport, settled twisted state",
        picture="3D viewport",
        renderer="twisted_state",
        px_per_unit=2,
        shot=(
            "2696 x 1900 px cut from a 4074 x 1900 whole-window render at px_per_unit 2, "
            "device columns 613..3308. The cut lands on the measured ink boundaries, so "
            "both inside margins carry no ink and the scene prints every pixel it draws. "
            "The scene prints the peak tension in pixels at its top left: T_peak 3099.9 N "
            "over SWL 3500 N. The ink box is 812..1388 x 111..257 device px, which is 199 px "
            "inside the 613 boundary and 1920 px inside the 3309"
        ),
        row=1,
        flags=(
            "No flags. figsize=(2037, 950) at px_per_unit 2 fixes the window. "
            "The ink boundaries crop-twisted-cell.py cuts on hold. The "
            "build_dashboard figsize default is (1600, 950). tension_label defaults "
            "to true, so the tension numerals print without a flag."
        ),
        state=dict(
            twist_deg=214.71,
            tension_peak_n=3099.9,
            tension_swl_n=3500,
            omega_hub_rad_s=9.5,
            electrical_power_kw=0.01,
        ),
        note=(
            "params_10kw() settled at 9.5 with the rotary lifter, V = 11 m/s, as "
            "the export script defaults; no CSV read. The frame shows twist, line "
            "tension and ring compression through the dashboard's own colour "
            "scales and prints no campaign result. State, printed by the "
            "generator: twist 214.71 deg (hub - PTO), T_peak 3099.9 N of 3500 N "
            "SWL, omega_hub 9.5 rad/s, electrical power 0.01 kW. build_dashboard "
            "generates the two tension numerals from the same SimPeaks T_peak its HUD row "
            "prints, through _tension_label_text. The render script stops if the string "
            "does not carry the receipt value"
        ),
    ),
    "winner-10kw-cartography-head.png": dict(
        interface="10 kW winner cartography (render_winners_clean.jl)",
        picture="rendered figure",
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
    head = git("rev-parse", PASS)
    branch = git("name-rev", "--name-only", "--refs=refs/heads/*", PASS).split("~")[0]
    head_time = git("log", "-1", "--format=%ad", "--date=iso", PASS)

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
            "The three-panel instrument gallery of Figure 12 (section 9): v2 cockpit, "
            "dashboard twisted-state viewport, 10 kW winner cartography. "
            "One pass, one commit."
        ),
        "head": head,
        "branch": branch,
        "head_commit_time": head_time,
        "era": ERA,
        "reads_dataset": True,
        "dataset_note": (
            "Two panels read no dataset at all. v2 renders the 10 kW canonical "
            "system from the tree (params_10kw(), settled at V = 11 m/s). The twisted-state "
            "cell renders the same system through the export script's default settle and "
            "reads no file. The cartography decodes its ring stack from elite_archive.csv "
            "and its title carries the design tag and geometry descriptors only. No panel "
            "prints a campaign result. No value in this report is read from "
            "a panel."
        ),
        "archive_input": archive,
        "chooser_inputs": telemetry,
        "provenance_note": (
            "Each capture names its invocation under `flags`, because one of the three does "
            "not print its shipped frame under the renderer's defaults: the cartography's "
            "geometry title is set by KTD_WINNER_TITLE=geometry. The twisted-state cell "
            "needs its window size fixed, so the column boundaries the crop cuts on hold. "
            "A reader who holds the commit, the renderer and the inputs still needs those "
            "flags to rebuild the frame. Figure 11's captures directory is tracked from "
            "fa91a8e, so both figures' kits carry a renderer in the tree."
        ),
        "toolchain": {"julia": "1.12.6", "glmakie": "0.13", "python": "3.12.3"},
        "print": {
            "box_mm": BOX_MM,
            "measure_mm": MEASURE_MM,
            "gutter_mm": GUTTER_MM,
            "row_1": "v2 + the twisted-state viewport, flush from 0.00 mm",
            "row_2": "the cartography alone at 85.00 mm, centred from 44.50 mm: a third "
                 "panel in two 85 mm columns leaves one cell empty",
            "raster": "3638 x 2588 px at 531 dpi = 174.02 x 123.80 mm. A 4.00 mm "
                      "gutter is 83.6 px, so the grid carries 84 px: the plate prints "
                      "0.02 mm over the nominal measure and 0.03 mm over the "
                      "123.77 mm block",
            "row_heights_mm": row_h,
            "block_mm": block,
        },
        "captures": captures,
    }
    (HERE / "stamp.json").write_text(json.dumps(stamp, indent=2) + "\n")

    lines = [
        "# Figure 12 instrument gallery: provenance",
        "",
        f"Frames rendered in one pass at `{head[:7]}` ({branch}), {head_time}. "
        f"Era `{ERA}`. The plate composes these three frames at a later commit. "
        "It re-renders none of them, so every hash below comes from the pass.",
        "",
        "| capture | pixels | prints | dpi | picture | sha256 |",
        "|---|---|---|---|---|---|",
    ]
    for name, c in captures.items():
        lines.append(
            f"| `{name}` | {c['pixels'][0]} x {c['pixels'][1]} "
            f"| {c['prints_mm'][0]:.2f} x {c['prints_mm'][1]:.2f} mm | {c['dpi']} "
            f"| {c['picture']} | `{c['sha256']}` |"
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
        "Invocation, per capture. One frame needs a flag beyond the script defaults. "
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
        + ("The file is tracked at the pin." if archive["tracked"]
           else "The file is not tracked at the pin."),
        "",
        "The retired chooser frame's input set. It still sits in this directory, so "
        "its inputs stay pinned, but no panel prints from them now.",
        "",
        "| input | sha256 | tracked |",
        "|---|---|---|",
    ]
    for t in telemetry:
        lines.append(f"| `{t['path']}` | `{t['sha256'][:16]}...` | {t['tracked']} |")
    lines += [
        "",
        "The first pass ran before this kit held a tracked renderer for v2. "
        "This kit carries a byte-identical copy of that renderer (`c1e7e35f...`). "
        "Each renderer named here sits in the tree from the landing commit onward. "
        "The captures directory of Figure 11 is tracked from `fa91a8e`. "
        "Both figures now carry their renderer.",
        "",
        "The chooser frame from the first pass stays in this directory. The "
        "twisted-state viewport replaced it at this seat and it prints no longer.",
        "",
        "The v1 dashboard capture stays in this directory. It is the frame that the "
        "Figure 11 strip prints and the re-stamp control from the first pass. This "
        "gallery prints it no longer. A whole window is its own writing. The plate "
        "carries the three frames that show what the report cannot say in words.",
        "",
        "Print geometry is an 85 x 59.89 mm box. Each frame fits by the binding "
        "dimension and no panel is upsampled. A panel enters this set only above a "
        "79 mm admission floor.",
        "",
        "Each panel prints every pixel of the picture its tool draws. The picture "
        "column of the capture table names the picture for each panel. In the "
        "twisted-state cell that picture is the 3D viewport. The control and readout "
        "columns sit outside it.",
        "",
        "The twisted-state cell prints its two tension numerals inside the picture. It "
        "does not print them in a chrome column: T_peak 3099.9 N over SWL 3500 N. "
        "build_dashboard draws them at its default, tension_label = true. The value is "
        "the SimPeaks T_peak that its HUD row prints, and the receipt uses the same "
        "formatter. Measured against the cut, the annotation ink box is "
        "812..1388 x 111..257 device px. That is 199 px inside the 613 boundary and "
        "1920 px inside the 3309. No numeral can fall in a zero-ink margin. The two "
        "line runs are 111..184 and 198..257.",
        "",
        "The HUD row prints the same value at whole-newton precision, %5.0f, so it "
        "reads 3100 N. That row sits outside the cut, so no reader meets the pair on "
        "the plate. A later whole-window use of this frame meets both and should pass "
        "one precision, not a second literal.",
        "",
        "Row 1 holds v2 and the viewport, at 85.00 x 56.35 mm and 84.98 x 59.89 mm. "
        "Row 2 holds the cartography alone at 85.00 x 59.88 mm, centred from "
        f"44.50 mm. The block is {block} mm. It sits in a 174 mm measure with a 4 mm "
        "gutter. Row 1 runs flush from 0.00 mm.",
        "",
        "Type at these widths: v2 2.98 pt, cartography 2.59 pt, and the "
        "twisted-state tension numerals 6.79 pt. The cartography title band is 43 px "
        "at 85 mm. The smallest label in the set is 1.22 pt in v2. The set ceiling is "
        "the twisted-state numerals at 6.79 pt. The one value the caption reads off the "
        "picture is the largest type in the set.",
        "",
        "Source line for the plate:",
        "",
        f"> captures: three instrument frames at `{head[:7]}`. v2 comes from "
        f"`render-captures-head.jl`. The twisted-state cell comes from "
        f"`render-twisted-state-head.jl` and `crop-twisted-cell.py`, which renders the "
        f"canonical system at its default settle and reads no file. build_dashboard "
        f"generates its two tension numerals from the same SimPeaks T_peak its HUD "
        f"prints. The cartography "
        f"comes from `render_winners_clean.jl` with `KTD_WINNER_TITLE=geometry`. Era "
        f"`{ERA}`. The cartography geometry reads from "
        "`trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. No value in "
        "this report is read from a panel.",
        "",
    ]
    (HERE / "captures.md").write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
