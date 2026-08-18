# F9 — prose: "The anchor" (29 April 2020 test vs the calibrated model)

Every claim in this report stands on one measured day. On 29 April 2020 the
mast-mounted six-blade TRPT-5 ran for 1,206 synchronized rows of wind,
power, cadence and controller data over about six minutes (15:03–15:09) —
the same configuration Oliver Tulloch modelled as config 9 in his PhD.
This figure is that day, against the calibrated model: same geometry
(2.22 m rotor, 1.52 m ring, 9.5 m chain at 10°), same generator (the
measured τ(ω) table — 30-s steady-block means from the Quarq and controller
logs), same bucket (constant 118 N), same wind shear (Hellmann α = 0.14
from the 5 m anemometer down to the 1.65 m hub).

The measured points are 30-s means, and that choice matters. The raw
1–2 s rows show wind excursions from 3.3 to 9 m/s, but those are gust
lulls and squalls lasting seconds: during a lull the anemometer reads
3.3–4.4 m/s while the rotor, still turning at ~110 rpm, delivers
120–400 W. The instantaneous pairs are phase-lagged — the machine's
inertia carries the power while the wind reading falls — so raw-row bins
at the extremes are transients, not operating points, and a raw bin can
even exceed Betz. Averaged over 30 s the test genuinely covered 5.5 to
7.0 m/s, and the honest envelope is what the figure shows.

Within that band the model lands on the measured numbers. At 6.25 m/s the
model delivers 231 W against 223 ± 79 W measured; both sit at a system
power coefficient of about 0.16 — the same number Oliver's spring-disc
model produced (Cp_max = 0.166 for the six-blade). Three independent
derivations — field, spring-disc, and this ODE — agree where they can be
compared. The measured power varied with the controller's ramping more
than with wind (186–281 W across the 1-min means Rod charted on the day —
the VESC "Too Slow 4 gen" state, dial settings, tension responses) — so
the "curve" is a scatter band, and the model sits in it.

The two honest disagreements, both labelled. Below 5.75 m/s the model
sits on its no-regen floor — outside the tested band entirely, so the
low-wind behaviour is a model prediction the field data neither confirms
nor denies. Above 6.5 m/s the model keeps climbing (370 W at 8.75 m/s)
while the field never went past ~7 m/s steady: the torque table was only
ever observed at 9.8–12.9 rad/s, and the flat extrapolation beyond it
lets the model overspeed — a table validity limit, not physics.

The second panel shows the speed story: the field controller held the
machine at 9.8–12.9 rad/s (TSR setpoint 5.5, actual 4.35) while the model
parks at the AeroDyn peak, λ ≈ 7.6, at 16–29 rad/s. The model reproduces
the power of the anchor at a different speed — the known six-blade
modelling gap Oliver himself flagged as the largest in his thesis (the
AeroDyn three-blade-plus-solidity representation). This is the honest
basis: power, yes; torque-speed balance, still a documented calibration
item.
