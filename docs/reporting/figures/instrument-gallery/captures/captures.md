# Figure 12 instrument gallery: provenance

Frames rendered in one pass at `87e6b10` (bank-derate-cos2p65), 2026-10-21 22:04:24 +0100. Era `post-95c385d_wind-authority`. The plate composes these three frames at a later commit. It re-renders none of them, so every hash below comes from the pass.

| capture | pixels | prints | dpi | picture | sha256 |
|---|---|---|---|---|---|
| `dashboard-v2-head.png` | 1780 x 1180 | 85.00 x 56.35 mm | 532 | whole window | `b4fdedf07a9a1aed445685a467fb9d98d9ae8b3d8729b74a19408394b6266112` |
| `dashboard-twisted-state-head.png` | 2696 x 1900 | 84.98 x 59.89 mm | 806 | 3D viewport | `691b13204ed8bbe35c38e6fddb0bd5ec950e8700ac448afc3a53f9ada04de72b` |
| `winner-10kw-cartography-head.png` | 4000 x 2818 | 85.00 x 59.88 mm | 1195 | rendered figure | `c0a3f49afcc85d9298350d2d407269a93343ec458362fb84f5811de978f04d81` |

Renderers, hashed in this kit:

| renderer | sha256 |
|---|---|
| `docs/reporting/figures/instrument-gallery/captures/render-captures-head.jl` | `c1e7e35fb57edfbd6f7cc9df88043dde37006a85b7bf60dd8b4d2ba2b88736f0` |
| `docs/reporting/figures/instrument-gallery/captures/render-twisted-state-head.jl` | `7c545caeac0660259bc97e1f0e7bc74dde3f4ac9c87b176b72cc5540cebd72d6` |
| `docs/reporting/figures/instrument-gallery/captures/crop-twisted-cell.py` | `d775351d929580c5556095381471357355fe2aa4d7eedd684e5a67cd17ee6601` |
| `scripts/view_campaign_genomes.jl` | `884133c125fc64cf2d7ec1c3b87e4cb72926d360a1acbe67689e262150c2db4d` |
| `scripts/render_winners_clean.jl` | `81488e607c93783c952be1ea899979c9f971b38f32d6f072f96902da9dac2710` |

Invocation, per capture. One frame needs a flag beyond the script defaults. The flags are part of the receipt:

| capture | invocation |
|---|---|
| `dashboard-v2-head.png` | No flags. The defaults of render-captures-head.jl print this frame. |
| `dashboard-twisted-state-head.png` | No flags. figsize=(2037, 950) at px_per_unit 2 fixes the window. The ink boundaries crop-twisted-cell.py cuts on hold. The build_dashboard figsize default is (1600, 950). tension_label defaults to true, so the tension numerals print without a flag. |
| `winner-10kw-cartography-head.png` | KTD_WINNER_FIG_W=2000 KTD_WINNER_FIG_H=1409 KTD_WINNER_AX_W=1880 KTD_WINNER_AX_H=1330 KTD_WINNER_TITLE=geometry KTD_WINNER_OUT=<dir>. The script default is TITLE=full. |

Cartography input: `scripts/results/trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. Its hash is `aa441c837fd036a8...`. The file is tracked at the pin.

The retired chooser frame's input set. It still sits in this directory, so its inputs stay pinned, but no panel prints from them now.

| input | sha256 | tracked |
|---|---|---|
| `scripts/results/v13_5kw_len18.0/telemetry.csv` | `cf878687e8effe20...` | True |
| `scripts/results/v13_5kw_len21.2/telemetry.csv` | `8e2508fc4c695977...` | True |
| `scripts/results/v13_5kw_len25.0/telemetry.csv` | `f3e19906f254821f...` | True |

The first pass ran before this kit held a tracked renderer for v2. This kit carries a byte-identical copy of that renderer (`c1e7e35f...`). Each renderer named here sits in the tree from the landing commit onward. The captures directory of Figure 11 is tracked from `fa91a8e`. Both figures now carry their renderer.

The chooser frame from the first pass stays in this directory. The twisted-state viewport replaced it at this seat and it prints no longer.

The v1 dashboard capture stays in this directory. It is the frame that the Figure 11 strip prints and the re-stamp control from the first pass. This gallery prints it no longer. A whole window is its own writing. The plate carries the three frames that show what the report cannot say in words.

Print geometry is an 85 x 59.89 mm box. Each frame fits by the binding dimension and no panel is upsampled. A panel enters this set only above a 79 mm admission floor.

Each panel prints every pixel of the picture its tool draws. The picture column of the capture table names the picture for each panel. In the twisted-state cell that picture is the 3D viewport. The control and readout columns sit outside it.

The twisted-state cell prints its two tension numerals inside the picture. It does not print them in a chrome column: T_peak 3099.9 N over SWL 3500 N. build_dashboard draws them at its default, tension_label = true. The value is the SimPeaks T_peak that its HUD row prints, and the receipt uses the same formatter. Measured against the cut, the annotation ink box is 812..1388 x 111..257 device px. That is 199 px inside the 613 boundary and 1920 px inside the 3309. No numeral can fall in a zero-ink margin. The two line runs are 111..184 and 198..257.

The HUD row prints the same value at whole-newton precision, %5.0f, so it reads 3100 N. That row sits outside the cut, so no reader meets the pair on the plate. A later whole-window use of this frame meets both and should pass one precision, not a second literal.

Row 1 holds v2 and the viewport, at 85.00 x 56.35 mm and 84.98 x 59.89 mm. Row 2 holds the cartography alone at 85.00 x 59.88 mm, centred from 44.50 mm. The block is 123.77 mm. It sits in a 174 mm measure with a 4 mm gutter. Row 1 runs flush from 0.00 mm.

Type at these widths: v2 2.98 pt, cartography 2.59 pt, and the twisted-state tension numerals 6.79 pt. The cartography title band is 43 px at 85 mm. The smallest label in the set is 1.22 pt in v2. The set ceiling is the twisted-state numerals at 6.79 pt. The one value the caption reads off the picture is the largest type in the set.

Source line for the plate:

> captures: three instrument frames at `87e6b10`. v2 comes from `render-captures-head.jl`. The twisted-state cell comes from `render-twisted-state-head.jl` and `crop-twisted-cell.py`, which renders the canonical system at its default settle and reads no file. build_dashboard generates its two tension numerals from the same SimPeaks T_peak its HUD prints. The cartography comes from `render_winners_clean.jl` with `KTD_WINNER_TITLE=geometry`. Era `post-95c385d_wind-authority`. The cartography geometry reads from `trpt_opt_v2/10kw_circular_straight_taper_s1/elite_archive.csv`. No value in this report is read from a panel.
