# Figure 12 instrument gallery: provenance

Rendered at `9e0866d` (bank-derate-cos2p65), 2026-10-21 18:49:59 +0100. Era `post-95c385d_wind-authority`. One pass, one commit.

| capture | pixels | prints | dpi | sha256 |
|---|---|---|---|---|
| `dashboard-v1-head.png` | 2000 x 1188 | 85.00 x 50.49 mm | 598 | `be8a88e4a5f844c444491b3deef3c696f967f019d7fae6655483e1ba1e697c4f` |
| `dashboard-v2-head.png` | 1780 x 1180 | 85.00 x 56.35 mm | 532 | `b4fdedf07a9a1aed445685a467fb9d98d9ae8b3d8729b74a19408394b6266112` |
| `genome-chooser-head.png` | 2500 x 1800 | 83.18 x 59.89 mm | 763 | `f1b6fad0341da2773568ec1d13904f74166c9e126b290340c2189725e17f6838` |
| `winner-10kw-cartography-head.png` | 4000 x 2818 | 85.00 x 59.88 mm | 1195 | `c0a3f49afcc85d9298350d2d407269a93343ec458362fb84f5811de978f04d81` |

Renderers, hashed in this kit:

| renderer | sha256 |
|---|---|
| `docs/reporting/figures/instrument-gallery/captures/render-captures-head.jl` | `c1e7e35fb57edfbd6f7cc9df88043dde37006a85b7bf60dd8b4d2ba2b88736f0` |
| `scripts/view_campaign_genomes.jl` | `ffdf7f58c6e4dac17a55211b4683134ec28d55fcdd7594b9d65debd65ace5fd2` |
| `scripts/render_winners_clean.jl` | `81488e607c93783c952be1ea899979c9f971b38f32d6f072f96902da9dac2710` |

Cartography input: `scripts/results/trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. Its hash is `aa441c837fd036a8...`. The file is tracked at the pin: True.

The renderer for v1 and v2, `render-captures-head.jl`, was untracked at the first pass. This kit holds a byte-identical copy (`c1e7e35f...`). From the landing commit onward, each renderer named here is in the tree. The captures directory of Figure 11 is still untracked. It is not this kit to commit.

The two dashboard frames reproduce the Figure 11 members byte for byte at this commit. This is the re-stamp control. A scripts-only diff cannot move them. If they had moved, the one-pass claim of the caption would be false.

Print geometry: an 85 x 59.89 mm box. Each frame fits by the binding dimension. No panel is cropped. No panel is upsampled. Row 1 holds v1 and v2 at 56.35 mm. Row 2 holds the chooser and the cartography at 59.89 mm. The block is 120.24 mm. It sits in a 174 mm measure with a 4 mm gutter. The rows are flush from 0.00 mm.

Type at these widths: v1 2.17 pt, v2 2.98 pt, chooser 2.92 pt, cartography 2.59 pt. The cartography title band is 43 px at 85 mm. The smallest labels are 1.22 pt (v2, 9 px).

Source line for the plate:

> captures: four instrument frames at `9e0866d` - v1 and v2 from `render-captures-head.jl`, chooser from `view_campaign_genomes.jl --smoke`, cartography from `render_winners_clean.jl` (title mode geometry) - era `post-95c385d_wind-authority` - cartography geometry read from `trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`, no value printed from it
