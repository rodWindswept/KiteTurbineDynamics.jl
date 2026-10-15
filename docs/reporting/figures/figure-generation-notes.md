Figure by figure
F1 — System anatomy (row 2)

How to generate. Rewrite d8-system-anatomy.tex. Keep its two panels: (a) side elevation, (b) view along the shaft from the ground station. Replace the V10 geometry with the winner topology. Mark it "schematic, not to scale". F6 carries the scale.

What to draw (the floor list):

Lifter: an autogyro-stack silhouette, labelled "lifter (lift only, no torque)".
Sky anchor: the 300 g three-way knot, with all three legs:
lift line, up to the lifter;
back line, down to the back-line ground anchor, drawn taut (2026-09-15 ruling). Its job is to limit lift-bearing altitude (physics-topology.md §3). The brief omits it.
the line to the lift bearing (name held at Track D).
Lift bearing, then three lifting bridles (one per TRPT line) to the R6 vertices.
R6, the hub ring, radius 4.580 m, carrying the main rotor. The blades straddle the ring: inner edge 4.130 m, tip 5.630 m (0.3 of the 1.50 m span inside, 0.7 outside).
S5, the cone: fixed 22° half-angle, 10.08 m lines, R5 to R6.
S1–S4, the cylinder: radius 0.804 m, 2.363 m lines, rings R1–R5.
R1, the ground ring, at the ground station. Generator label "τ = kω², k = 2.24".
Wind arrow. Two angles, each labelled: shaft elevation 30° and lift-line angle 70°.
Rings as triangles. With n_lines = 3, each ring is a three-sided frame of CFRP tube (R6 side 7.93 m). Panel (b) shows this. Circles would misdraw the machine.

Numbering runs ground to hub: R1 at the ground datum, R6 the hub, S1–S5 the segments between (register block, 1a95ae0). d8 numbers from the hub ("hub rotor (ring 1)"), so flip it.

Separate the line classes by style as well as colour: TRPT lines, lifting bridles (gold, as the dashboard), lift-chain lines, back line.

Cleared for print (build dump at 980de02, science-validator): cylinder 9.4533 m, cone lines 10.0807 m, slope 22.000° by construction. Any lettered length uses the decode set. The pair-extract capture set is a final-state read at t = 50 s, not design.

Corrections to the brief:

"Cyan line" is a dashboard colour, not a name. Hold the label until Track D picks. The 10 October review asks for "bearing line".
The brief's eye path runs "down the lift line" from the knot. Below the knot the line is the cyan/bearing line. physics-topology.md §3 makes the distinction load-bearing: lifting bridle = bearing to rotor; cyan line = sky anchor to bearing.
The brief caps labels at twelve. The floor list holds sixteen terms. Split them across the two panels and an inset. Do not drop the back line to fit.

Blocked by: Track D (the knot name, the bearing-line name). Decision 2: F1 marks the point where the 1.5 × weight check sits, with a dot and the label "lift check point". The code applies it at the lift bearing (NR-026). Your requirement puts it at the sky hook.

F2 — Genome decode (row 3)

How to generate. Make it a table, not a strip. The gene table already exists (9f29df1) and answers Harris 2.2. A table carries the same ten facts as the chips and arrows, and it needs no figure slot.

Winner values (scratch/av_fignums_recheck_1a95ae0.log; meanings from docs/agents/genome-glossary.md):

Slot	Gene	Meaning	Winner	Live at the winner?
x1	r_hub	hub ring radius	4.580 m	live
x2	r_bottom	ground ring radius	0.804 m	live
x3	target_Lr	ring spacing ratio L/r; higher means fewer rings	2.721	live
x4	n_lines	lines per segment (rounded)	3	live
x5	density_profile	ring clustering along the shaft; negative clusters toward the ground	−0.8 (box floor)	dead at winner
x6	rotor_count	rotor count (rounded)	1.037 → 1	live
x7	bank_top	main-rotor bank	7.088°	live
x8	bank_bottom	second-rotor bank	22.0 (box ceiling)	dead at one rotor
x9	blade_scale_top	main-rotor blade scale	0.821	live
x10	blade_scale_bottom	second-rotor blade scale	0.20	dead at one rotor

Add the bounds column from 9f29df1 once it is signed. Under the table, state three decode rules:

