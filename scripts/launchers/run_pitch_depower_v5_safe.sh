#!/usr/bin/env bash
# run_pitch_depower_v5_safe.sh
#
# Windswept & Interesting Ltd
# Safety-Focused Pitch-Depower Sweep Automation Master Script
#
# Decouples execution phases and runs the entire V5-Safe Campaign
# (256-run high-fidelity octagon sweep + python report compilation)
# while you are AFK.
#

set -e

REPO_DIR="/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
RESULTS_DIR="${REPO_DIR}/scripts/results/pitch_depower_campaign_v5_safe"
LOG_FILE="${REPO_DIR}/campaign_v5_safe.log"

echo "=========================================================================="
echo "Windswept & Interesting Ltd — V5-Safe Dynamic Pitch Depower Campaign"
echo "=========================================================================="
echo "Start Time: $(date)"
echo "Repo Dir:   ${REPO_DIR}"
echo "Log File:   ${LOG_FILE}"
echo "=========================================================================="

cd "${REPO_DIR}"

# Step 1: Instantiate packages
echo -e "\n[PHASE 1] Instantiating Julia dependencies..."
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Step 2: Run test suite to verify physics alignment
echo -e "\n[PHASE 2] Running KiteTurbineDynamics.jl test suite..."
if julia --project=. test/runtests.jl; then
    echo "✔ Test suite passed successfully."
else
    echo "❌ Test suite failed. Please check simulation constraints."
    exit 1
fi

# Step 3: Run quick dynamic smoke test (4 runs, ~1 minute)
echo -e "\n[PHASE 3] Running quick V5-Safe dynamic smoke test..."
julia --project=. --threads=auto scripts/pitch_depower_campaign_v5_safe.jl --test
echo "✔ Smoke test completed. Summary metrics verified."

# Step 4: Launch full 256-run campaign in the background
echo -e "\n[PHASE 4] Launching full V5-Safe dynamic campaign (256 runs)..."
echo "Running parallel sweep (saving logs to ${LOG_FILE})..."

# Launch in background with nohup so it survives shell disconnect while you are AFK
nohup julia --project=. --threads=auto scripts/pitch_depower_campaign_v5_safe.jl > "${LOG_FILE}" 2>&1 &
CAMPAIGN_PID=$!

echo "=========================================================================="
echo "Campaign is now running in the BACKGROUND (PID: ${CAMPAIGN_PID})."
echo "You can safely go AFK. The campaign will run asynchronously."
echo "=========================================================================="
echo "To monitor progress in real-time, run:"
echo "  tail -f ${LOG_FILE}"
echo "=========================================================================="

# Wait for background process to finish before compiling the report
wait ${CAMPAIGN_PID}

echo -e "\n[PHASE 5] Campaign execution complete. Compiling diagnostics..."
if python3 scripts/pitch_depower_analysis_v5_safe.py; then
    echo "=========================================================================="
    echo "✔ PROFESSIONAL PDF REPORT GENERATED SUCCESSFULLY!"
    echo "Report Path: ${RESULTS_DIR}/analysis/analysis_report_v5_safe.pdf"
    echo "=========================================================================="
else
    echo "❌ Report compilation failed. Check python environment."
    exit 1
fi

echo "End Time: $(date)"
echo "Campaign V5-Safe automation sequence completed successfully."
echo "=========================================================================="
