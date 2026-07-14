#!/bin/bash
# launch_v10_conservative.sh — Overnight V10 50kW campaign with conservative k_mppt
# Uses k_mppt_safety=3.0 to account for static/dynamic mismatch (ratio ~3.3×)
# Full bounds (no --tight), 60 islands × 80 × 10,000 iterations
# Estimated runtime: 4-8 hours
set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_campaign_50kw_cons"
mkdir -p "$OUT_DIR"

echo "═══════════════════════════════════════════════════"
echo "  V10 Conservative Campaign — Overnight Run"
echo "  k_mppt_safety = 3.0 (dynamic/static ~3.3×)"
echo "  60 islands × 80 pop, up to 10,000 iterations"
echo "  Full bounds — no tight narrowing"
echo "  Output: $OUT_DIR/campaign.log"
echo "  Expected: 4-8 hours"
echo "═══════════════════════════════════════════════════"
echo ""

julia --project=. scripts/run_v10_campaign.jl \
    --power 50 \
    --conservative \
    --islands 60 \
    --iterations 10000 \
    2>&1 | tee "$OUT_DIR/campaign.log"

echo ""
echo "Campaign complete. Results in $OUT_DIR/"
