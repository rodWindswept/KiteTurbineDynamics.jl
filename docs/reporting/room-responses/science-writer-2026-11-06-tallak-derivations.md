# Room response: the Tallak derivation blocks and the E3 power-gap rewrite (2026-11-06, science-writer)

**Status** Ten blocks verify. Three take an adjustment. None fails.
**Seat** science-writer. **Read at** `e1f0987`.

## The sources

The file `Tulloch, PhD Thesis Final Submission.md` holds the section 4 equations.
Eq 4.30 sits at line 9642.
Eq 4.31 sits at line 9654.
Eq 4.32 sits at line 9676.
Eq 4.33 sits at line 9723.

Eq 4.34 sits at line 9754.
The 180 degree crossing sits at line 9691.

`src/trpt_twist_limit.jl` line 41 carries the 4.34 plus root.
Line 93 evaluates that root.
Line 118 carries the 4.31 peak form.
Line 119 carries the factored peak.
Line 145 evaluates the capacity.

`axioms.yaml` line 25 carries the Glauert source.
Line 47 carries the R61 peak rule.
The ontology addendum holds the closed forms and the naming call.
O1 sits at line 39 and O2 at line 64.
C5 sits at line 265, C6 at 267, C7 at 269 and C8 at 271.

## The blocks

1. The height block reads as follows.
h(theta) = sqrt(A + B cos theta), A = l^2 - r0^2 - r1^2, B = 2 r0 r1.
VERIFIED.

   Tulloch Eq 4.30 at line 9642 states the same form. `src/trpt_twist_limit.jl` line 96 uses it. Addendum O2 line 73 uses it. h is the ring separation, not the line length.

2. The torque block: tau = -T_N dh/dtheta and Lambda = tau/(T_N r1) = r0 sin theta/h. VERIFIED. Tulloch Eq 4.31 at line 9654 states Q = R1 R2 F_x sin delta / l_s. The derivative of h gives that form. The sign is positive over the open interval. Addendum O2 line 69 states the same moment.

3. The peak angle block: cos delta_peak = (sqrt(A^2 - B^2) - A)/B, for l > r0 + r1. VERIFIED. Tulloch Eq 4.34 at line 9754 states the plus root. `src/trpt_twist_limit.jl` line 41 and line 93 carry the same root. The substitution A = l^2 - r0^2 - r1^2 proves the identity. The condition keeps A^2 - B^2 positive.

4. The peak-past-90 block: delta_peak > 90 degrees and delta_peak = 90 degrees + r0 r1/l^2 + O(l^-4). ADJUSTED, units. The inequality holds because the cosine is negative. The series holds in radians as pi/2 + r0 r1/l^2 + O(l^-4). The block adds a radian term to 90 degrees with no conversion.

   The degree form needs the factor 180/pi on the correction. Addendum C8 at line 271 states the radian form. The check reads 90.0718 degrees against 90.0716 at r0 0.5, r1 1, l 20.

5. The peak-torque block: tau_max = T_N (h(0) - h(pi))/2. VERIFIED. `src/trpt_twist_limit.jl` line 119 carries the factored form. The numeric maximum of the torque curve agrees to 1.9e-10. The literature check by the room does not find this form in Tulloch. Samara states it at line 5 of the results note.

6. The margin block reads as follows.
M(theta_op, delta_peak) = sqrt(1 + c^2 - 2 c cos theta_op)/sin theta_op. Here c = cos delta_peak.
VERIFIED. The value is tau_peak/tau_op. It reads 2.0252 for S1 and 2.6883 for S5 from the printed twist and peak alone.

   The signed rows read 2.0287 and 2.6936. Both forms round to 2.03 and 2.69. Addendum Q2 at lines 171 to 173 states the form. The literature check by the room does not find it in Tulloch.

7. The inverse block: cos theta_M = (c + sqrt(c^2 - M^2 (1 + c^2 - M^2)))/M^2. VERIFIED. It is the inverse of block 6. The check returns M 2.0 and 3.0 to ten digits. Addendum C6 at line 268 states it.

8. The zero-crossing block: tau = T r0 r1 sin delta / L, so tau = 0 at delta = 180 degrees. ADJUSTED, domain. The statement holds for l at or above r0 + r1. For l below r0 + r1 the rings meet first and tau does not cross zero. Addendum O2 lines 77 to 90 state both cases. The block must print the domain condition.

9. The crossing-angle block reads as follows.
delta_crit = pi if l >= r0 + r1, else arccos((r0^2 + r1^2 - l^2)/(2 r0 r1)).
ADJUSTED, name. The piecewise form is correct for the zero crossing. Addendum C5 at line 265 states it.

   R61 moved the fatal line to the peak. The delta_crit in the report is the peak (NR-022). The fold must print delta_zero or delta_touch here, not delta_crit.

10. The torque-ratio block reads as follows.
y(x) = sin(x delta_peak)/sqrt(1 + c^2 - 2 c cos(x delta_peak)), x = delta/delta_peak.
VERIFIED. The value is 1/M and the torque ratio. It reads 1 at x = 1 and 0 at x = 0. Addendum Q2 at lines 171 to 173 states the form.

11. The Glauert power block: Cp(a, gamma) = 4 a (cos gamma - a) sqrt(1 - 2 a cos gamma + a^2). VERIFIED. The maximum at 30 degrees reads 0.519229 at a 0.343369. The `axioms.yaml` line 25 states 0.5192 at a 0.3434. Addendum Q3 at line 204 carries the table.

12. The Glauert cubic block: -3 a^3 + 7 a^2 c - 3 a c^2 - 2 a + c = 0, c = cos gamma. VERIFIED. The derivative of the Glauert form gives the cubic. The root at 30 degrees reads 0.343369. Addendum C7 at line 269 states it.

13. The Jensen block: mean(omega^3) >= mean(omega)^3. VERIFIED. The cube is convex on the positive speeds. The inequality is strict unless the speed is constant. The samara results note states it at line 20. Section 2.3 now uses it.

## Number discipline

The closed-form margins sit 0.17 and 0.20 per cent below the extract rows.
The rows read 2.0287 and 2.6936.
The closed forms read 2.0252 and 2.6883.
The draft prints 2.03 and 2.69 from NR-040 at 2 dp.
The one-more-digit form needs a ruling from @science-validator.

The Glauert ceiling 0.5192 gains a row in this pass.
@aero-validator signs NR-086 in the working tree at this read.
The row may print once that sign commits.

## The E3 rewrite

The rewrite lands in section 2.3 at lines 343 to 356.
The draft ticks to v0.90.
The old text named a speed trend, ground-ring drag and the averaging as open causes.
The new text uses the Jensen inequality to rule out the trend and the averaging.

The gap reads 57 W, and the window swing reads 29 W (NR-014).
The gap is therefore systematic.
The torque basis shows the same offset.

The delivered torque reads 396.76 N.m (NR-030).
The load law gives 401.03 N.m at the mean speed (NR-015, NR-029).
The physical source stays open for the gate-trace probe.

No signed row moves.
The cited count holds at 59.
Words read 11,981 from 11,855.
STE holds 31 total at 0.26 per 100 words.
Em dashes read 0.

## Evidence

`scratch/sw_tallak_derivations_check.py` holds every numeric check.
It returns the margins, the series, the peak identity, the inverse, the Glauert root and the Jensen sign.
The check does not write.

## Deltas

- v1 (2026-11-06): created.

science-writer, 2026-11-06
