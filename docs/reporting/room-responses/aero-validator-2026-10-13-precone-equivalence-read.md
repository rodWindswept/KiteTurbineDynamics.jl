# Room response: the AeroDyn pre-cone equivalence read (2026-10-13, aero-validator)

**Status** founder return note 10 discharges on this read. The equivalence
holds. The gloss can fold. **Seat** aero-validator. **Read at** HEAD
`17e6b89`. Committed bytes plus the NAS AeroDyn deck.

Note 10 reads: "the equivalent term in AeroDyn is pre-cone". This read
covers the term, its backing, and the form the fold takes.

## 1. Verdict

The equivalence holds. The record keeps this mapping already. Bank reads
as the AeroDyn pre-cone angle. The gloss can install as the note writes
it.

## 2. Backing

- The geometry-knobs record assigns the term (`09-aerodyn-geometry-knobs.md`,
  section 4). The bank row reads "the blade angled out of the ring plane,
  rigid and uniform along the span". The knob column reads `Precone`, "the
  only knob of this kind".

- The same section reads: "`ShftTilt` is where the elevation goes, and
  `Precone` is the banking knob." It also corrects the earlier claim
  that "the bank is a shaft tilt". That correction stands.

- The annotation in the deck, read today from the NAS bytes.
  `aerodyn-v5.0.0/ad_driver_v5.inp` lines 35 and 36 read
  `ShftTilt(1) - Shaft tilt (deg)` and `Precone(1) - Blade precone
  (deg)`. Deck sha256
  `93edcf7ecf8fb042f4a79ae08a3a32b3563ddcb0391891d4683ad572e65602de`.

- The measurement used the knob. The bank-derate rows NR-019 and
  NR-020 (signed) take their values from the precone sweep.
  `10-precone-sweep.md`, section 5 reads "the closest AeroDyn analogue
  to our bank".

## 3. Guardrail, wording only

The term mapping is exact. Two open items stay outside the gloss. Both
sit in the validation file already.

- The pivot. AeroDyn pivots the blade at its root. The bank angle turns
  about the chord axis at the ring (`09`, section 6). Section 8 reads:
  "The pivot geometry is still open, but the magnitude is now measured."

- The radius convention. `10`, section 7 reads: "The precone radius
  convention is open and is not needed for this result."

So the fold installs the term bridge, and no more. Keep the prose off
identity forms, such as "identical geometry". Where the report describes
the measurement itself, keep the phrase from the record: the closest
AeroDyn analogue.

One trap for the fold: shaft tilt is not the bank. `ShftTilt` carries
the elevation. Install pre-cone only.

## 4. Install point and form

Draft `docs/reporting/drafts/2026-10-08-report-first-draft.md`, section
2.1, lines 181 and 182:

> Bank is the blade angle away from the ring plane about its chord axis
> at the ring.

The draft carries no AeroDyn mention today. The gloss is new to the
draft, and it introduces the term. Recommended end form, as the note
writes it:

> the equivalent term in AeroDyn is pre-cone

The author picks the placement: its own sentence after the bank
definition, or a clause joined to it. No value, unit or row moves.

## 5. Dispositions

- No new register row. The mapping is terminology. The values it
  touches stay rowed already: NR-017 (the bank gene), NR-019 and NR-020
  (the derate).

- The tracker item reads "awaits the @aero-validator read". It closes
  on this read. The next tracker pass can take it.

- For @science-writer, optional: "pre-cone" is a candidate cross-term
  on the "bank angle (bank)" glossary row. Not a release blocker either
  way.

## 6. Evidence

`scratch/av_precone_read.py` and `scratch/av_precone_read_2026-10-13.log`.
The script re-checks every anchor above from the committed files and
the NAS deck. It prints 19 checks, all pass, and exits 0.

---

aero-validator, 2026-10-13.
