# Figure 12 instrument gallery: provenance

Rendered at `4749828` (bank-derate-cos2p65), 2026-10-21 21:26:15 +0100. Era `post-95c385d_wind-authority`. One pass, one commit.

| capture | pixels | prints | dpi | picture | sha256 |
|---|---|---|---|---|---|
| `dashboard-v1-head.png` | 2000 x 1188 | 85.00 x 50.49 mm | 598 | whole window | `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f` |
| `dashboard-v2-head.png` | 1780 x 1180 | 85.00 x 56.35 mm | 532 | whole window | `b4fdedf07a9a1aed445685a467fb9d98d9ae8b3d8729b74a19408394b6266112` |
| `dashboard-twisted-state-head.png` | 2696 x 1900 | 84.98 x 59.89 mm | 806 | 3D viewport | `74299edc5ddaad611b805da0b5328436e631dbd37909f40cae5f54608e933fe8` |
| `winner-10kw-cartography-head.png` | 4000 x 2818 | 85.00 x 59.88 mm | 1195 | rendered figure | `c0a3f49afcc85d9298350d2d407269a93343ec458362fb84f5811de978f04d81` |

Renderers, hashed in this kit:

| renderer | sha256 |
|---|---|
| `docs/reporting/figures/instrument-gallery/captures/render-captures-head.jl` | `c1e7e35fb57edfbd6f7cc9df88043dde37006a85b7bf60dd8b4d2ba2b88736f0` |
| `docs/reporting/figures/instrument-gallery/captures/render-twisted-state-head.jl` | `506aa8a32181fc35c808783b80a07a5e7850b9c7dbb34c818e683ab0fdf367e6` |
| `docs/reporting/figures/instrument-gallery/captures/crop-twisted-cell.py` | `d775351d929580c5556095381471357355fe2aa4d7eedd684e5a67cd17ee6601` |
| `scripts/view_campaign_genomes.jl` | `884133c125fc64cf2d7ec1c3b87e4cb72926d360a1acbe67689e262150c2db4d` |
| `scripts/render_winners_clean.jl` | `81488e607c93783c952be1ea899979c9f971b38f32d6f072f96902da9dac2710` |

Invocation, per capture. One frame needs a flag beyond the script defaults. The flags are part of the receipt:

| capture | invocation |
|---|---|
| `dashboard-v1-head.png` | No flags. The defaults of render-captures-head.jl print this frame. |
| `dashboard-v2-head.png` | No flags. The defaults of render-captures-head.jl print this frame. |
| `dashboard-twisted-state-head.png` | No flags. figsize=(2037, 950) at px_per_unit 2 fixes the window, so the ink boundaries crop-twisted-cell.py cuts on hold. The build_dashboard figsize default is (1600, 950). |
| `winner-10kw-cartography-head.png` | KTD_WINNER_FIG_W=2000 KTD_WINNER_FIG_H=1409 KTD_WINNER_AX_W=1880 KTD_WINNER_AX_H=1330 KTD_WINNER_TITLE=geometry KTD_WINNER_OUT=<dir>. The script default is TITLE=full. |

Cartography input: `scripts/results/trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. Its hash is `aa441c837fd036a8...`. The file is tracked at the pin: True.

The retired chooser frame's input set. It still sits in this directory, so its inputs stay pinned, but no panel prints from them now.

| input | sha256 | tracked |
|---|---|---|
| `scripts/results/v13_5kw_len18.0/telemetry.csv` | `cf878687e8effe20...` | True |
| `scripts/results/v13_5kw_len21.2/telemetry.csv` | `8e2508fc4c695977...` | True |
| `scripts/results/v13_5kw_len25.0/telemetry.csv` | `f3e19906f254821f...` | True |

The first pass ran before this kit held a tracked renderer for v1 and v2. This kit carries a byte-identical copy of that renderer (`c1e7e35f...`). Each renderer named here sits in the tree from the landing commit onward. The captures directory of Figure 11 is tracked from `fa91a8e`. Both figures now carry their renderer.

The chooser frame from the first pass stays in this directory. The twisted-state viewport replaced it at this seat and it prints no longer.

Print geometry is an 85 x 59.89 mm box. Each frame fits by the binding dimension and no panel is upsampled. A panel enters this set only above a 79 mm admission floor. Each panel prints every pixel of the picture its tool draws. The picture column of the capture table names the picture for each panel. In the twisted-state cell that picture is the 3D viewport. The control and readout columns sit outside it. Row 1 holds v1 and v2 at 56.35 mm. Row 2 holds the viewport at 84.98 mm and the cartography at 85.00 mm. The block is 120.24 mm. It sits in a 174 mm measure with a 4 mm gutter. The rows run flush from 0.00 mm.

Type at these widths: v1 2.17 pt, v2 2.98 pt, cartography 2.59 pt. The cartography title band is 43 px at 85 mm. The smallest label in the set is 1.22 pt in v2. The set ceiling is v2 at 2.98 pt.

Source line for the plate:

> captures: four instrument frames at `4749828`. v1 and v2 come from `render-captures-head.jl`. The twisted-state cell comes from `render-twisted-state-head.jl` and `crop-twisted-cell.py`, which renders the canonical system at its default settle and reads no file. The cartography comes from `render_winners_clean.jl` with `KTD_WINNER_TITLE=geometry`. Era `post-95c385d_wind-authority`. The cartography geometry reads from `trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. No value in this report is read from a panel.
