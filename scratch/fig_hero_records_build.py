#!/usr/bin/env python3
"""B-commit record builder for the machine-winner-hero landing (figures seat).
Two-phase: verify every anchor, then apply every write. Atomics: no partial state."""
import sys
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
KIT = ROOT / "docs/reporting/figures/machine-winner-hero"
SPEC = ROOT / "docs/reporting/figures/machine-renderer/SPEC.md"
FMAP = ROOT / "docs/reporting/figures/figure-map.md"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = ROOT / "docs/reporting/draft-tracker.md"
RECEIPT = ROOT / "docs/reporting/room-responses/figures-images-diagrams-2026-10-14-machine-winner-hero.md"
HANDOVER = ROOT / "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"

A2 = "c438398"

# ---------- new files ----------
captions = f"""# Captions: machine winner hero

**Slug** `machine-winner-hero`. **Status** GENERATE (first build 2026-10-14).
**Caption split** in force from the first build.

Site: the report at §3.3, the winner. Reading order: plan, side and
downwind. The wording comes from the figures seat, STE-gate checked.
Values cite NR-011, NR-017, NR-021, NR-022 and NR-043. The geometry
sources are the signed genome extract and the signed capture.

## Plain caption

The campaign winner, drawn three ways: down the shaft, from the side,
and along the wind. The machine stands at its settled operating point.
The six rings sit at their recorded stations. The shaft carries its
recorded wind-up. Each ring turns against the ring below it. All three
views share one scale, so the drawn size reads true.

## Technical caption (undergrad register, STE-clean form)

The island-3 winner at its final operating step. The machine reads six
rings, three lines and one active rotor (NR-011). The ring stations and
the per-segment twist come from the signed capture (NR-021, NR-022).
The main rotor carries three blades of span 1.499 m and a bank of 7.088
degrees (NR-043, NR-017).

The plan view looks along the shaft. It draws each ring as its node
polygon. The side view uses the shaft frame. Distance along the shaft
is vertical, and the operating elevation is not drawn. The downwind
view looks along the wind, so the shaft reads foreshortened.

The swept annulus draws as one truncated cone in the side view. It
draws as a ring band in the plan view and as a flattened band in the
downwind view. One scale holds across the three views. A 5 m scale bar
sits in the footer.

## Provenance line

Data commit `dd3cc6a` · genome extract `strip-extract-2026-10-09-best-so-far` (row i3-g26-i9) · capture `pair-extract-2026-10-08-winner-ops` · rows NR-011, NR-017, NR-021, NR-022, NR-043 · script commit `{A2}` · full record: the figure-provenance appendix.

## Generation note

Resolved at GENERATE by the figures seat. The engine is CairoMakie, the
machine-renderer D7 steer. The drawn state is the recorded final
operating pose (SPEC delta D9, 2026-10-14). The built decode supplies
the section classes and the rotor spec. The capture supplies the ring
stations and the twist. The plain built state reads an untwisted shaft
(probe `scratch/fig_hero_state_probe.jl`). No ODE runs.

The capture stores twist magnitudes only. The drawn winding sense takes
the declared spin-sense convention, recorded in the manifest.

The SVG emits glyph paths, not a text layer. The PDF chain takes the
-g garbage collect, then the date pin (2026-10-14).

The ground-station glyph is schematic and carries no number. The
lift-chain overlay and the section markers stay absent by declaration.
"""

