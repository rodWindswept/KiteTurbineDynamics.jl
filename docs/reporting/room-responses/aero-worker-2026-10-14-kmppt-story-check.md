# Room response: does the report tell the k = 2.24 story? (2026-10-14, aero-worker)

Rod asked in the Signal channel, reading the current docx build. His
question: does the report tell how the team settled on k_mppt = 2.24,
and the performance and safety implications found when varying the load
to operate on opposite sides of the response curve?

## What the draft already says (v0.36, §2.3)

The draft states the load law, the fixed value 2.24 (NR-015), and that
the team selected it in a load sweep of the seed machine (2026-08-22).
One paragraph states the two ends in words: at the light end the seed
reads under the power floor, at the heavy end the power levels off, and
the selected value sits in the working range between them.

## What the draft does not say

- The retired anchors. The closed-form 3.55 (mass-scaled, unanchored)
  and the 5.39 (3-blade anchor, chosen on the broken machine, retired
  because it forces about 9 kW from the seed). Both sit in the runner
  comment at scripts/run_v13_5kw_masslift.jl, not in the draft.
- The numbers. The sweep rows stay out of the report. scripts/results/
  k_sweep_daisy_5kw.csv reads: k=0.5 reject P 3.49, FoS 51.8. k=1.0
  P 5.45, omega 17.64, FoS 47.8. k=1.5 P 6.78, omega 16.59, FoS 42.8.
  k=1.94 P 7.56, omega 15.80, FoS 40.1. k=2.24 P 8.00, omega 15.34,
  FoS 36.4. k=3.0 P 8.89, omega 14.42, FoS 24.3.
- The safety framing on both sides. The light end spins the machine up:
  the runner comment records k=1.0 at omega 17.6, tip about 85 m/s,
  near the 100 m/s ceiling. The ceiling is a hard gate in the code
  (TIP_SPEED_CEILING_MPS, src/objective_evaluator.jl:103). The heavy
  end raises torque and line tension, so FoS falls: 36.4 at 2.24 down
  to 24.3 at 3.0. The draft says only that power levels off.
- The draft itself flags the gap at line 739: the other values need
  register rows first.

## Suggested action

1. science-validator: sign the sweep rows into the register (one row
   per k, from the sweep CSV).
2. author: expand §2.3 with the two retirements, a small k table
   (k, P, omega, tip speed, FoS), and one paragraph each on the two
   sides: tip-speed ceiling at the light end, FoS fall at the heavy
   end.
3. The over-power penalty story (the objective charges 5 kg per excess
   kW squared above the 5.0 floor, so heavy k also costs fitness)
   belongs in the same block.

Relayed only. Nothing edited in the draft or the register.
