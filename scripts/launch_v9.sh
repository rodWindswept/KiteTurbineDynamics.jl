#!/bin/bash
# KTD v9 campaign launcher
# Uses setsid to create new session, trap to ignore SIGTERM
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
trap '' TERM HUP
setsid julia --project=. scripts/run_v6_campaign.jl --power 50 \
    > scripts/results/v9_0_full_50kw/campaign.log 2>&1 &
JULIA_PID=$!
echo "Julia PID: $JULIA_PID"
wait $JULIA_PID
