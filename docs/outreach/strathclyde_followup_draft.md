# DRAFT: Follow-up to Hong & Amjad — corrected aerodynamic model (promised in previous email)

<!-- Status: DRAFT 2026-07-19. This is the follow-up pre-announced in the sent
     reply ("We will send corrected estimates as a follow-up"). Every number
     cites its source in an HTML comment — strip before sending.
     NOTE: numbers here are from wind_sweep_triangle3_90s_induction.csv read
     against its own column header (P_gen vs P_aero distinguished). The
     "~20 kW @ 11 m/s" figure circulating in DECISIONS.md 2026-07-19 is a
     column mis-read (P_aero_30) — do not quote it. -->

Dear Hong and Amjad,

Following up as promised: the momentum-coupled aerodynamic model is
implemented, validated, and now the default in our simulator. The result is
a larger correction than the Betz-margin arithmetic in my last email
suggested, and I'd rather give you the full picture than a softened one.

## What changed in the model

Two coupled fixes to the expansion-rotor aerodynamics, both in the direction
of standard rotor theory:

1. **Per-annulus axial induction.** Each rotor's swept annulus is treated as
   an actuator annulus: blade-element thrust is balanced against momentum
   thrust (Glauert empirical branch above a = 0.4, a ≤ 0.5), solved per
   rotor per timestep. Extraction now depletes the inflow that produces it.
2. **Angle-of-attack-based lift.** The previous model flew a fixed design C_L
   at all inflow angles; blades now carry C_L = clamp(2π·(φ − θ), ±1.2), with
   the pitch offset θ back-solved so the design point is reproduced exactly.
   At high tip-speed ratio the blades feather and then brake, as real blades
   do.

Validation: a property-test suite (≈800 assertions) enforces that every
rotor across the operating grid converges and respects its per-annulus Betz
limit, that the model reduces to the legacy one in the light-loading limit,
and that energy balance closes in full-system simulation. The legacy model
is retained behind an explicit switch, so every CSV you already hold remains
bit-for-bit reproducible against its archived script.
<!-- test/test_expansion_induction.jl, 793 assertions; commits 068de03,
     234a722; 10 legacy scripts pinned induction=false -->

## What this does to the numbers

**The high-RPM operating branch does not survive physical aerodynamics.**
The 300–480 rpm equilibria — including the 117.4 kW @ 11 m/s point — were
sustained by the fixed-C_L model's unbounded high-tip-speed torque. Under
the corrected model, blades at those tip speeds feather toward zero and then
negative lift, and the branch either decays or free-wheels at near-zero
power. At the previously quoted operating points (λ = 0.85, k ∈ {4, 8}),
the system now limit-cycles between partial spin-up and collapse:
windowed electrical output at 11 m/s is single-digit kW, with aerodynamic
extraction of order 20–30 kW against the ~97 kW swept-union Betz ceiling.
<!-- wind_sweep_triangle3_90s_induction.csv: 0.85/k4/11 → P_90=4.8 kW
     (window 2.2–9.6), P_aero_90=25.7 kW; 0.85/k8/11 → P_90≈0;
     ceiling: wake_overlap_audit.jl, union 201 m² -->

**Why I'm not sending a corrected power curve yet.** The generator constants
(k), the start transient, and indeed the design itself were all optimized
against the old aerodynamics. Quoting the corrected model at those legacy
settings would understate the machine exactly the way the old model
overstated it — it answers "what does the old controller do under new
physics", not "what can the machine do". We are re-bracketing the control
map and re-running the design optimization under the corrected model; the
honest corrected power curve comes from that, and I'll share it when it
exists. What I can state now with confidence is the envelope: this
geometry's output at 11 m/s is bounded by its ~97 kW swept-area ceiling and
is realistically in the tens of kW — the machine belongs to its 50 kW
design class, not the 100–450 kW range the earlier files implied.

**Revision to the bistability finding.** The basin-of-attraction structure
survives, but its interesting half does not: the "productive high-RPM
branch" reachable only by kickstart was largely an artifact of the missing
feathering physics. What remains is genuinely bistable spin-up/collapse
limit-cycling at low power — which is why we now treat windowed statistics
(min/mean/max with drift checks) as the only admissible way to report this
system, and I'd stand by that as a methodology recommendation for any
TRPT-class simulation.

## Where your expertise would genuinely help

The corrected model's constants are theory-defaults, not measurements: the
2π lift slope, the ±1.2 C_L limits, the design annulus tip-speed ratio, and
separately our Cp(blade count, TSR) solidity scaling are all flagged in-code
as approximate pending proper BEM validation — we have no hardware anchor at
the 50 kW scale. This is exactly the kind of thing AeroDyn does well. If you
or colleagues had interest in cross-checking the per-annulus model (or
running blade-count/solidity sweeps we could calibrate against), we would
gladly share the model specification, the property-test suite, and all
simulation data — and credit the collaboration in anything that comes of it.

Either way, you now hold the complete honest state of our simulations:
geometry verified, protocols documented, reproducibility pinned, and
absolute powers finally conserving energy.

Best regards,
Rod

<!-- Numbers index (strip):
  P_gen@90s / windows / P_aero: wind_sweep_triangle3_90s_induction.csv rows
    0.85/{4,8}/{9,11,13,15}, read against header line
    (blade_scale,k_mppt,wind_ms,P_30,P_60,P_90,P_aero_30..90,omega_30..90,
     fos_90,fos_min_window,T_max,P_min_w,P_max_w,drift,verdict,git,status).
  All rows verdict=DRIFTING — hence windowed language, no point values.
  Betz ceilings: union 201 m² → ~97 kW @ 11 m/s (triangle),
    scripts/wake_overlap_audit.jl.
  Model: src/expansion_rotor.jl (EXPANSION_INDUCTION, expansion_cl,
    solve_expansion_induction); proposal docs/plans/induction_fix_proposal.md.
  Cp solidity exponents "approximate, AeroDyn sweeps required": src/bem.jl:58.
-->
