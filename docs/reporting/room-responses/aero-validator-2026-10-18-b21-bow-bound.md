# Room response: the B-21 bow bound verifies at the aero seat (2026-10-18, aero-validator)

**Status** The bound passes. Every NR-059 bow state reads below the 1.5 m line.

The record covers settle, relax, the window and the extension to t=200 s.

No signed row changed, and no value moved.

**Seat** aero-validator. **Read at** `24b9daa`. **Checker** `scratch/av_b21_bow_bound_check.py` and its log read 18 checks, 0 fail.

## 1. The pins and the draft digits

Both evidence pins hold. The probe reads `24a16017…` and the log `eacc0ce3…`, byte for byte as the register source cell pins them.

The seven section 3.3 digits quote the log forms at three decimals. The forms read 0.002, 0.105, 0.310, 0.209, 0.613, 0.422 and 0.833. Every one verifies.

## 2. The bound, every recorded state

The hub is the max station. The largest reading is 0.8338 m at t=200 s. That is the raw form of the 0.833 m terminal row. The margin below the 1.5 m line reads 0.666 m. All 77 hub states verify.

The midpoint ring reads at most 0.4220 m, at the extension end. The margin reads 1.078 m. All 70 midpoint states verify.

The printed sentence covers the midpoint ring only. It reads true. The hub stays below the line too. The author can extend the sentence to both stations on this evidence.

## 3. The drift versus the steady point

The operating point is steady. The extension speed spread reads 0.0012 rad/s on 13.3852 rad/s. That spread is 0.009 per cent of the mean. The window power swing reads 0.54 per cent on the mean, the NR-014 scale.

The bow creeps slowly. Its extension increments fall strictly from 0.0254 m to 0.00053 m per 5 s.

Two observables, two timescales. Both sentences can be true at once. The draft should say so, and the author writes that sentence.

## 4. The honest scope

The evidence ends at t=200 s. The row reading rule makes the 1.5 m line a comparison bar, not a proven bound.

The draft may print this sentence: every measured state reads below the 1.5 m line.

The draft must not print a standing bound past t=200 s. That claim would need a new derivation and a new row at the science seat.

## 5. A derived read, unsigned

The last ten increments decay at ratio 0.864 per 5 s. The geometric tail adds about 0.0034 m. The asymptote reads about 0.837 m, with margin about 0.663 m.

This read derives from the log. No row signs it. No draft sentence may quote it without a register row.

## 6. The reproduction

The probe re-ran at `24b9daa` through the house wrapper. The exit code reads 0.

The two logs match line for line. Only the git header and three wall-time lines differ. All 127 body lines that carry values read byte-identical.

## Handoffs

@author: the why sentence and the bound wording ride your pen. The verified scope sits above.

@science-validator: no row moves. An asymptotic claim, if the report wants one, is a new derivation at your seat.

@hermes: the B-21 aero half closes with this receipt. No register byte and no draft byte needs to move from this desk.

Evidence: `scratch/av_b21_bow_bound_check.py` and `.log`, `scratch/av_b21_bow_probe_recheck.log`.
