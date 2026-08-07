# ══════════════════════════════════════════════════════════════════════════════
# Stage 2: Feasibility-first objective — three-tier minimisation
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_feasibility(P_mean, FoS_min; P_cap=50.0, P_floor=1.0, FoS_design=1.5, P_range=0.0)

Three-tier feasibility objective for DE minimisation:

- **Stalled tier** (P_mean < P_floor): f = 10 + (P_floor − P_mean)/P_floor
  → worst fitness, unloaded structures that fake high FoS
- **Feasibility tier** (FoS_min < FoS_design): f = FoS_design − FoS_min
  → structural gate — lower FoS = worse fitness in (0, 1.5)
- **Feasible tier** (FoS ≥ FoS_design, P ≥ P_floor):
  f = −min(P_mean, P_cap)/P_cap
  → power quality within feasible region, ∈ [−1, 0)

Tier ordering invariant: stalled > feasibility > feasible.
Within each tier: f decreases (improves) monotonically with better P or FoS.

F5 stationarity penalty (2026-08-07): when `P_range` is given, a design whose
window power swings wider than `swing_gate`× its mean pays an additive penalty
in the feasible tier.  The DE ranks on THIS function, so the penalty is what
actually shapes the search toward steady designs (the raw v11_fitness penalty
only affects the k-bracket's internal k choice).
"""
function objective_feasibility(P_mean, FoS_min;
        P_cap=50.0, P_floor=25.0, FoS_design=1.5,
        P_range=0.0, swing_gate=0.20, swing_lambda=10.0)
    # Guard: null structural measurement → rejection tier, above all stalls.
    # Returns strictly > any genuine stall so rejections can never be elite.
    (!isfinite(FoS_min) || FoS_min <= 0.0) && return 12.0
    if P_mean < P_floor
        return 10.0 + (P_floor - P_mean) / P_floor  # stalled tier ∈ [10, 11]
    elseif FoS_min < FoS_design
        return FoS_design - FoS_min  # feasibility tier ∈ (0, 1.5)
    else
        # Feasible tier ∈ [-1, 0).  Swing penalty: excess swing ratio beyond
        # the gate, scaled to the same units as the tier's power term.
        f = -min(P_mean, P_cap) / P_cap
        swing = P_mean > 0.1 ? P_range / P_mean : 0.0
        excess = max(0.0, swing - swing_gate)
        return f + swing_lambda * excess / P_cap
    end
end