readme = f"""# machine-winner-hero: the winner view set

The machine-renderer hero (figure map row 10). One design: the island-3
winner, drawn as the plan, side and downwind capture set at one shared
scale. The drawn state is the recorded final operating pose (SPEC delta
D9, 2026-10-14).

## Files

- `machine-winner-hero.jl` is the generating script.
- `machine-winner-hero.svg`, `.pdf` and `.png` are the outputs.
- `manifest.json`, `checks.log`, `captions.md` and `register-status.md`
  carry the record.

## Sources

- Genome: `docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv`, the winner row i3-g26-i9.
- Pose: `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`. The ring block carries the stations (NR-021). The segment block carries the twist (NR-022).

## The drawn state

The hero draws the recorded final operating pose. The plain built state
reads an untwisted shaft, so the settled twisted form comes from the
capture. The built decode supplies the section classes and the rotor
spec. No ODE runs. The capture stores twist magnitudes only, so the
drawn winding sense takes the declared spin-sense convention.

## Reproduce

`scripts/ktd-julia docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl --script-commit <hex>`

A fresh run reproduces all five outputs byte-identically. The PDF
carries a normalised creation date. The clean passes take -g.

## Rule

Values become register rows before any figure draws them. The figure
draws the signed geometry. The captions cite the rows.
"""

register_status = f"""# Register status: machine winner hero

**Slug** `machine-winner-hero`. Status note for the figure row.
**Date** 2026-10-14. **Script commit** `{A2}`. First GENERATE `{A2}`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-011 | Winner geometry: six rings, three lines, one rotor, hub and ground radii | Signed (science-validator, 2026-10-08) |
| NR-017 | Main-rotor bank, 7.088 deg at ring 6 | Signed (science-validator, 2026-10-08) |
| NR-021 | Ring stations at the winner operating point | Signed (aero-validator, 2026-10-08) |
| NR-022 | Per-segment twist at the winner operating point | Signed (aero-validator, 2026-10-08) |
| NR-043 | Winner blade span 1.4994019682084492 m (quote 1.499) | Signed (science-validator, 2026-10-13) |

The figure draws no other row. The radii, the stations and the twist
come byte-exact from the signed capture. The rotor spec and the section
classes come from the built decode.

## Drawn values and precision

| Quantity | Drawn form | Source |
|---|---|---|
| Ring stations R1 to R6 | 0, 2.3182841987165674, 4.636939712683201, 6.9559610374822345, 9.27534680414777, 18.600867750952748 m | capture ring block; the NR-021 register note reads the same station order |
| Segment twist S1 to S5 | 33.94561934829036, 33.811870056223555, 33.67952027817454, 33.54707806507812, 22.821871326820364 deg | capture segment block (NR-022) |
| Radii R1 to R5, R6 | 0.8036829846088207 m and 4.5799790548200496 m | capture segment block; NR-011 display 0.804 m and 4.580 m |
| Blade span | 1.4994019682084492 m | NR-043 |
| Bank | 7.0881314603 deg | NR-017 display 7.088 |
| Elevation (downwind view) | 28.64 deg | the flown-basis edge note in the NR-032 block |
| Scale bar | 5 m | production value, manifest |

The drawn numerals: the blade span 1.499 m (the NR-043 quote form), the
scale bar 5 m, the register cites and the stamps. No other value numeral
prints.

## The state note (SPEC delta D9)

The hero draws the recorded final operating pose: the built geometry
with the captured wind-up. The probe `scratch/fig_hero_state_probe.jl`
reads every ring azimuth state at 0.000 deg in the plain built state,
so the settled twisted form comes from the capture. The capture stores
twist magnitudes only. The drawn winding sense takes the declared
spin-sense convention: the azimuths accumulate the recorded magnitudes
from R1 upward. The manifest records it.

## Checks at GENERATE

All in-script checks pass at `{A2}`: 15 state checks, the layout
viewports, the px-per-m squareness at 0.0000 ppm on all three panels,
and the PDF chain. The `checks.log` holds the full record. Three fresh
runs stay byte-identical across all five outputs. That walk caught the
orphan-length wobble in the PDF chain, and the mutool passes now take
-g.

## Validator gates

F-COUNT, F-PARSE and F-VALUE walk at the seats. The aero-validator
counter-read and the visual pass by Rod follow.

## Reproduce

Command:
`scripts/ktd-julia docs/reporting/figures/machine-winner-hero/machine-winner-hero.jl --script-commit {A2}`

Toolchain pin: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10. The
PDF carries a normalised creation date (1970-01-01). The clean passes
take -g, so cairo's orphan length objects leave the file. The manifest
pins both extracts and the output hashes.

Self-check: three consecutive runs stay byte-identical across all five
outputs. Verified 2026-10-14 at `{A2}`.
"""

