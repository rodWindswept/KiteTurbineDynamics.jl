# DRAFT: Reply to Hong & Amjad (Strathclyde) — for Rod to edit and send

<!-- Status: DRAFT 2026-07-18. Basis: strathclyde_qa_verified.md (Q1-Q4, Q6
     re-verified against current code 2026-07-18) + corrected-geometry results.
     Every number cites its CSV/doc source in an HTML comment — strip before
     sending. Framing per Rod: caveat, not retraction; absolutes bracketed as
     upper bounds pending the momentum-coupled model. -->

Dear Hong and Amjad,

Thank you both for the sharp questions — answering them properly forced a
code-verification pass that caught something important, so this reply comes
in two parts: direct answers, and a correction with its consequences.

## Your questions

**Q1 — λ (blade scale).** λ is dimensionless — a multiplier on blade *linear*
dimensions (tip radius, hub radius, chord) relative to the reference design;
blade area therefore scales as λ², which is why the generator constant is
scaled k ∝ λ² across blade sizes. λ = 0.85 means 85% linear / 72% area. One
flag: in these files λ is **not** tip-speed ratio — apologies for the symbol
collision with the wind-energy convention.

**Q2 — FoS and its relation to k.** FoS is the standard failure/applied ratio,
evaluated per structural member. Each ring is a closed polygon of straight
CFRP tube segments (fixed-fixed, K = 0.5 — deliberately not a continuous
hoop, which over-predicts capacity 5–10× at this geometry). Combined
beam-column utilisation `util = N/N_crit + √(M_ip² + M_oop²)/M_el`; FoS =
1/util, reported as the minimum over all airborne-ring members. k has no
definitional link to FoS — only the load path: τ_gen = k·ω² twists the tether
lines into a helix, the tension's inward vertex components compress the
polygon segments, and Euler buckling of a segment is the failure mode. Higher
k at a given ω → more compression → lower FoS. (This also answers **Q6**: the
compression is in-plane, in the ring's own members — neither along the system
axis nor a uniform radial squeeze.)

**Q3 — "k2".** Yes: k_mppt = 2.0 in τ_gen = k·ω² (ω in rad/s, so k in N·m·s²).

**Q4 — the "30-second" spin.** A launch transient, not MPPT: the generator is
fully unloaded (k = 0) for those 30 s. Sequence: static settle → impulsive
kick of all rings to ≈287 rpm → 30 s free-wheel → generator engaged at target
k → 30–90 s under load, statistics recorded. In hardware this corresponds to a
brief motoring phase from the ground station. The reason it exists: the
high-RPM equilibria (300–480 rpm) are unreachable from rest — a quasi-static
spin-up never finds them. <!-- kick=30 rad/s: kickstart_sweep protocol;
"140+ rpm" in the earlier email described post-free-wheel speed -->

## Q5 — what r means, and a correction

r was *intended* as a bottom-ring radius multiplier on the campaign winner.
Code verification found a vector-packing defect in the builder: parameters
were packed in one field order and decoded in another. The consequence is
that every result we shared (kickstart, catalog, wind sweep) simulated a
**different machine than we believed**: a 3-line triangle frame, 22 rings,
untapered ~2.99 m radius, three 3-bladed expansion rotors at intermediate
stations (bank 18°/11°/4°), λ gradient 1.0→0.88 — not the 12-line tapered
design in the campaign JSON. r never scaled a radius as-built; it silently
switched builder code paths (which also explains an internal catalog-vs-sweep
discrepancy we had been chasing).

Three things about what this means for the numbers you have:

1. **They are reproducible simulations of a now-deliberately-specified
   design.** We rebuilt the triangle system intentionally, from a documented
   spec, and it reproduces the shared results bit-for-bit — e.g. 117.4 kW @
   411 rpm, FoS 4.5 (11 m/s, λ = 0.85, k = 2).
   <!-- wind_sweep_triangle_legacy.csv row 4; phantom gate PASS,
        DECISIONS.md 2026-07-17 -->
2. **The corrected 12-line system is not citable as viable.** With the fixed
   decode (verified field-for-field against the campaign record) it produces
   large converged power but no operating point holds FoS ≥ 1.5 — extended
   captures show the earlier snapshot FoS values were aliased by transients.
   <!-- kickstart_12gon_recheck.csv; DECISIONS.md 2026-07-18 -->
3. **All absolute powers above ~50 kW carry an upper-bound caveat.** Two
   model limits apply: no rated-power curtailment, and — found this week via
   a swept-area/energy audit — the expansion-rotor aerodynamics currently
   lack per-rotor momentum (induction) feedback, so absolute extraction can
   exceed actuator-disc limits. For the triangle at 11 m/s the shared 117 kW
   sits near (moderately above) its corrected swept-union Betz ceiling of
   ~97 kW — so the numbers need a caveat, not a retraction — but treat all
   absolutes as upper bounds until we land the momentum-coupled model, which
   is in progress. We will send corrected estimates as a follow-up.
   <!-- union-Betz: wake_overlap_audit.jl, union area 201 m² @ 30° elevation;
        induction fix: docs/plans/induction_fix_proposal.md -->

Two methodology notes that survive everything above, and that we think are
the genuinely interesting findings: (a) the system is strongly bistable —
the productive high-RPM branch is reachable only through the kickstart
transient, and basin-of-attraction sensitivity to the kick magnitude is
real in both geometries; (b) single-snapshot captures alias badly on this
system — it settles into slow limit cycles, so we now report windowed
statistics (min/mean/max over t ∈ [30, 90] s) with explicit drift checks
between checkpoints.

Amjad — for the parameter summary you're building from the logs: the
builder's printed line (`n_lines=… rings=…`) is authoritative for what was
simulated, and every new CSV now embeds a full geometry fingerprint
(per-rotor blade count, tip/chord/span, areas, masses, taper) in its header
precisely so that cross-configuration tables can't hide a reference shift.

Happy to share the corrected-geometry CSVs, the audit scripts, and the
convergence-recheck protocol if useful.

Best regards,
Rod

<!-- Numbers index (strip):
  117.4 kW / 411 rpm / FoS 4.52 / 77.3 kN : wind_sweep_triangle_legacy.csv,
    0.85/k2/11 row; reproduced by scripts/phantom_gate_test.jl (GATE PASS).
  12-gon geometry: best_design.json vs fixed decode, 10/10 fields
    (n_lines=12, rings=10, r_hub 2.8885, r_bottom 2.000, tether 67.08 m).
  12-gon recheck: kickstart_12gon_recheck.csv — 0.69/k62 326 kW converged,
    FoS_min_window 0.22; 0.80/k62 ~540 kW, FoS_min 0.21; 0.80/k96 transient.
  Triangle 90 s: wind_sweep_triangle3_90s.csv — 11/12 DRIFTING, window stats.
  Betz ceilings: union 201 m² → 97 kW @ 11 m/s, 247 kW @ 15 m/s (triangle);
    128 m² → 62 kW @ 11 m/s (12-gon). scripts/wake_overlap_audit.jl.
-->
