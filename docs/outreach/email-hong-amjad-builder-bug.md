Hi Hong, Amjad,

Great questions — they prompted a proper audit of the code, which turned up something important. Answers first, finding after.

1. λ (blade scale). Dimensionless — not metres, and not tip-speed ratio (sorry, bad symbol choice on my part; I'll write s_b from now on). It's a multiplier on the blade linear dimensions (tip radius, root radius, chord) relative to our V10 reference design, with the ring/tether geometry held fixed. So blade planform area scales as λ², which is why the generator constant is scaled k ∝ λ² across blade sizes. λ = 0.85 means blades at 85% linear size, 72% area.

2. FoS. Exactly your standard definition, failure load / applied load, applied per structural member. Each ring is modelled as a polygon frame of straight CFRP tube segments (not a continuous hoop — hoop Euler over-predicts capacity 5–10× at this geometry). Per-segment we compute a combined beam-column utilisation: axial compression over the Euler column buckling load (fixed-fixed ends) plus resultant bending over elastic moment capacity. FoS = 1/utilisation, and the quoted number is the minimum over all airborne rings. There is no direct relation to the generator k — k only sets the load path: τ_gen = k·ω² determines the torque transmitted down the TRPT, which sets the twist of the line helix, which sets the inward pull at each ring vertex, which sets ring compression. More k at a given speed → more compression → lower FoS.

3. k2. Yes — k = 2 in the MPPT law τ_gen = k·ω² (ω in rad/s, τ in N·m, so k has units N·m·s²).

4. The 30-second spin. It's a launch transient before equilibrium, and the generator is fully OFF during it (k = 0) — so "30-second MPPT" was sloppy wording by me. Sequence: settle the structure statically → spin the whole stack up (in hardware this is a short motoring phase from the ground station; in the sim we initialise at ~287 rpm) → 30 s at zero load so the rotor finds its aerodynamic free speed → then engage k. The point is that these high-RPM equilibria are unreachable from rest: our standard equilibrium finder sweeps ω downward from ~90 rpm and is blind to the 300–480 rpm branch, which is why 6 of 8 blade scales were mislabelled "failed."

6. Ring compression. In-plane, in the ring's own members: the straight segments between tether attachment points carry compressive force along their member axes (circumferential direction). The loading that causes it is radial — the inward components of line tension once the TRPT twists into a helix under torque — but the failure mode is column buckling of individual segments in the ring plane, not compression along the turbine axis.

5. What r means — and the honest finding. r was intended as a scale factor on the bottom-ring radius. But while double-checking it for you, we found a design-vector ordering bug in the system builder: the vector is packed in one field order and decoded in another. Consequence: every simulation behind the results and charts I sent — the kickstart runs, the wind sweep, the catalog — actually ran a 3-line triangle-frame TRPT with 22 rings and an untapered ~3 m radius, not the 12-sided optimised geometry in the design file I pointed you at. The simulations themselves are sound (the dynamics, control, and FoS machinery all operate on the geometry actually built, and the dashboard renders the same triangle system), but the geometry labels I gave you were wrong, and Amjad's parameter summary would have inherited that. Apologies — please put the geometry columns on hold.

Ironically the triangle may be the more defensible machine anyway: it matches our physical Daisy hardware (3-line TRPT, 3 blades), and our BEM strip model is only validated up to ~6 lines, so the 12-sided optimum was resting on provisional aerodynamics. But that should be a deliberate choice, not an accident.

What we're doing about it: fixing the builder so it constructs exactly what the design file says, adding regression tests so this class of bug can't recur, re-running the three key sweeps on the corrected geometry, and re-issuing the charts with verified parameter tables. I'll send the corrected package before I'm up in Glasgow late next week — happy to walk through it in person, and it should give Amjad a clean parameter set for when he's back from leave.

The qualitative story I shared stands on the triangle system as simulated: small blades stall below ~7 m/s, need a kickstart, then find high-RPM equilibria with better FoS. Whether the exact numbers (117 kW / 225 kW etc.) survive the geometry correction is precisely what the re-run will tell us — I'd rather hand you numbers we've verified end-to-end than defend ones we can't.

Looking forward to meeting / discussion — this episode highlight a need for it.

Best,
Rod
