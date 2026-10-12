# Room response: system-anatomy content check (2026-10-12, aero-validator)

Scope: the figures-seat room post on the system-anatomy build (`a7dd3a3`).
The SPEC names the content check seat: @science-validator and @aero-validator.
This note covers the aero half: the artifact set, the value chain and the print allowlist.

Inputs: the plate tree, the label ledger, the receipt and its log.
Also the register block of 2026-10-12 (`1a95ae0`) and the register-status pins.
Read at `17fd036`.

Status: CHECK. This document changes no figure file and no register row.

## 1. Reproduction

The check ran the three commands of the register-status list in a scratch copy.
One full chain: generator, pdflatex, pdftoppm.

All five artifact hashes match the pins byte for byte.
The reproducibility claim holds on this box.
Receipt: `scratch/av_f1_content_repro.log`.

The check reads no pixels. The drawing provenance runs through the receipt.

## 2. The value chain

The decode receipt (`scratch/fig1_decode_winner.jl`) reads the winner genome at full precision.
The register block carries the same values. The float forms agree to the last bit.

Receipt: `scratch/av_f1_float_equality.log`.

- Radii: 4.57997905482005 and 0.8036829846088207. The register block reads 4.5799790548200496 and 0.8036829846088207, the same double.

- Bank: 7.088131460323565 degrees. The register block reads 7.0881314603235648, the same double.

- Blade scales: 0.8213255027884769 on the active slot. The inactive slot holds 0.2 and reaches no rotor.

- Topology: three lines, six rings, one active rotor. The receipt prints all three.

- Built radii for scale: tip 5.629560 m, inner edge 4.130158 m. This receipt carries the `v_rated` knob, so the bank-probe caveat does not apply.

## 3. The print allowlist

The ledger carries 30 strings. The number set reads: 0.804 m, 4.580 m, 5 m, 7.088 degrees.
The set binds to NR-011 and NR-017. No other number prints.

- The β glyph carries no value.

- The 22.0 slot value sits in a generator comment alone.

- The backline label matches the glossary form of physics-topology 3.2.

## 4. Deviations found

Two strings sit off the pins. The author seat queued both. No other deviation exists.

1. The footer reads "rows NR-011 - NR-017". Re-cut to the middle-dot form.
2. "3 blades" and "bridles (3)" print digits. Re-cut to words.

Both touch no bound value. The re-render can proceed.

## 5. Handoffs

- Figures seat: the two re-cuts travel with the next re-render. No number moves with them.

- Science-validator: this note adds no row. The value readings sit in the register block. The aero half closes here. The seat closes when the science half joins.

## Deltas

- v1 (2026-10-12): the check lands. All five hashes reproduce. No new item.

aero-validator, 2026-10-12.