x4 and x6 round to integers (run_v13_5kw_masslift.jl:245-246).
No gene sets the ring count. The decoder derives six rings from x3 and the 18.8 m length.
Slots 8 and 10 reach no rotor at a count of one.

Corrections to the brief:

"Six rings", "polygon count" and "ring geometry" are not genes. Ring count is a decoder output. "Polygon count" is n_lines (x4). "Ring geometry" is x1, x2, x3 and x5.
"Bank angle maps to blade orientation about the chord axis": bank is the blade's coning angle out of the ring plane (Harris 1.8, held at Track D).
The fixed 22° cone half-angle (cone_slope_deg) is a configuration constant, not a gene. It belongs in F1. The two 22° values never share a figure.
x5 is dead at the winner (science-validator, tree 980de02). With cylinder_cone=true the cone resolves to one segment, and the cylinder branch returns uniform spacing, so the density bias cannot act. x5 in {−0.8, 0, +0.8} left the build unchanged (max|Δzs| = max|Δradii| = 0.0). Seven live genes, not eight. x5 would act on designs whose cone resolves to two or more segments. The S1–S4 design lines are 2.3633 m each. Design stations 2.363 / 4.727 / 7.090 / 9.453 m. The 2.318 / 4.637 / 6.956 / 9.275 set is a final-state capture at t = 50 s, not design.
Quote evaluator-chain radii in any art. The gate path omits the v_rated knob (11.0097 m/s), the score path uses 11.0. The tip differs by 1.4 mm (5.6282 against 5.6296 m, scratch/av_probe_clearance_knob_1a95ae0.log).
F3 — Evaluation timeline (row 4)

How to generate. Write one probe, scripts/probe_eval_timeline.jl, by copying the tap pattern of probe_window_trace.jl. Two changes:

write a CSV;
sample at 100 Hz, because the committed probe samples at 1 Hz and that misses the warm-start transient.

Columns: t, ω_gnd, ω_hub, P_gen, τ_gen, peak line strain / 0.035 (ROPE_BREAK_STRAIN, rope_forces.jl:89), any_broken. Run it on the winner, cold and warm: two runs, about 45 s each. Plot only from that CSV. Draw no idealised traces.

Layout: shared x axis, 0–50 s. Relax 0–10 s shaded. Measurement window 10–50 s outlined.

Lane	Quantity	Axis	Marks
1	ω_gnd, ω_hub	9–15 rad/s	10.17 rad/s "start: the rotor's Cp-peak speed" (NR-016). 13.38 rad/s "window mean" (NR-029)
2	P_gen	0–7 kW	P̄ 5.309 kW over 10–50 s (NR-008). P_end 5.314 kW over the last five 1 Hz samples, about 46–50 s
3	peak line strain / break strain, cold and warm	0–1.2	break line at 1.0
4	gate map	—	see the table below

The gate map, as coded at a89642b:

Gate	When it acts	Source
Ground clearance ≥ 1.5 m	before the run, at decode	run_v13_5kw_masslift.jl:256-257
Rope break (strain > 0.035)	every step, 0–50 s, relax included	rope_forces.jl:556, 616, 620; checked at objective_evaluator.jl:999-1000
Twist crossing δα*, hub divergence, tip speed, rotor Betz	once per second, t > 10 s only	objective_evaluator.jl:912
Power floor (5 kW) and the over-power term	P_end, the mean of the last five samples	objective_evaluator.jl:1016, 1148

The figure must show two facts the brief misses. Of the gates above, rope break is the only one that reads the relax. The sampled gates read once per second, so a twist crossing between samples goes unseen.

Corrections to the brief:

The speed axis of 8–12 rad/s cuts off the operating speed. Use 9–15.
The power axis of 4–7 kW cuts off the start. At the start speed the load law gives 2.24 × 10.17³ = 2.36 kW. Use 0–7.
10.17 rad/s is not an equilibrium of this machine at k = 2.24. It is the rotor's Cp-peak speed: 5.2 × 11.01 / 5.6296 = 10.1698 rad/s = NR-016.
"Rope-break gate: window only under ruling" describes code that does not exist. The 2026-09-16 ruling is not landed at a89642b: any_broken latches at any step. Draw the code as it is and label the ruling "not yet in the code". Decision 5 decides the warm-lane wording.
"Honest window" becomes "measurement window" (Harris 3.3). The code names :cold and :warm appear in the software section only.

