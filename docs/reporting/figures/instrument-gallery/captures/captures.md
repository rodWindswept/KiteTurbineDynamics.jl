# Figure 12 instrument gallery: provenance

Rendered at `ecc6fc6` (bank-derate-cos2p65), 2026-10-21 19:27:08 +0100. Era `post-95c385d_wind-authority`. One pass, one commit.

| capture | pixels | prints | dpi | sha256 |
|---|---|---|---|---|
| `dashboard-v1-head.png` | 2000 x 1188 | 85.00 x 50.49 mm | 598 | `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f` |
| `dashboard-v2-head.png` | 1780 x 1180 | 85.00 x 56.35 mm | 532 | `b4fdedf07a9a1aed445685a467fb9d98d9ae8b3d8729b74a19408394b6266112` |
| `genome-chooser-head.png` | 2500 x 1800 | 83.18 x 59.89 mm | 763 | `b1e5e367215d9363d86b80fa8d7e5cc218605d3ddffaed53816ccba08f7b86ca` |
| `winner-10kw-cartography-head.png` | 4000 x 2818 | 85.00 x 59.88 mm | 1195 | `c0a3f49afcc85d9298350d2d407269a93343ec458362fb84f5811de978f04d81` |

Renderers, hashed in this kit:

| renderer | sha256 |
|---|---|
| `docs/reporting/figures/instrument-gallery/captures/render-captures-head.jl` | `c1e7e35fb57edfbd6f7cc9df88043dde37006a85b7bf60dd8b4d2ba2b88736f0` |
| `scripts/view_campaign_genomes.jl` | `884133c125fc64cf2d7ec1c3b87e4cb72926d360a1acbe67689e262150c2db4d` |
| `scripts/render_winners_clean.jl` | `81488e607c93783c952be1ea899979c9f971b38f32d6f072f96902da9dac2710` |

Invocation, per capture. Two frames need flags beyond the script defaults. The flags are part of the receipt:

| capture | invocation |
|---|---|
| `dashboard-v1-head.png` | No flags. The defaults of render-captures-head.jl print this frame. |
| `dashboard-v2-head.png` | No flags. The defaults of render-captures-head.jl print this frame. |
| `genome-chooser-head.png` | --smoke=<prefix> scripts/results. The --smoke path sets card_text style=:identity. The interactive browser keeps :full. |
| `winner-10kw-cartography-head.png` | KTD_WINNER_FIG_W=2000 KTD_WINNER_FIG_H=1409 KTD_WINNER_AX_W=1880 KTD_WINNER_AX_H=1330 KTD_WINNER_TITLE=geometry KTD_WINNER_OUT=<dir>. The script default is TITLE=full. |

Cartography input: `scripts/results/trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. Its hash is `aa441c837fd036a8...`. The file is tracked at the pin: True.

Chooser inputs: the set the renderer's own glob selects in `scripts/results`.

| input | sha256 | tracked |
|---|---|---|
| `scripts/results/v13_5kw_len18.0/telemetry.csv` | `cf878687e8effe20...` | True |
| `scripts/results/v13_5kw_len21.2/telemetry.csv` | `8e2508fc4c695977...` | True |
| `scripts/results/v13_5kw_len25.0/telemetry.csv` | `f3e19906f254821f...` | True |

The first pass ran before this kit held a tracked renderer for v1 and v2. This kit carries a byte-identical copy of that renderer (`c1e7e35f...`). Each renderer named here sits in the tree from the landing commit onward. The captures directory of Figure 11 is tracked from `fa91a8e`. Both figures now carry their renderer.

The two dashboard frames repeat the Figure 11 members byte for byte at this commit. That repetition is the re-stamp control. A scripts-only diff cannot move them. A move would break the one-pass claim in the caption.

Print geometry is an 85 x 59.89 mm box. Each frame fits by the binding dimension. No panel is cropped. No panel is upsampled. Row 1 holds v1 and v2 at 56.35 mm. Row 2 holds the chooser and the cartography at 59.89 mm. The block is 120.24 mm. It sits in a 174 mm measure with a 4 mm gutter. The rows run flush from 0.00 mm.

Type at these widths: v1 2.17 pt, v2 2.98 pt, chooser 2.36 pt, cartography 2.59 pt. The cartography title band is 43 px at 85 mm. The smallest labels are 1.22 pt in v2 and 1.13 pt in the chooser filter column. The card strip does not touch that column. The tallest chooser line was 2.92 pt before the strip. It is 2.36 pt after, because the line carrying P_mean reached highest. The set ceiling is v2 at 2.98 pt either way.

Source line for the plate:

> captures: four instrument frames at `ecc6fc6`. v1 and v2 come from `render-captures-head.jl`. The chooser comes from `view_campaign_genomes.jl --smoke` over the three `v13_5kw_len*` telemetry sets, with cards in identity+geometry style. The cartography comes from `render_winners_clean.jl` with `KTD_WINNER_TITLE=geometry`. Era `post-95c385d_wind-authority`. The cartography geometry reads from `trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. No value prints from either input.
