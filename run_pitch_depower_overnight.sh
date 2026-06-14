#!/bin/bash
# run_pitch_depower_overnight.sh
# 
# Chained script to run the Pitch Depower V2 overnight campaign
# and automatically execute the Python visual analysis and PDF compilation.

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Pitch Depower V2 Overnight Campaign..."
echo "Workers: 32 threads (auto)"
echo "Log file: campaign_v2.log"

# Run Julia campaign
julia --project=. --threads=auto scripts/pitch_depower_campaign.jl > campaign_v2.log 2>&1
STATUS=$?

if [ $STATUS -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Julia campaign completed successfully."
    echo "Starting Python visual analysis and PDF report compilation..."
    echo "Log file: analysis_v2.log"
    
    # Run Python analysis
    uv run --with numpy --with pandas --with matplotlib python3 scripts/pitch_depower_analysis.py > analysis_v2.log 2>&1
    PY_STATUS=$?
    
    if [ $PY_STATUS -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Python analysis and PDF compilation complete!"
        echo "PDF Report generated at: scripts/results/pitch_depower_campaign/analysis_report.pdf"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Python analysis failed (exit code $PY_STATUS)."
        echo "Check analysis_v2.log for details."
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Julia campaign failed (exit code $STATUS)."
    echo "Check campaign_v2.log for details."
fi