receipt = f"""# The machine winner hero lands (figure map row 10)

**From** @figures-images-diagrams. **Date** 2026-10-14.
**Base** `c438398`, the fetch-first form; the refresh rides this landing.

## What lands

The hero capture set for the island-3 winner: the machine drawn three
ways (plan, side and downwind) at one shared scale, seated in the draft
at §3.3 ahead of the plates. Script `{A2}` (the generator `599d0fb`
plus the PDF normalise fix `{A2}`). The outputs, the kit records, the
map delta v32, the SPEC delta D9 and the draft fold all ride this push.

## The drawn state (SPEC delta D9)

The founder asks for a settled-machine image for the hero, ahead of the
send. The plain built state reads an untwisted shaft. The probe
`scratch/fig_hero_state_probe.jl` reads every ring azimuth state at
0.000 deg there. The settled twisted form therefore comes from the
signed pair-extract capture: the ring stations (NR-021) and the
per-segment twist (NR-022) at the final integration step. The built
decode supplies the section classes and the rotor spec. No ODE runs.
The capture stores twist magnitudes only. The drawn winding sense takes
the declared spin-sense convention, and the manifest records it.

## The F-REPRO finding

The three-way F-REPRO walk at `599d0fb` caught one wobbling byte in the
PDF: an orphan stream-length value, 278 against 279 between fresh runs.
Cairo writes stream lengths as `/Length N 0 R`. Mutool clean inlines
the lengths and orphans the values. The fix: both clean passes take -g,
so the orphans leave the file. The PDF is then byte-stable, and the
render reads identical. The probe `scratch/fig_cairo_date_probe.jl`
holds the evidence chain. The same latent class sits in the strip
chain. The strip holds as recorded at `74cfef9`. No byte moves there
without a scheduled pass.

## Checks

All in-script checks pass. The px-per-m scale reads 30.000000 on all
three panels, 0.0000 ppm. Three fresh runs stay byte-identical across
all five outputs (png, svg, pdf, manifest, checks.log). The fold
resolves in the rebuilt copy.

## Open at the visual pass

The section request note at the tracker §3.3 also names the lift-chain
overlay and the full ring-number set. Row 2 carries the lift chain in
the anatomy plate, so the hero keeps the D4 form for now. Both items
stand parked for Rod's look.

## Handoffs

@aero-validator — the new seat sits in the rebuilt copy at §3.3 (row
10); the counter-read walks when the copy does. @user — the hero is in
the draft. The seat reads §3.3, and it moves earlier in one line if
wanted. @hermes — row 10 reads R2, and the map delta v32 records the
landing.
"""

# ---------- patch map (file, old, new, count) ----------
def spec_patch():
    t = SPEC.read_text()
    d8_end = """- **D8 (2026-10-11):** the strip carries the search objective under
  each panel, in kg, under a declared delta. Row NR-036 backs the
  values (signed 2026-10-11). The geometry claims stand. The strip
  prints no power value and no airborne mass value. The footer states
  the shaft frame."""
    d9 = d8_end + """

- **D9 (2026-10-14):** the hero draws the recorded final operating pose —
  the built geometry with the captured wind-up — not the plain built state.
  The ring stations and the per-segment twist read from the signed
  pair-extract capture (the NR-021 and NR-022 basis, the final integration
  step). The built decode (no ODE) supplies the section classes and the
  rotor spec. Reason: the plain built state reads an untwisted shaft (probe
  `scratch/fig_hero_state_probe.jl`: every ring azimuth state reads 0.000
  deg), so the settled twisted form the founder asked for on 2026-10-14
  comes from the capture. The capture stores magnitudes only; the drawn
  winding sense is the declared spin-sense convention, recorded in the
  manifest. The hero carries the ground-station glyph and a register-bound
  annotation block. The lift-chain overlay and the section markers stay
  absent, declared. The emitted set follows the strip's D7 landing: svg,
  pdf, png, manifest, checks, with the PDF date normalised. The clean
  passes take -g: the orphan stream-length values were the one wobbling
  byte class (2026-10-14)."""
    assert t.count(d8_end) == 1, "D8 anchor"
    t = t.replace(d8_end, d9)
    r_old = "R2 to ⟨append⟩. R3 to ⟨append⟩."
    r_new = ("R2 opened 2026-10-14: the hero capture set renders at `c438398` "
             "(generator `599d0fb` plus the -g normalise fix); the in-script checks pass, "
             "and the seats' counter-read and the visual pass follow. R3 to ⟨append⟩.")
    assert t.count(r_old) == 1, "rounds anchor"
    t = t.replace(r_old, r_new)
    return t

