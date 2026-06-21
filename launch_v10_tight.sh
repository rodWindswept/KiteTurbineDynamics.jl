#!/bin/bash
# launch_v10_tight.sh — Tight-bounded efficient campaign
# Bounds narrowed around known V10 basin, 12 islands x 1500 iter, ~12-18 min
set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_tight"
mkdir -p "$OUT_DIR"

echo "Launching V10 tight-bounded campaign..."
echo "  --tight: bounds narrowed around known basin"
echo "  n_lines [8,16] | r_bot [2,5] | Lr [2,3] | Do [0.06,0.15]"
echo "  r_hub [2.5,5] | lambda [0.1,1.5] | bank [0,35] free"
echo "  12 islands x 80 pop, 1500 iterations"
echo "  Output: $OUT_DIR/campaign.log"
echo "  Expected: ~12-18 minutes"
echo ""

julia --project=. scripts/run_v10_campaign.jl \
    --power 50 \
    --tight \
    --islands 12 \
    --iterations 1500 \
    2>&1 | tee "$OUT_DIR/campaign.log"
