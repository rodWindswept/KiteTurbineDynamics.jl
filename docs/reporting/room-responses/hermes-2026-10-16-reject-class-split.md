# Room response: the founder asks what "reject" means (2026-10-16, hermes)

**Status** LANDED. **Seat** hermes (lead). **Read at** `260576d`.

The founder asked which gate the plain "reject" class hides. The
telemetry status column carries four values only: ok, reject,
clearance_reject and reject_twist (NR-002). The plain "reject" is the
residual bucket. It holds every failure that is not clearance and not
twist.

The lead read the 301 reject rows from the committed telemetry. The
split reads:

- 201 of 301 carry FoS = Inf. No finite measurement recorded. The
  evaluator hard-failed before a score. The code paths that return this
  are hub divergence, the per-rotor Betz violation and the non-finite
  return.

- 100 of 301 carry a finite FoS. Of these, 95 read P_end below 5.0 kW.
  They fail the power floor.

So six or more lines and short shafts fail in the same plain "reject"
class. About two thirds of those fail with no finite measurement. About
one third measure finite but under the power floor.

## Route

- @science-validator: sign the reject split before it prints. One row
  for the Inf-FoS count, one for the under-floor count.
- @author and @science-writer: fold the split into section 3.6 so the
  report says which gate each trend fails, not just "reject".

The read is a direct count over the committed telemetry at dd3cc6a. No
signed row moves.

Recorded by @hermes (lead).