def fmap_patch():
    t = FMAP.read_text()
    row_old = "| 10 | 9 | §3.3 | Machine hero and the plan, side, downwind capture set | `machine-winner-hero` | planned | The winner genome. Makie captures of the built state | The capture script (plan, side, downwind). Then F-REPRO |"
    row_new = "| 10 | 9 | §3.3 | Machine hero and the plan, side, downwind capture set | `machine-winner-hero` | R2 | The winner genome. Makie captures of the recorded final operating pose (the pair-extract capture) | Seated in the draft (§3.3). Three-way F-REPRO green (`c438398`). Next: F-COUNT/F-PARSE and the seats' counter-read, then the visual pass by Rod |"
    assert t.count(row_old) == 1, "row10 anchor"
    t = t.replace(row_old, row_new)
    v31_tail = "The map cells and both kit rounds\n  lines take the closure. Next at both: the visual pass by Rod."
    assert t.count(v31_tail) == 1, "v31 anchor"
    v32 = v31_tail + """

- **v32 (2026-10-14):** row 10 lands its capture set. The hero draws the
  recorded final operating pose: the ring stations and the per-segment
  twist read from the signed pair-extract capture, and the built decode
  supplies the section classes and the rotor spec. No ODE. The drawn
  state records as SPEC delta D9, because the plain built state reads an
  untwisted shaft. Script `c438398`; the outputs and the records ride
  this commit. The three-way F-REPRO walk caught one wobbling orphan
  byte in the PDF chain, and the mutool passes now take -g. All five
  outputs read byte-identical across three fresh runs. The seat: draft
  §3.3, ahead of the plates. The row moves to R2."""
    t = t.replace(v31_tail, v32)
    return t

def draft_patch():
    t = DRAFT.read_text()
    a1 = "Internal engineering report. Draft v0.40. Date 2026-10-14."
    assert t.count(a1) == 1, "title anchor"
    t = t.replace(a1, "Internal engineering report. Draft v0.41. Date 2026-10-14.")
    a2 = "### 3.3 The winner\n\nIsland 3 carries the winner."
    mark = "### 3.3 The winner\n\n[Figure seated: figure-map row 10 (machine winner hero, slug `machine-winner-hero`). Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]\n\nIsland 3 carries the winner."
    assert t.count(a2) == 1, "seat anchor"
    t = t.replace(a2, mark)
    a3 = "One row per built exhibit. All six read dataset commit `dd3cc6a`."
    assert t.count(a3) == 1, "count anchor"
    t = t.replace(a3, "One row per built exhibit. All seven read dataset commit `dd3cc6a`.")
    a4 = "| Parameter atlas | `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv` | NR-001, NR-005, NR-006, NR-044 | `e23f226` | `post-95c385d_wind-authority` |"
    assert t.count(a4) == 1, "atlas row anchor"
    t = t.replace(a4, a4 + "\n| Machine winner hero | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `c438398` | `post-95c385d_wind-authority` |")
    a5 = "- `ledger` `d3a2bcb1208db0bf0a4e5eb061620d9e73e99e776dc091dd26c067a2324d6f76`"
    assert t.count(a5) == 1, "hash tail anchor"
    t = t.replace(a5, a5 + """

Machine winner hero:

- `png` `4e8fc9d267a7e776857b8805be34da1189fddd65117fdf7278f36bd2cd4e6af5`
- `svg` `819bafe52679b0fa23ac8c225e3156444b3dcee3ff4fa1ddf4c9065f846c5171`
- `pdf` `a9d5516d7ec7bd71bbcd8edee6f425b619736277c229c5bc9ff4aae3f3e8fb2e`
- `checks` `52fe83a8c54ec93f5372b2fb15c8c77af90b44c3f1e6eb5a8732efffebf59924`""")
    return t

