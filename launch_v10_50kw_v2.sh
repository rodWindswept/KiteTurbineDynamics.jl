#!/bin/bash
# launch_v10_50kw_v2.sh — V10 campaign re-run with corrected physics gates
#
# Changes from v1 (launch_v10_50kw.sh):
#   - Rotor-position clamp removed: DE can now select 2+ rotor designs
#     that distribute thrust along the TRPT (rings 7+4, 7+3, etc.)
#   - Tension-distribution gate: rejects designs where any tether
#     segment goes slack at the equilibrium operating point
#   - Hub-rotor filter: 60→19 masks, all include rotor at position 1
#   - Per-island structural gate (headless_verify_structural): catches
#     degenerate gravity-settle failures
#   - Post-campaign dynamic k_mppt scan on global best
#
# Run from your own terminal (screen/tmux recommended):
#   screen -S v10v2 ; ./launch_v10_50kw_v2.sh
#
# Expected: ~2 hours for 60 islands × 10K iterations

set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_campaign_50kw_v2"
mkdir -p "$OUT_DIR"

echo "Launching V10 v2 50kW campaign..."
echo "  Fixes: rotor-position clamp removed, tension-distribution gate, hub-rotor filter"
echo "  Masks: 19 (all include hub rotor)"
echo "  Output: $OUT_DIR/campaign.log"
echo "  Expected: ~2 hours for 60 islands"
echo ""

# tee pattern — reliable on Julia 1.12.6 (nohup > produces 0-byte logs)
julia --project=. scripts/run_v10_campaign.jl --power 50 2>&1 | tee "$OUT_DIR/campaign.log"
