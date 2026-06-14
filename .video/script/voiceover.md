# .video/script/voiceover.md — Narration Script

---

## SCENE 1 — The Problem (60s)

Kite turbines are different. Instead of a heavy tower, they fly. The rotor spins in the air, and power comes down through a tensile shaft — a TRPT. No tower. No gearbox at altitude. Just tethers under tension transmitting torque to a generator on the ground.

But the TRPT has a problem. As you scale up the power, the shaft mass doesn't scale linearly — it scales worse. This is the TRPT scaling wall.

[AIR: Mass/power curve animating upward, bending away from ideal]

Our own simulator found this. Version 2, version 3, version 4, version 5 — each campaign improved the design, but the fundamental scaling curvature remained. At 10 kilowatts, the shaft weighs 11 and a half kilos. At 50 kilowatts, it's nearly 80. The mass-to-power ratio gets worse, not better. For airborne wind energy, where every kilogram aloft costs you, this is an existential problem.

---

## SCENE 2 — Why It Happens (45s)

Here's why. The TRPT shaft is a stack of rings connected by tension lines. When the rotor produces thrust, the lines pull inward on each ring. That inward force puts the ring beams in compression.

[AIR: Ring diagram, arrows showing inward forces, beam buckling]

Compression means buckling. Euler told us in 1757: the critical load is pi-squared E I over L-squared. More power means more thrust, means more compression, means thicker beams or more rings. Either way, more mass.

And there's a second constraint — torsional collapse. The shaft has to transmit torque without the lines going slack. Tulloch and Wacker derived the criterion: it depends on ring radius squared. Small rings at the ground end are the bottleneck.

Both constraints point the same way. More rings, heavier beams, worse scaling.

---

## SCENE 3 — The Concept (90s)

What if the rings could spread themselves?

[AIR: 3D TRPT shaft, expansion blades appearing on rings near the hub]

Instead of passive carbon-fibre compression rings — dead weight — we mount aerodynamic blades on the rings. These are the same blades as the generating rotor. Same span. Same chord. Same count. Same mould. The only difference: they're banked.

[AIR: Banking animation — blade tilts ~20° toward next ring down]

The blade tip drops toward the next ring down on the TRPT. As the shaft rotates, these blades generate lift from the apparent wind. That lift, resolved through the bank angle, pulls the ring outward — spreading the tether lines, increasing the effective ring radius.

[AIR: Side-by-side comparison — generating rotor blade = expansion blade]

Same blade. Different job. The generating rotor makes torque. The expansion rotor makes radial force.

---

## SCENE 4 — The Physics (90s)

Let's look at the forces on one ring.

[AIR: Force diagram — ring with blade, apparent wind vector]

The expansion blade is at the ring radius. The apparent wind has two components: the free-stream wind, and the rotational speed — omega times r. This is the same apparent wind that drives any wind turbine blade.

For a 5-meter blade on the hub ring, at 9.5 radians per second, the apparent wind is over 40 meters per second. The dynamic pressure drives blade lift of 2,800 Newtons per blade. Times five blades — that's 14,000 Newtons of total lift.

[AIR: Resolution diagram — sin/cos split]

Resolved through a 20-degree bank angle: 4,800 Newtons pull the ring outward. That's nearly 1,000 Newtons per tether attachment point, directly counteracting the inward compression.

[AIR: Force-first equation with numbers]

Our model injects this radial force directly into the structural solver. We compute the ring compression with and without expansion — and the difference is real.

---

## SCENE 5 — The Model (60s)

Everything I'm showing you is open-source. The simulator is KiteTurbineDynamics.jl — a Julia package with 917 tests, all green.

[AIR: Screencast — terminal running test suite, 917/917 pass]

The expansion rotor model is 175 lines of Julia. The force-first structural integration touches four files. We have a standalone verification script that computes per-ring expansion forces so you can check the physics by hand.

[AIR: Screencast — verification script output showing F_radial numbers]

And we fixed a subtle bug in the system initialisation — the settle function — so expansion rotors reach operating speed correctly at frame zero.

---

## SCENE 6 — The Dashboard (45s)

But equations aren't enough. You need to see it.

[AIR: Screencast — GLMakie dashboard with expansion rotors]

We built an interactive dashboard. Launch it with the expansion flag — 20-degree bank, 3 rotors — and the simulator runs the full multi-body dynamics. Cyan diamonds mark the expansion rotor positions. The HUD shows blade span, chord, bank angle, number of blades.

[AIR: Mouse moving over expansion ring markers]

This is physics verification by visual inspection. Are the forces where you expect them? Does the geometry match your mental model? The dashboard answers those questions before you commit to a full campaign.

---

## SCENE 7 — The Results (60s)

So does it work?

[AIR: Bar chart — v5 shaft 11.47 kg vs v6 shaft 10.97 kg]

We ran a 60-island differential evolution campaign — 30,000 iterations across 11 design variables. The optimiser found a shaft mass of 10.97 kilograms, down from v5's 11.47. That's a 4.4 percent improvement.

But the really interesting result is what the optimiser demanded. It saturated every expansion-related parameter at the upper bound. Six expansion rotors — the maximum allowed. 45-degree bank angle — the steepest allowed. Eight tether lines — the most allowed.

[AIR: Convergence plot — mass dropping from 72 to 17 kg]

The optimiser wants more expansion than we gave it. That's a strong signal that the physics is real. The blades are earning their keep.

---

## SCENE 8 — What's Next (30s)

This is early-stage research. We've shown that expansion rotors improve shaft mass at 10 kilowatts. The next step is 50 kilowatts — where the scaling wall is steeper and the benefit should be larger.

We're integrating the radial force into the full multi-body dynamics, so transient effects like gusts and startup are captured. And we're planning a peer-reviewed paper for Wind Energy Science.

[AIR: GitHub URL and windswept.energy]

The code is open. The data is public. The dashboard runs on any Linux machine with Julia. If you're at AWEC and this resonates — come talk to us. There's a lot more to build.
