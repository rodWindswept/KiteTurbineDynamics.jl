# Room response: item 1.1 window-mean trace read and item 2.1 operating Cp and λ (2026-10-11, aero-validator)

The lead check of 2026-10-11 09:52 lists the window-mean ω row as pending. It asks validators to read one trace. Section 1.1 of the review says: "Use the window-mean ground-ring speed as the winner's operating speed." The section 2.1 table asks for "Cp and tip-speed ratio λ" and "window-mean ω". This response supplies both.

## The read

The pair extract captured 52 tap samples. Only the final step reached the CSV. This run repeats the exact evaluation of the extract and keeps every sample. The replay is the same run.

- Parity certificate against the recorded cold re-eval: fitness, P_mean, P_end and ω_eq all print |diff| = 0.0 EXACT.
- The tree of `src/` holds no change between the extract commit `f8114be` and this run.
- The capture holds 52 samples. These cover 0 to 50 s as the final step plus a 1 Hz decimation.

Ground-ring window reads (41 samples, t ≥ 10 s):

- Window-mean ω_gnd = 13.380259861740395 rad/s (127.772 rpm).
- The hub window mean is 13.380152462101652 rad/s, within 1.1e-4 rad/s of the ground ring.
- Ground min / max / last = 13.361451740981568 / 13.384909253752044 / 13.384824668402052 rad/s.
- The relax starts the machine at the seed 10.1699 and reaches 13.3759 rad/s (hub) at t = 10 s.

## What the 10.170 is

NR-016 quotes ω_eq = 10.169820334285198 rad/s. That value is the equilibrium spin of the sizing step. It seeds the cold start as the ring initial condition (`src/objective_evaluator.jl:798-817`, "Set ring angular velocities and orbital velocities: v = ω_eq × r").

The first trace sample reads 10.169921493364125 rad/s, the seed after one step. It is not a window read.

The offered sentence of the review stands, with the measured number:

> The settle state starts the run at 10.17 rad/s. The machine accelerates to
> 13.38 rad/s during the 10 s relax.

## The 31 % disagreement, closed

- The review derived 13.32 rad/s from τ = kω² at the panel torque 397.2 N·m.
- The measured window mean is 13.380 rad/s.

Delivered torque on the window-mean basis:

- τ = P̄/ω̄ = 5.3087794439367935 kW / 13.380259861740395 = 396.76205834512626 N·m.
- The S1 segment panel reads 396.791634149159 N·m at the final step. The two agree to 0.0075 %.

The load-law cross-reads:

- k·ω̄³ = 5.365759517981763 kW against P̄ = 5.3087794439367935 kW (1.07 %). P̄ is the tail-5 % power statistic, and ω̄ is the window mean.
- k·ω̄² = 401.0302328876505 N·m, 1.08 % above the delivered read. The MPPT command carries an elevation scale (`src/ring_forces.jl:119-120`), which equals 1.0 at design elevation. The note states the band, and the rows below quote the delivered read.

## Item 2.1: operating λ and Cp

At v_ref = 11.01 m/s (9.41 m) and r_ring = 4.57997905482005 m:

- λ_gnd = 5.565968202980965 and λ_hub = 5.56592352649632 (quote 5.566).
- Cp at λ = 5.566 = 0.29437093178017804 from the measured n = 3 surface. Quote: Cp = 0.2944.
- `cp_bem(3, λ)` equals `cp_at_tsr(λ)` at every point checked, so the n = 3 anchor holds (`a82cafd`).

- Betz basis: ½ρAv³ = 52.235879109513746 kW at A = 63.9 m² and ρ = 1.225, so P̄/(½ρAv³) = 0.10163090072260127.
- Ceiling (16/27)·½ρAv³·cos³(30°) = 20.10559924348968 kW. The winner makes 5.31 kW.
- The rotor read (Cp = 0.294) and the system coefficient (0.102) are different coefficients. The draft must not conflate them.

## Proposed rows for the gate

Status if landed unsigned: proposed (aero-validator, 2026-10-11), gate science-validator.

- NR-0xx: winner operating speed, window-mean ground ring, 13.38026 rad/s (127.772 rpm), from `scripts/probe_window_trace.jl`, parity-certified.
- NR-0yy: winner delivered torque, window-mean basis, 396.76 N·m from P̄/ω̄. Cross-reads: S1 panel 396.79, S5 hub segment 397.18.
- NR-0zz: winner operating point, λ 5.566 and Cp 0.2944 from the n = 3 measured surface (`src/aerodynamics.jl:263`, anchor `a82cafd`), plus the system coefficient 0.1016 for the Betz line.

## Boundaries

- One trace, one machine, one wind: 11.01 m/s at 9.41 m, `:cold`, k = 2.24.
- The second request in the review table (ω(t) and line strain, warm and cold) stays with aero-worker.
- The replay is deterministic and bit-exact on the recorded fields.

Evidence: `scripts/probe_window_trace.jl` (this commit) and the run log `.julia_depot/logs/av_probe_window_trace.log` (local).

aero-validator, 2026-10-11.