Lane 2 check: closed (aero-validator, tree 980de02). The logged P_gen is τ_gen·ω_gnd/1000, the scored definition. The station is the ground ring. No filter and no losses. Ground and hub rates differ by 0.009 %, so the hub-side reading is dead. The 1.1 % gap is the build payout derate: the builder writes backline_payout 0.1 m (objective_evaluator.jl:619-621), factor 1 − 0.1/9.4 = 0.9893617021276596, exact against the run. A stored-CSV re-derivation brackets it at ±7.5e-11, the file's 9-decimal rounding (science-validator). Spec the column as τ_gen·ω_gnd. Never k·ω³.

Lane 3 data, from the certified extract: cold strain runs 0.021 to 0.032 of break. The warm as-coded run is 98 rows, ending at t = 2.841 ms with strain 1.00081. The ruling-mode condition run peaks at 1.448, the extract grid max at t = 5.798 ms (per-step read 1.44819 at t = 5.740 ms), then rings without settling (window 8.6 to 23.4 rad/s and 1.4 to 28.4 kW; window means 12.64 rad/s and 4.96 kW). Draw the ruling-mode curve only under the condition-run label; decision 5 decides the warm-lane wording. Axis note: 0 to 1.5 admits the ruling peak; 0 to 1.2 can return if the condition curve drops. Both drawn values re-derive from the committed extract and stay row-wants until the NR-013 extension lands (science-validator).

Draft render: scratch/fig_f3_draft/ (figures seat), generator scratch/fig_f3_eval_timeline_draft.py.

Merge option. Lane 3 (warm against cold strain) is the core evidence of row 12, the fidelity band chart. F3 can carry row 12 and free a slot.

F4 — Campaign architecture and status mix (new row)

How to generate. Read the three telemetry files: 310 rows each, generations 0–30, columns gen, status, fitness, P_mean, P_end, FoS, twist_ratio, clearance. No runs.

What the brief's single funnel hides (my count):

Generations	Feasible designs
0	3 / 30 = 10.0 %
1–10	26 / 300 = 8.7 %
11–20	196 / 300 = 65.3 %
21–30	283 / 300 = 94.3 %

At generation 0, only the seed is feasible in each island: nine of the ten starting designs fail. The search spent its first third finding the feasible region and its last third inside it. One 930-design funnel at 54.6 % averages that story away.

Layout:

Panel (a), the search set-up: three islands, NP = 10, generations 0–30, rand/1/bin, F 0.5–0.8 and CR 0.7–0.9 redrawn per vector, RNG seeds 42–44, one common seed design, no migration. Draw no arrows between the islands.
Panel (b), status per generation: stacked bars, 31 bars, pooled across islands.

Per-island totals (my count; they sum to NR-002):

Island	Feasible	Rejected	Clearance	Twist
1	152	108	47	3
2	162	111	35	2
3	194	82	28	6

Correction: "reject: failed primary gate" is not in the record. The 301 rejects split three ways (my count):

Subgroup	Count	What the telemetry shows
Ran; power below the 5 kW floor	96	P_mean < 5
Ran; power ≥ 5 kW; FoS below 2.5	4	FoS < 2.5
Fields zeroed; cause not logged	201	P = 0, FoS = Inf, T_lift = 0

The 201 come from the early rejected_eval() returns in objective_evaluator.jl (settle failure, rope break, hub divergence, Betz, rotor spacing, non-finite score). The runner logs only :reject (run_v13_5kw_masslift.jl:271-272). There are two options:

(a) Print the three subgroups as above. No runs.
(b) Add a reason code to rejected_eval and re-evaluate the 201. That takes at most 2.4 h serial at 43 s each, less on threads. It changes src/, so it needs the acceptance suite.

Recommend (a) for this report and (b) before the next campaign.

Label statuses in words: "feasible", "rejected: rotor below 1.5 m clearance", "rejected: twist past the crossing limit", and the three subgroups. Print no status codes and no Track names.

F5 — Convergence (row 16)

How to generate. Read telemetry, not convergence.csv. That file holds iterations 1–30 and has no generation 0. NR-006 calls the seed "gen 1", while NR-036 calls it "gen 0". Telemetry generations 0–30 give one convention. Running best = the lowest feasible fitness up to each generation. My recompute matches NR-003 to NR-006 and NR-036.

