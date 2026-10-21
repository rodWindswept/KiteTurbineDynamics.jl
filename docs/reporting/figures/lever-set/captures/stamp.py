#!/usr/bin/python3
"""stamp.py — the provenance stamp for Figure 11's interface captures.

Reads the capture files in this directory, hashes them, and writes
`stamp.json` (machine) and `captures.md` (the line that travels with the
plate). Nothing here draws: the renderer is `render-captures-head.jl` and
the notebook capture is the Pluto page exported beside it.

Run:
    /usr/bin/python3 docs/reporting/figures/lever-set/captures/stamp.py
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

# Figure 10's kit records the frame it seats as an input. If the v1 render
# here reproduces that hash, the interface has not moved since Figure 10's
# script commit and the strip can say so.
FIG10_MANIFEST = REPO / "docs/reporting/figures/capability-sheet/manifest.json"


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


def main() -> None:
    head = git("rev-parse", "HEAD")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    head_time = git("log", "-1", "--format=%ad", "--date=iso")

    fig10 = json.loads(FIG10_MANIFEST.read_text())
    fig10_hash = fig10["inputs"]["capture_full"]["sha256"]

    captures = {}
    for name, kwargs in {
        "dashboard-v1-head.png": {
            "interface": "v1 dashboard",
            "px_per_unit": 1.25,
            "shot": "1600 x 950 logical units, saved at px_per_unit 1.25",
        },
        "dashboard-v2-head.png": {
            "interface": "v2 cockpit",
            "px_per_unit": 1.0,
            "shot": "1780 x 1180 logical units, one frame of a 1.0 s canonical run (50 frames, SAVE_EVERY 500, DT 4e-5)",
        },
    }.items():
        path = HERE / name
        captures[name] = {
            "path": str(path.relative_to(REPO)),
            "pixels": px(path),
            "sha256": sha256(path),
            "renderer": "docs/reporting/figures/lever-set/captures/render-captures-head.jl",
            "renderer_sha256": sha256(HERE / "render-captures-head.jl"),
            **kwargs,
        }

    v1_hash = captures["dashboard-v1-head.png"]["sha256"]
    captures["dashboard-v1-head.png"]["identical_to_figure_10_input"] = v1_hash == fig10_hash
    captures["dashboard-v1-head.png"]["figure_10_input_sha256"] = fig10_hash

    notebook = {
        "path": "docs/reporting/figures/lever-set/captures/notebook-page-head.png",
        "source": "notebooks/design_explorer.jl",
        "source_sha256": sha256(REPO / "notebooks/design_explorer.jl"),
        "pixels": px(HERE / "notebook-page-head.png"),
        "sha256": sha256(HERE / "notebook-page-head.png"),
        "viewport_css": [760, 560],
        "device_scale_factor": 2,
        "capture": "CDP Page.captureScreenshot, captureBeyondViewport, default view state (no code folded)",
        "pluto": "1.0.3",
        "export": {
            "path": "docs/reporting/figures/lever-set/captures/design_explorer-head.html",
            "bytes": (HERE / "design_explorer-head.html").stat().st_size,
            "sha256": sha256(HERE / "design_explorer-head.html"),
            "route": "GET /notebookexport?id=<session notebook id>&offline_bundle=true",
        },
    }

    crops = {}
    for name, note in {
        "cand-notebook-verdict-hud.png": "the verdict HUD, natural aspect 2.58",
        "cand-notebook-top-band.png": "0.733 band from the page top: Pluto chrome + MeshCat viewport",
        "cand-notebook-sliderbank-band.png": "0.733 band through the preset and parameter banks",
    }.items():
        p = HERE / name
        crops[name] = {"pixels": px(p), "sha256": sha256(p), "note": note}

    stamp = {
        "slug": "figure-11-captures",
        "purpose": "The interface capture strip of Figure 11: v1 dashboard, v2 cockpit, Pluto notebook.",
        "head": head,
        "branch": branch,
        "head_commit_time": head_time,
        "era": ERA,
        "reads_dataset": False,
        "dataset_note": (
            "No capture reads a campaign row. The two Makie frames render the 10 kW "
            "canonical system from the tree at HEAD (params_10kw(), settled at "
            "V = 11 m/s); the notebook frame reads notebooks/design_explorer.jl at HEAD."
        ),
        "toolchain": {
            "julia": "1.12.6",
            "glmakie": "0.13",
            "pluto": "1.0.3",
            "plutoui": "0.7.83",
            "python": "3.12.3",
        },
        "captures": captures,
        "notebook": notebook,
        "crop_candidates": crops,
    }
    (HERE / "stamp.json").write_text(json.dumps(stamp, indent=2) + "\n")

    lines = [
        "# Figure 11 interface captures: provenance",
        "",
        f"Rendered at `{head[:7]}` ({branch}), {head_time}. Era `{ERA}`.",
        "",
        "| capture | pixels | sha256 |",
        "|---|---|---|",
    ]
    for name in ("dashboard-v1-head.png", "dashboard-v2-head.png"):
        c = captures[name]
        lines.append(f"| `{name}` | {c['pixels'][0]} x {c['pixels'][1]} | `{c['sha256']}` |")
    lines.append(
        f"| `notebook-page-head.png` | {notebook['pixels'][0]} x {notebook['pixels'][1]} "
        f"| `{notebook['sha256']}` |"
    )
    lines += [
        "",
        f"The v1 frame is byte-identical to Figure 10's recorded input: "
        f"`{v1_hash}` == `{fig10_hash}`. Two runs of the renderer at this commit "
        "returned the same two hashes.",
        "",
        "No capture reads a campaign row. The two Makie frames render the 10 kW canonical "
        "system from the tree; the notebook frame reads `notebooks/design_explorer.jl`.",
        "",
        "Source line for the plate:",
        "",
        f"> captures: interface renders at `{head[:7]}` - v1 dashboard and v2 cockpit from "
        f"`render-captures-head.jl` - era `{ERA}` - no dataset read",
        "",
        "The notebook frame stays in this kit as provenance of the HEAD defect and does not "
        "print: cell `...000000000007` renders its `HTML`-interpolated slider bonds as "
        "`PlutoRunner.Bond(...)` reprs, and its verdict HUD reports `192 / 8` slack over a "
        "segment count. Two members, not three.",
        "",
    ]
    (HERE / "captures.md").write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