def tracker_patch():
    t = TRACKER.read_text()
    a = """No value moves.

## 2. Working notes"""
    assert t.count(a) == 1, "tracker anchor"
    entry = """No value moves.

v0.41 fold pass by @figures-images-diagrams (2026-10-14).
This pass seats the machine winner hero in the draft at §3.3, ahead of the plates (figure-map row 10).
The hero draws the recorded final operating pose (SPEC delta D9).
The exhibit joins the figure-provenance appendix with its output hashes.
The lift-chain overlay and the R2 to R5 number set stay open for the visual pass.
No value moves.

## 2. Working notes"""
    t = t.replace(a, entry)
    return t

def handover_patch():
    t = HANDOVER.read_text()
    a0 = "**Base:** branch `bank-derate-cos2p65`. Fetch first and read the tip. This page refreshed at the item-5 counter-read close (2026-10-14, tip `d0679d3`)."
    assert t.count(a0) == 1, "handover base anchor"
    t = t.replace(a0, "**Base:** branch `bank-derate-cos2p65`. Fetch first and read the tip. This page refreshed in the fetch-first form; the refresh rides the machine-hero landing (2026-10-14).")
    a1 = """1. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis,
   ring-utilisation and twist-limit plates) stand at F-VALUE pass or closure.
   The visual pass is the standing final step. The folds follow."""
    assert t.count(a1) == 1, "handover open anchor"
    new1 = """1. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis,
   ring-utilisation and twist-limit plates) and the machine hero (row 10)
   stand at F-VALUE pass or closure. The visual pass is the standing final
   step. The folds follow.
   The hero seat reads §3.3, ahead of the plates. It moves earlier in one
   line if the room calls."""
    t = t.replace(a1, new1)
    a2 = "## Closed, last (evidence index)\n\n- The ring lead flag closes as held (2026-10-14):"
    assert t.count(a2) == 1, "handover closed anchor"
    new2 = """## Closed, last (evidence index)

- The machine winner hero lands (2026-10-14). The plan, side and downwind
  capture set draws the winner at its recorded operating pose (SPEC delta D9).
  Three-way F-REPRO green at `c438398`. The F-REPRO walk caught one wobbling
  orphan byte in the PDF chain, so the mutool passes now take -g.
  Kit `docs/reporting/figures/machine-winner-hero/`. The fold lands at §3.3
  with the appendix row. Receipt
  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-machine-winner-hero.md`.
  Evidence `scratch/fig_hero_state_probe.jl`, `scratch/fig_cairo_date_probe.jl`
  and the kit `checks.log`.

- The ring lead flag closes as held (2026-10-14):"""
    t = t.replace(a2, new2)
    return t

def main():
    # phase 1: build everything in memory (asserts fire here)
    outputs = {
        KIT / "captions.md": ("new", captions),
        KIT / "README.md": ("new", readme),
        KIT / "register-status.md": ("new", register_status),
        RECEIPT: ("new", receipt),
        SPEC: ("patch", spec_patch()),
        FMAP: ("patch", fmap_patch()),
        DRAFT: ("patch", draft_patch()),
        TRACKER: ("patch", tracker_patch()),
        HANDOVER: ("patch", handover_patch()),
    }
    # phase 2: write
    for path, (kind, text) in outputs.items():
        if kind == "new" and path.exists():
            sys.exit(f"refusing: {path} exists")
        path.write_text(text)
        print(f"wrote {path.relative_to(ROOT)}")
    print("ALL RECORDS WRITTEN")

main()
