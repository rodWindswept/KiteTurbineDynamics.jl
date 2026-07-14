#!/bin/bash
# launch_v10_50kw.sh — V10 campaign: unified rotor architecture, 14-DoF, 60 islands
# Run from your own terminal (screen/tmux recommended for long runs)
#
# Usage:
#   chmod +x launch_v10_50kw.sh
#   ./launch_v10_50kw.sh              # foreground (see progress)
#   screen -S v10 ; ./launch_v10_50kw.sh  # detachable session

set -e
cd "$HOME/Documents/GitHub/KiteTurbineDynamics.jl"

OUT_DIR="scripts/results/v10_campaign_50kw"
mkdir -p "$OUT_DIR"

echo "Launching V10 50kW campaign..."
echo "Output: $OUT_DIR/campaign.log"
echo "Expected duration: ~2 hours for 60 islands"
echo ""

# tee pattern — reliable on Julia 1.12.6 (nohup > produces 0-byte logs)
julia --project=. scripts/run_v10_campaign.jl --power 50 2>&1 | tee "$OUT_DIR/campaign.log"