Layout:

x axis: generation, 0–30.
y axis: "search objective (kg)", 26–37.
Three islands, each with its own line style and colour. A common start at 36.109. A star at generation 26, 27.364.
Optional lower panel: P_end of every feasible design, with the 5 kW floor (NR-007 band 5.02–6.32 kW).

Corrections to the brief:

The y label is "search objective (kg)", not mass (NR-036 boundary 1).
The gap between 27.364 and 25.698 kg is the penalty, not "pre-fold against post-fold". The objective is F = m + 5·max(P_end − 5, 0)² + 20·(2.5/FoS)² + (tr/(1 − tr))² (9f29df1). At the winner: 25.698 + 0.493 + 0.558 + 0.614 = 27.364. Put the equation in the caption or §2.4. Drop the speculation.
Islands 1 and 2 improved in their last generation. Island 1 went from 31.018 to 30.578 at generation 30; island 2 from 31.085 to 30.637. The budget stopped the search, not convergence. The caption must say so. This gives "a screen, not an optimum" its data.

Rows needed: the island 1 and 2 running-best series, 31 values each (extend NR-036 or add a row).

Merge. F4 panel (b) and F5 make one two-panel figure: "first feasibility, then mass". This saves a slot.

F6 — Winner hero (row 10)

How to generate. Write the hero capture script for the machine renderer (docs/reporting/figures/machine-renderer/SPEC.md, hero mode). The renderer draws decode plus build, with no ODE. So the drawing shows the design elevation of 30°. The flown values (elevation 28.64°, hub altitude 8.91 m; NR-032 to NR-034 boundary 5) go in the table.

