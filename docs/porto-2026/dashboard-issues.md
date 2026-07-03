# Dashboard Issues — 2026-06-29

## 1. No live k_mppt value display
**Symptom:** The k_mppt slider shows its static value but there's no live readout showing what
k_mppt the simulation is actually running at during auto-ramp.  The slider animates (line 1042)
but the numeric label doesn't update to show the current value.
**Fix:** Update `vl_kmppt` in the auto-ramp callback alongside `sl_kmppt.value[]`.
**Priority:** High — user can't verify controller action.

## 2. Controller stuck in RAMPING when power is decreasing
**Symptom:** Auto-ramp stays in RAMPING state even when power trend is going down.
**Cause:** The HOLDING transition requires power within ±hold_pct of target AND struct_mult ≥ 0.99.
If FoS is below the soft limit, struct_mult < 1.0 and HOLDING never engages.
**Fix:** HOLDING should only require power stability (±5% for 3s), not structural margin.
The structural guards should limit the ramp rate, not prevent HOLDING.
**Priority:** High — controller never reaches steady state.

## 3. Compression problems at low rings near generator
**Symptom:** Visible in the 3D view — rings near the ground show more compression/buckling.
**Analysis:** Expected — torque accumulates toward the generator, so bottom rings see highest
torsional load.  The FoS taper should be protecting these rings.
**Fix:** Verify the FoS per-ring computation is identifying the limiting ring correctly.
Consider adding a per-ring FoS display to the dashboard.
**Priority:** Medium — physics observation, not a bug.

## 4. Configuration says "3 rotors" but turbine has 4
**Symptom:** V10 Tight label says "3 rotors" but the 3D view shows 4 (top hub rotor + 3 expansion).
**Cause:** `build_v10_tight_no_lowest()` drops the lowest expansion rotor, leaving 3 expansion
rotors. The hub rotor makes 4 total. The label should say "3 expansion rotors" or "4 total rotors".
**Fix:** Update the label string.
**Priority:** Low — cosmetic.

## 5. Kp slider range — is 7.5e-04 appropriate?
**Symptom:** The Kp slider shows 7.5e-04 (default was 1e-4). Log scale from 1e-5 to 1e-3.
**Analysis:** For V10 Tight at 50 kW with Kp=7.5e-04 and P deficit ~50 kW:
Δk per frame = 7.5e-4 × 50000 × 0.02 = 0.75. Over 10s (500 frames): Δk = 375.
That's quite fast — it would ramp k from 20 to 395 in 10 seconds.
The original auto-computed Kp was 1e-4 (much slower).
**Fix:** Extend log range to include smaller values: 1e-6 to 1e-3, default 1e-4.
**Priority:** Medium — affects controller behaviour.

## 6. Elevation factor slider jump
**Symptom:** Slider jumps between set value 1.0 and range when moved.
**Analysis:** This is a pre-existing issue with the lift device slider, not from our changes.
**Fix:** Defer to separate investigation — likely a Makie slider range/step issue.
**Priority:** Low — pre-existing.

## 7. Missing controls from the redesign plan
**Checklist against plan:**
- [x] Generator Control panel with k slider
- [x] Auto-Ramp toggle with large state indicator
- [x] Kp slider (log scale)
- [x] Structural Guards panel with FoS sliders
- [x] Tulloch collapse margin slider
- [x] System panel with elevation
- [x] Depower panel with controls
- [ ] Live structural readouts (FoS, margin, T_max) — NOT IMPLEMENTED
- [ ] Collapsible sections — NOT IMPLEMENTED
- [ ] Live k_mppt value label — NOT IMPLEMENTED

**Priority for missing items:**
1. Live k_mppt value (high — needed for #1 above)
2. Live structural readouts (medium — Phase B of plan)
3. Collapsible sections (low — Phase B/C)
