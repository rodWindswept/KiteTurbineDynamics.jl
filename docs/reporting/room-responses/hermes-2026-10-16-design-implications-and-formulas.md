# Room response: the founder asks for design implications and formulas (2026-10-16, hermes)

**Status** LANDED. **Seat** hermes (lead). **Read at** `81756b6`.

The founder raised two gaps on 2026-10-16.

## Ask 1. Design implications from the trends

Section 3.6 lists four implications but does not answer the founder's
two questions. The data already exists in the lever-statistics-extract
(`docs/reporting/figures/lever-statistics-extract/`, item 5). The
report must fold it.

What improves the score:

- Single rotor. rotor_count 1 reads 68.5 per cent ok. Count 2 reads 1.3.
  Count 3 reads 0.0.
- Three or four TRPT lines. Three lines read 66.9 per cent ok and four
  read 68.9. Six read 4.8. Nine read 2.9.
- A longer shaft length. target_Lr is the strongest lever (rho -0.58).
- Smaller main blades. blade_scale_top is the strongest mass lever
  (rho +0.50).
- Shallower banks and a smaller ground radius.

Where the other designs trip up:

- Multi-rotor machines fail on clearance. The median clearance reject
  carries two rotors.
- Six or more lines fail on reject.
- Short shafts fail on reject. target_Lr is the best reject separator
  (auc 0.74).

## Ask 2. Formulas and the STE gate

The report carries no rendered math. The load law, the power law, the
objective, the penalty terms, the BEM Cp and the Betz ceiling all read
as unicode prose. They should render as LaTeX math.

The founder asks: can formulas sit outside the Technical English
scoring? Yes. ste-lint.py already strips code fences in strip_code.
Extend the same strip to math delimiters (single dollar, double dollar,
backslash paren, backslash square). Formulas then count no words and
score no violations.

## Route

- @author and @science-writer: fold the design-implications story into
  section 3.6, in plain English. The numbers need signed register rows
  first. @science-validator signs the extract values before any prints.
- @software-worker: extend ste-lint.py to strip math delimiters, then
  the author seat writes the formula set.

No signed row moves here.

Recorded by @hermes (lead).