Operating table (replaces the brief's list):

Quantity	Value	Row
Mean power, measurement window	5.309 kW	NR-008
Operating speed, window mean	13.38 rad/s (127.8 rpm)	NR-029
Delivered torque	396.8 N·m	NR-030
Tip-speed ratio and Cp	6.84 and 0.226	NR-032
Cp peak of this rotor	0.309 at λ = 5.2	needs a row (aerodynamics.jl:93-94)
Swept annulus	46.0 m²	NR-033
Airborne mass	25.70 kg; 20.70 kg without the 5 kg lifter	NR-018
Governing margin	2.03, torque, S1; floor 1.5	NR-023; decision 1
Lift-line tension	324.1 N at 70°	NR-010, NR-026
Window swing	0.5 %, in steady 11.01 m/s wind	NR-014

Force inset. Draw one triangle, at the point where the code applies the check: the lift bearing (NR-026). Vertical 304.6 N = 1.5 × 20.698 kg × 9.81 m/s². Tension 324.1 N. Angle 70°. If decision 2 moves the check to the sky hook, the triangle moves and the numbers change.

Corrections to the brief:

"Settle speed 10.170 rad/s" as an operating value becomes 13.38 rad/s.
"Minimum FoS 14.972" as the headline becomes the governing margin, 2.03 on S1 torque. 14.972 is the ring beam-column figure (NR-009). It belongs in F7.
Drop the "vertical lift margin 1.21" label, not the number. The F6 build prints 1.5 as the margin (NR-026). It prints 1.21 as the vertical load over the total airborne weight, definition beside the number (NR-037). Never label 1.21 a margin. The margin applies to the mass net of the lifter. The ratio takes the full airborne mass as the denominator. Draft v0.16 lines 299–301 carried the old sentence; removed in v0.17 (398d4b9).
"Elevation angle 70°" becomes "lift-line angle 70°". The shaft elevation is a separate 30°.
Draw no second rotor. Put bank 7.088° in the table, because at hero scale it is too small to read.
The Cp curve source is the AeroDyn v5.0.0 BEM table, a computation (aerodynamics.jl:93; bem.jl:109-110 returns it unchanged at n = 3). NR-032's source cell still says "measured n = 3 surface". Amend that wording before any caption cites it.
F7 — Margin plate (rows 6 and 7)

How to generate. Extend scripts/extract_pair_capture.jl and re-run it once (about 45 s). Add four column groups:

δα* per segment. This is the twist-crossing limit from twist_collapse_check, the campaign's twist gate. The winner's worst twist/δα* ratio is 0.4393 (telemetry twist_ratio), a gate margin of 2.28.
The realisability floor, 72.25° (sin Δα ≤ 1/1.05).
Sizing-case utilisation per ring. The tubes are sized to Euler FoS 3.25 = fos_hard 2.5 × SIZING_FOS_MARGIN 1.3 (trpt_optimization.jl:199). R6 is sized at the worse of the rated load and the parked peak-wind case (T_peak, ω = 0); R2–R5 at the rated helix envelope (size_beams_closed_form). R2–R5 sit at the 2 mm wall floor, so their sizing FoS may exceed 3.25. Print the value per ring; do not assume it.
Line tension and break load per segment. There is no row for line FoS yet.

Re-render with ring-utilisation.py and twist-limit.py, or merge both into one three-panel plate.

Panel A, rings R2–R6. Operating utilisation as bars; sizing-case utilisation as markers; log axis from 10⁻⁶ to 1. Operating values (NR-021): R2 0.0332, R3 0.0335, R4 0.0284, R5 3.1 × 10⁻⁶, R6 0.0665.

Drop the axial/bending stack. Bending is at most 0.04 % of each loaded ring's utilisation (my count), so the stack draws nothing. State it in the caption.
R5 carries bending only (3.1 × 10⁻⁶), no compression. Print "FoS > 10⁵ (no compression)", not "326,974".

Panel B, segment torque. Plot the margin (capacity / torque), axis 0–3. S1 2.03, S2 2.04, S3 2.04, S4 2.05, S5 2.69 (NR-023). Reference lines at 1.5 (the torsion floor, trpt_optimization.jl:39) and 2.5 (the gate on lines and rings). The plot itself then shows decision 1.

The extract header says its capacity is "the Tulloch authority basis ... not the sim's held conservative Case-B cap". State which capacity the campaign's torsion gate used, and plot that one.

Panel C, twist. Plot |Δα| for S1–S5: 33.95°, 33.81°, 33.68°, 33.55°, 22.82° (NR-022). Draw three limits per segment:

δα*, the gate (new column);
72.25°, the realisability floor;
δcrit: 98.86° on S1–S4, 92.64° on S5.

Measure the margin and the title against the binding limit.

Corrections to the brief:

"All checked elements below their relevant limits, none near" hides the governing case. S1–S4 torque margins of 2.03–2.05 would fail a 2.5 gate. The campaign applies the 1.5 Tulloch floor to torsion. The plate must show both lines until decision 1 is made.
The twist axis set against δcrit (0–100°) measures the wrong limit. The current plate title, "Every segment of the winner runs far below its over-twist limit" (twist-limit.py:75), goes with it.
"Evaluated at the final integration step" holds for NR-021 to NR-023 (s = 1,724,859, t = 50.0 s). NR-009 (14.972) may be a window minimum (10 October item 1.3, still open). Label each value with its capture instant.
Drop the "no limit" hatching. The no-limit class does not occur at the winner (twist-limit/captions.md).

Blocked by: decision 1 (which line is the criterion), decision 3 (the hub-ring load case, its wind speed and parked CT). R6 alone is about 13.3 kg, 52 % of airborne mass (finding B, unsigned).

F8 — Evolution strip (row 9)

How to generate. Nothing new. The strip is built and re-rendered at 74cfef9: two rows (4 + 3) at one scale, square axes, a shaft-frame stamp, and NR-036 labels. Remaining work: F-COUNT and F-PARSE on the new SVG, then sign-off. The SVG text-layer item stays open.

Corrections to the brief:

"Avoid printing mass in the panels" conflicts with the room's declared delta (v8): each panel carries its search objective (NR-036), because without it the strip shows seven similar machines and no story. Keep the labels.
"0.0602 m per pixel on a 1580 × 596 canvas" describes the superseded single-row render.
F9 — Failure ledger (row 13)

How to generate. Build one ledger file, docs/reporting/figures/failure-ledger/ledger.csv. Columns:

date
class (decoder or geometry, model correction, voided campaign, gate near-miss, fidelity ruling, closure)
title
affected data (folder or campaign)
status (VOID, superseded, or caught before use)
detected by (test, review, audit, probe)
consequence
lesson
guard now in the code (test file or gate)
source (DECISIONS.md entry or commit)
