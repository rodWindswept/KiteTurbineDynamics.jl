# F3 — prose: "The ladder" (delivered power across ratings × lengths)

The optimiser's job is not to find one design — it is to find out what the
TRPT kite turbine can and cannot be. This figure is the cheap DENY/PROVE
signal: seven rated-power targets (5 to 50 kW), six chain lengths (12 to
40 m), 42 designs — each one a baseline (seed) design scaled from the
50 kW canonical family by √(kw/50) geometry scaling and run through the
full ODE gate on the corrected model. The colour is what each design
actually delivered at the ground ring.

An important honesty note: these are seed designs, not the optimised
campaign winners and not a field test. The rating is the design's target
output at the design wind; it sizes the rotor, the lines and the generator
gain together. The ladder asks: does the baseline family transmit at each
rating and length, uncollapsed, unbroken, inside the tip-speed ceiling?

Read it from the top. The 5 kW row delivers 4.4–4.9 kW at 12–21.2 m
(4.58 at 12 m, 4.89 at 18 m, 4.45 at 21.2 m), then degrades — 2.25 kW at
25 m, 3.18 kW at 30 m, 1.36 kW at 40 m. The 7–15 kW rows peak at 18 m
(6.64 / 7.88 / 8.70 kW) and degrade past 25 m. Every class suffers at
40 m, and the 40 m column carries the twist story: the chains cross their
torsional limit at the 7, 10 and 15 kW cells — the 15 kW cell collapses
to exactly 0.00 kW with a twist ratio of 1.26 and crossed tethers.

Then the honest non-result. The 25–50 kW rows sit at ≈0.00–0.01 kW — but
the reason is NOT a power ceiling: the ODE gate never got those machines
spinning. ω_gnd ≈ 0.25 rad/s at every length (vs 8.9–13.6 rad/s for the
5 kW row) — the scaled generator demand (k·ω²) plus the low-λ aero
balance parks the big designs at a standstill. The gate's own minimum is
ω > 0.5 rad/s; the big cells sit just under it. So the ≥25 kW cells
carry no physics verdict: the ladder cannot yet judge those ratings, and
it would be wrong to read them as "25 kW is impossible". Three
code-verified reasons, all test-side (retrospective §4): the seed's swept
area is ~3× too small for its rating at 11 m/s (50 kW at 11 m/s needs
A ≈ 160–190 m², R ≈ 7–8 m — the seed's 4.39 m radius gives ~60 m², a
~16–20 kW rotor; its 50 kW label implies a ~15 m/s design wind); the MPPT
gain scales ∝ P^2.5 while the aero drive scales ∝ P, collapsing the
cold-start balance at scale; and the 50 kW seed genome was never
aero-validated ("structural proportions only — aero eval was broken").
The ladder's real signal is the down-scaled family: 5–15 kW works at
11 m/s.

The ✗ marks are the gate verdicts: power ≥ 2.5 kW AND ω_gnd > 0.5 rad/s
AND no twist crossing AND clearance ≥ 1.5 m. The 5–15 kW rows show which
cells pass (18 m and 30 m mostly) and which fail (25 m, 40 m).

The reader should leave with: 5–15 kW is real for the baseline family at
short-to-mid lengths; the longest chains twist before they stall; and the
ladder's ≥25 kW cells are a gate artifact to fix, not a verdict.
