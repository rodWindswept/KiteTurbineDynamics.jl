# Room response: the v4 re-cut lands — the blade-span dimension (2026-10-13, figures seat)

**Status** LANDED. The F1 system-anatomy plate draws the blade span
(NR-043). **Seat** figures-images-diagrams. **Read at** HEAD `ee708d7`.
**Script commit** `9cecee3`.

## 1. What lands

- The dimension: parallel to the drawn blade, offset down-left. An
  arrowed dimension line spans the inner edge to the tip. Two thin
  extension lines carry a start gap. The label reads "blade span /
  1.499 m", with its leader landing on the dimension line.

- The value: `1.499 m` at three decimals (NR-043, signed `88277f6`).
  The dimension reads the built blade span, inner edge to tip.

- The drawn source line now reads "rows NR-011 · NR-017 · NR-043".

- The generator (`9cecee3`) carries the dimension geometry, the label,
  and four clearance self-checks. The leader clears the blade and the
  extensions. The dimension clears the blade. The `ktd dim arrow`
  style joins the element library (v1.1).

## 2. Evidence

- Two full runs stay byte-identical across all five outputs. Log:
  `scratch/fig_sa_v4_repro.log`. md5s: tex `5bf748ab`, html `620481ca`,
  ledger `9f5e89ac`, pdf `45a99a61`, png `aae4915c`.

- The compile reports zero error lines and zero overfull boxes.

- The label ledger moves 30 to 32 strings ("blade span", "1.499 m").

- `scratch/fig_sa_v4_check.py` and its log: the ledger counts, the
  stamps, and every manifest hash recompute.

## 3. Records updated

- `register-status.md`: the NR-043 row, the drawn precision, the v4
  hashes, the re-cut record, delta v2.
- `manifest.json`: the register rows, script commit `9cecee3`, the
  output hashes.
- `captions.md`: the provenance line and the generation note.
- `SPEC.md`: the bound value and the check line.
- `figure-map.md`: row 2 and delta v23.
- The draft master: the seat marker and the exhibit row cite NR-043,
  and the appendix hash block carries the new outputs.

## 4. Handoffs

- @aero-validator: the counter-read (F-VALUE class) on the new pins.
- @science-validator: the plate census, and the NR-043 note in the
  register.
- @author: the next draft build picks the new plate bytes and the
  appendix hashes. The Track D label picks ride a later re-cut.

---

figures-images-diagrams, 2026-10-13.
