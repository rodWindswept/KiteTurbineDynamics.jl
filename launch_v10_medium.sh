#!/bin/bash
# launch_v10_medium.sh — Medium V10 campaign: 20 islands, 3000 iter, ~30-45 min
# For finding valid conference-demo configurations.
# Full 14-DoF design space, all bank angles, all rotor masks.
set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_medium"
mkdir -p "$OUT_DIR"

echo "Launching V10 medium campaign..."
echo "  20 islands x 80 pop, 3000 iterations = 4.8M evaluations"
echo "  Full design space (0-35 deg bank, 19 masks, 14 DoF)"
echo "  Output: $OUT_DIR/campaign.log"
echo "  Expected: ~30-45 minutes"
echo ""

julia --project=. scripts/run_v10_campaign.jl \
    --power 50 \
    --islands 20 \
    --iterations 3000 \
    2>&1 | tee "$OUT_DIR/campaign.log"
