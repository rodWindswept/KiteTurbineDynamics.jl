V10 Campaign — Traced Performance Paths Over Non-Dimensional Contour Space
=========================================================================

Accompanying diagram: v10-traced-paths.png
Source campaign: V10, 60 islands, 310,000 evaluations, 14-DoF DE optimisation
Best design: Island 41, 76.75 kg, 12-line dodecagon, 1 rotor, 35° bank

What this diagram shows
-----------------------
A four-panel figure that traces the convergence of 31 differential evolution
islands through the same PCA-projected parameter space used in the non-
dimensional atlas. While the atlas shows static snapshots coloured by Pi
groups, this diagram shows the dynamic paths — how each island moved through
the space, where it hit constraints, and how quickly it found the optimum.

Panel layout:

  Top-left     PC landscape with density background, iso-mass contours,
               all 31 island trajectories overlaid, and constraint boundary
               crossing points marked.

  Top-right    Mass vs iteration on a semi-log scale for key islands,
               showing convergence speed and constraint-wall encounters.

  Bottom-left  Mass vs beam slenderness (L_r/D) for all island paths,
               revealing the constraint gate and descent corridor.

  Bottom-middle  Mass vs lambda gradient (bot/top) for all island paths,
                 showing the basin-selection threshold.

  Bottom-right   Summary findings as text.

Trajectory colour coding
------------------------
  Green  — Fastest optimum-finder (Island 36, 326 iterations to 5% of optimum)
  Orange — Slowest optimum-finder (Island 44, 8,448 iterations)
  Red    — Divergent islands that never found the optimum (6 islands, 80-81 kg)
  Cyan   — All remaining optimum-finders (25 islands total)

White diamonds mark the start of each highlighted trajectory; coloured
diamonds mark the final converged position.

The constraint boundary
-----------------------
Red scatter points in the top-left panel mark every location where an island
crossed the feasibility threshold — either entering the feasible region from
the infeasible wall, or being thrown back out after a reseed. A total of 378
crossing events were recorded across 31 islands (mean ~12 per island).

The boundary sits at beam slenderness L_r/D ≈ 21. Below this value, parasitic
drag on the structural elements exceeds the total aerodynamic power available
from all rotors — the design is an air brake, not a turbine. Every island
that reached the optimum first had to discover and cross this gate.

The boundary is visible as a vertical dashed red line in the bottom-left
panel (Mass vs Slenderness). Paths that approach from the left are in the
infeasible region; crossing to the right enters feasibility. The optimum
sits at L_r/D ≈ 39 — nearly twice the threshold — because mass continues
to decrease with slenderness until the design bounds are reached.

The two-basin architecture
--------------------------
The PC landscape reveals two distinct attractors separated by a fitness
barrier:

  Basin A (76.75 kg) — 25/31 islands
    PC1 ≈ 0.0, PC2 ≈ −2.0
    Slenderness ≈ 39, λ gradient ≈ 4-5
    Expansion-dominant, structurally lean. The global optimum.

  Basin B (80.6-81.2 kg) — 6/31 islands
    PC1 ≈ +0.5, PC2 ≈ −0.5
    Slenderness ≈ 25-35, λ gradient ≈ 8-15
    Moderately lean but poor expansion/thrust balance. A local optimum.

Islands in Basin B never discover Basin A because the path between them
passes through higher-mass (100-150 kg) intermediate designs that the DE's
selection pressure rejects. The basins are separated in Pi-space primarily
by lambda gradient — Basin A designs reduce bottom-blade overshoot to ~4×,
while Basin B designs remain at 8-15×.

This is visible in the bottom-middle panel (Mass vs Lambda Gradient): the
green and orange paths descend below λ_grad ≈ 7 en route to the optimum,
while the red paths plateau at higher gradients and settle at 80-81 kg.

Convergence behaviour
---------------------
The convergence traces in the top-right panel reveal the temporal structure:

  - All islands start at high mass (200-10,000 kg or infeasible) and
    descend rapidly in the first ~500 iterations as they discover the
    feasible region.

  - Spikes back to ~1,000,000 kg are reseed events — the DE population
    collapses, is re-initialised randomly, and must rediscover feasibility.
    The fastest island (36) had 4 reseeds; the slowest (44) had 8.

  - After the final reseed, convergence to the basin floor is rapid —
    typically 200-500 iterations from first feasible entry to within 5%
    of the final mass.

  - The divergent islands (red) show a different pattern: they enter the
    feasible region early, descend to 80-81 kg, and then flatline. They
    never reseed out of Basin B because the DE population has converged
    within that local attractor.

Path efficiency
---------------
The path directness metric (Euclidean start-to-end distance divided by total
path length) quantifies exploration cost:

  All optimum-finders:  1.7% ± 0.8%  efficient
  Divergent islands:    1.6% ± 0.5%  efficient
  Fastest (Island 36):  3.1%          efficient
  Slowest (Island 44):  1.1%          efficient

The DE spends 96-99% of its movement budget on exploration — probing
constraint boundaries, recovering from reseeds, mapping the feasible
region's shape. The "fast" islands are not smarter; they simply started in
regions of PC space with clearer gradient toward the Basin A entrance.

The performance signature
-------------------------
Three Pi-space trajectories define the outcome classes:

  Fast optimum:    Rapid slenderness climb → crosses L_r/D > 21 early →
                   λ gradient drops below 7 → direct descent to 76.75 kg.
                   Islands 36, 45, 49.

  Slow optimum:    Extended wandering along constraint wall → many boundary
                   hits → eventually finds feasible corridor → same descent
                   to 76.75 kg. Islands 43, 44.

  Divergent:       Achieves slenderness > 21 → enters feasible region →
                   λ gradient stalls at 8-15 → settles at 80-81 kg, never
                   discovers the lower basin. Islands 31, 34, 37, 42, 50, 53.

The divergent islands all share the same failure mode: they clear the
structural feasibility gate (slenderness) but never find the configuration
gate (λ gradient). This confirms that the exploration space has a two-stage
performance filter.

What this means for the design space
------------------------------------
1. The global optimum at 76.75 kg is a genuine, tight attractor — 25
   independent DE islands from different random starts all found exactly
   the same basin. This is strong evidence that the result is not a fluke
   of the optimiser.

2. The exploration space is shaped by two non-dimensional gates: a hard
   structural feasibility threshold (L_r/D > 21) and a softer configuration
   threshold (λ_bot/λ_top < 7). Designs that clear only the first gate
   settle at ~15% higher mass.

3. The constraint boundary (378 crossings) is the dominant feature of the
   landscape. Future campaigns with wider bounds should expect even more
   boundary interaction as the DE probes further into the infeasible region.

4. Path efficiency of ~2% is typical for DE on this landscape and should
   be budgeted for in campaign planning. A 10,000-iteration island run
   is not "slow" — it is the expected cost of adequate exploration.

5. The three bound-screaming parameters (t/D, L_r, r_bottom) are all on the
   structural slenderness axis. The next campaign that widens these bounds
   should expect the optimum to shift leftward in PC1 (structurally leaner)
   with the same PC2 (configuration) — confirming that structural leanness
   and configuration balance are genuinely separable optimisation sub-
   problems.
