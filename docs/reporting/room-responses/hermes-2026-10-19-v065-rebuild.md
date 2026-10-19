# Room response: the v0.65 rebuild (2026-10-19, hermes)

**Status** LANDED. **Seat** hermes. **Read at** `66060fd` (branch `bank-derate-cos2p65`). The rebuild ran off-peak. The D4 proposal fold rides the same train.

**Scope** This response closes the rebuild gate. The re-stamp (`c0e72f2`) cleared the last hold. The rebuild runs the DOCX and the PDF from the tip. The D4 proposal fold also lands here as its own commit.

## The rebuild

The build runs `build_draft_docx.py` and `build_draft_pdf.py` from the tip. Both read draft `a9dc348` and the register file at `3407925`.

The citation gate exits 0 on both routes. It reads 56 cited rows, every one signed. The signed set holds 63 rows. The uncited set reads NR-024, NR-035, NR-037, NR-038, NR-054, NR-062 and NR-063.

Nine of nine seats resolve. The draft carries nine `[Figure seated:` markers. The DOCX carries nine media entries. The seat list reads `system-anatomy`, `machine-winner-hero`, `ring-utilisation`, `twist-limit`, `pca-landscape`, `pca-atlas`, `machine-corner-grid`, `machine-evolution-strip` and `scaling-ladder`.

The three counts agree: nine markers, nine seats, nine media entries. The build re-renders nothing. The kits embed as shipped.

## The copies

The DOCX reads md5 `80e01b5d…`. It is byte-identical to its archived build `draft-a9dc348-20261019-102740.docx`.

The PDF reads md5 `7bbe4dff…`. It is byte-identical to its archived build `draft-a9dc348-20261019-102746.pdf`.

## Probes

The DOCX text reads `v0.65` once and `v0.64` zero times.

The retired term `seat checks` reads zero. The house term `the pipeline` reads twice. The two sites are the expansion-rotor sentence and the swapped ladder sentence.

## Receipts

The D4 proposal fold lands as `66060fd`. The file `docs/plans/2026-10-07-state-fed-regen-cap-proposal.md` joins `.ste-exempt` as a dated plan record. No content moved. The file lands exactly as drafted.

## Handoffs

@author: the rebuild verification keys this copy. Record draft `a9dc348`, register file `3407925`, live md5 `80e01b5d…`.

hermes, 2026-10-19.
