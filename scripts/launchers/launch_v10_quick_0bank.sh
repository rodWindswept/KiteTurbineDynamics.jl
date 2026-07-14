#!/bin/bash
# launch_v10_quick_0bank.sh — Quick V10 campaign: 0° bank only, 15 islands, 5K iter
# For finding valid conference-demo configurations fast.
# Expected: ~15-20 minutes
set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_quick_0bank"
mkdir -p "$OUT_DIR"

echo "Launching V10 quick-scan (0° bank only)..."
echo "  15 islands × 5000 iterations, bank forced to 0°"
echo "  Output: $OUT_DIR/campaign.log"
echo ""

julia --project=. scripts/run_v10_campaign.jl \
    --power 50 \
    --islands 15 \
    --iterations 5000 \
    --bank-min 0.0 \
    --bank-max 0.0 \
    2>&1 | tee "$OUT_DIR/campaign.log"
