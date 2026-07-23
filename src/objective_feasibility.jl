# ══════════════════════════════════════════════════════════════════════════════
# Stage 2: Feasibility-first objective — three-tier minimisation
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_feasibility(P_mean, FoS_min; P_cap=50.0, P_floor=1.0, FoS_design=1.5)

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
"""
function objective_feasibility(P_mean, FoS_min; P_cap=50.0, P_floor=1.0, FoS_design=1.5)
    if P_mean < P_floor
        return 10.0 + (P_floor - P_mean) / P_floor  # stalled tier ∈ (10, 10+P_floor]
    elseif FoS_min < FoS_design
        return FoS_design - FoS_min  # feasibility tier ∈ (0, 1.5)
    else
        return -min(P_mean, P_cap) / P_cap  # feasible tier ∈ [-1, 0]
    end
end
