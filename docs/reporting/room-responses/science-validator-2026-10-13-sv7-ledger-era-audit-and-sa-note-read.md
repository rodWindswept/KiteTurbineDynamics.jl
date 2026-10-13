# Room response: SV7 ledger and era audit; the system-anatomy note read (2026-10-13, science-validator)

**Status** SV7 discharges: the six failure-ledger dates and the four era rows verify at the sources. The system-anatomy note read holds at `ee708d7`. **Seat** science-validator. **Read at** HEAD `6f22af1`. Committed bytes plus checker runs.

## 1. SV7: the failure ledger, audited

The six entries verify against the trust log, the commit record and the captured return. Dates, classes and status markers all hold.

| # | Entry | Commit corroboration | Class and status |
|---|---|---|---|
| 1 | 2026-08-14 inverted-taper divergence | `7183f96` 08-14, the reject. `542e148` 08-15, Rod-dated 08-14, the tip-speed sanity and the r_hub lo 0.7 bound | Geometry/decoder failure. Lesson applied |
| 2 | 2026-08-26 rotor-to-ring off-by-one | `828668d` and `fe8ec77`, both 08-26 | Decoder mapping error. Corrected |
| 3 | 2026-08-22 blade-mass-law correction | `bdc9ae7` 08-22, the unified law. `807efa6` 08-23, the decoded-span pricing and the winners VOID | Model correction. Data voided, record kept |
| 4 | 2026-08-13 k-alignment fault | Landing `f9f31ec`, 08-14 11:32. No commit carries 08-13 | Gain misalignment. Caught and corrected |
| 5 | 2026-08-24 stale-gain re-gate | `026c734` 08-24 | Stale configuration. Corrected |
| 6 | 2026-08-22 FoS=Inf guard gap | `402697b` 08-22, with `73528ac`, `e703162` and `2126fc1` | Gate near-miss. Near-miss, no corrupted survivor |

The classes re-read the trust log rows. The status markers re-read the draft section 4.2 sentences. The numbers quoted by the table hold. The 1.94 gain, the 5.18 kW re-gate and the 5.19 to 5.28 kW voided winners all read in the records.

## 2. SV7: the era map, audited

Every era maps to anchors the register signs.

| Era row | Anchor | Check |
|---|---|---|
| Before the bank derate | The era the derate closed, `94223eb` 10-01 and `b835ebc` 10-07 | "Superseded as era record" reads in draft section 4.2 |
| The bank-derate basis | NR-019, NR-020 | Exponent 2.65 in use. The measured 0.854 at 20 degrees sits against the cos^2.65 fit 0.848 |
| cp fix and the folded class | NR-027, NR-028 | Six rows FAIL (NR-027). The folded class reads 5.3691 (NR-028). "Span shrink" reads the D1 record, draft line 261 and the 10-10 attribution receipt |
| The wind-authority era | The register header, the glossary row, the stamps | The era string reads in the register header and the extract stamps. `95c385d` pins the site spec |

Verdict: the era text stands. No row needs a correction.

## 3. Two landings ride one day after their dates

Two entries carry the record date with a next-day landing. Both are named above.

- Entry 3. The correction reads 2026-08-22 in DECISIONS, the draft and the archive dir name. The pricing and VOID commit lands `807efa6` on 08-23.
- Entry 4. Every record dates the fault 2026-08-13, the trust log, DECISIONS, the exploit register and the feedback table. The landing is `f9f31ec` on 08-14.

This seat recommends keeping the record dates. They match the records the ledger cites, and the landing pins travel in this receipt.

## 4. The system-anatomy note read at `ee708d7` holds

- The note cites NR-043 with the signed value, the form `1.499 m` at three decimals, the scope line and the v4 re-cut plan. Every token re-reads the row.
- The caption counter-read re-ran the kit checker. It exits clean, and the rerun reads byte-identical to the committed log.
- No plate byte moves. The landing's figures tree changes are the map, the note and the captions alone.

## 5. Evidence

- `scratch/sv_sv7_audit_check.py` and `scratch/sv_sv7_audit_check.log`: 60 checks, all pass.
- `scratch/sv_sa_caption_check_rerun.log`: the caption checker rerun, byte-identical to the kit log.

---

science-validator, 2026-10-13.
