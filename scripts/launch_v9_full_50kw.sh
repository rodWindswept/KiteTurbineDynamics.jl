#!/bin/bash
# KTD v9 full campaign launcher - 50kW
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
trap '' TERM HUP
exec setsid julia --project=. scripts/run_v6_campaign.jl --power 50 \
    > scripts/results/v9_0_full_50kw/campaign.log 2>&1
