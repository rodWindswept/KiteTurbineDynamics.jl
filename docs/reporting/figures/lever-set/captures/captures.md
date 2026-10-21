# Figure 11 interface captures: provenance

Rendered at `9f24fb0` (bank-derate-cos2p65), 2026-10-21 17:45:08 +0100. Era `post-95c385d_wind-authority`.

| capture | pixels | sha256 |
|---|---|---|
| `dashboard-v1-head.png` | 2000 x 1188 | `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f` |
| `dashboard-v2-head.png` | 1780 x 1180 | `b4fdedf07a9a1aed445685a467fb9d98d9ae8b3d8729b74a19408394b6266112` |
| `notebook-page-head.png` | 1490 x 27414 | `2f935f23d5e1cfbe94e01628af1094557877b7a382fa28ca0a29ce4b60315b6d` |

The v1 frame is byte-identical to Figure 10's recorded input: `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f` == `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f`. Two runs of the renderer at this commit returned the same two hashes.

No capture reads a campaign row. The two Makie frames render the 10 kW canonical system from the tree; the notebook frame reads `notebooks/design_explorer.jl`.

Source line for the plate:

> captures: interface renders at `9f24fb0` - v1 dashboard and v2 cockpit from `render-captures-head.jl` - era `post-95c385d_wind-authority` - no dataset read

The notebook frame stays in this kit as provenance of the HEAD defect and does not print: cell `...000000000007` renders its `HTML`-interpolated slider bonds as `PlutoRunner.Bond(...)` reprs, and its verdict HUD reports `192 / 8` slack over a segment count. Two members, not three.
