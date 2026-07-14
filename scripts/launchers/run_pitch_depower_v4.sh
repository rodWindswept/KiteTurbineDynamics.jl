#!/bin/bash
# run_pitch_depower_v4.sh
# 
# Chained automation harness to run the Pitch Depower V4 dynamic campaign
# and automatically execute the Python visual analysis and PDF compilation.
#
# Usage:
#   ./run_pitch_depower_v4.sh          # Full 128-run dynamic sweep
#   ./run_pitch_depower_v4.sh --test   # 2-run quick smoke test
#

export JULIA_NUM_THREADS=auto

SMOKE_TEST=0
if [ "$1" == "--test" ]; then
    SMOKE_TEST=1
fi

if [ $SMOKE_TEST -eq 1 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Pitch Depower V4 Quick Smoke Test..."
    echo "  - Mode: 2-run coarse test"
    echo "  - Threads: $(julia -e 'using Base.Threads; println(nthreads())')"
    echo "  - Julia Log : campaign_v4_smoke.log"
    echo "  - Python Log: analysis_v4_smoke.log"
    
    # Run Julia smoke campaign
    julia --project=. --threads=auto scripts/pitch_depower_campaign_v4.jl --test > campaign_v4_smoke.log 2>&1
    STATUS=$?
    
    if [ $STATUS -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Smoke campaign completed successfully."
        echo "Running Python post-processor and PDF compiler..."
        
        # Modify path dynamically inside python run for test metrics if needed, or simply run the analysis script
        # since campaign_metrics.csv will contain the smoke test metrics
        uv run --with numpy --with pandas --with matplotlib python3 scripts/pitch_depower_analysis_v4.py > analysis_v4_smoke.log 2>&1
        PY_STATUS=$?
        
        if [ $PY_STATUS -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Smoke test complete! All pipelines are green!"
            echo "Smoke PDF Report: scripts/results/pitch_depower_campaign_v4/analysis/analysis_report.pdf"
            exit 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Python smoke analysis failed (exit code $PY_STATUS)."
            echo "Check analysis_v4_smoke.log for details."
            exit 1
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Julia smoke campaign failed (exit code $STATUS)."
        echo "Check campaign_v4_smoke.log for details."
        exit 1
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Full Pitch Depower V4 Campaign..."
    echo "  - Mode: 128-run high-resolution dynamic sweep"
    echo "  - Time-step: 100 kHz (dt = 1e-5s)"
    echo "  - Threads: $(julia -e 'using Base.Threads; println(nthreads())')"
    echo "  - Julia Log : campaign_v4.log"
    echo "  - Python Log: analysis_v4.log"
    
    # Run full Julia campaign
    julia --project=. --threads=auto scripts/pitch_depower_campaign_v4.jl > campaign_v4.log 2>&1
    STATUS=$?
    
    if [ $STATUS -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Julia campaign completed successfully."
        echo "Starting Python visual post-processing and PDF compilation..."
        
        uv run --with numpy --with pandas --with matplotlib python3 scripts/pitch_depower_analysis_v4.py > analysis_v4.log 2>&1
        PY_STATUS=$?
        
        if [ $PY_STATUS -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pitch Depower V4 Campaign and PDF compilation complete! ✅"
            echo "Finished PDF Report: scripts/results/pitch_depower_campaign_v4/analysis/analysis_report.pdf"
            exit 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Python analysis failed (exit code $PY_STATUS)."
            echo "Check analysis_v4.log for details."
            exit 1
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Julia campaign failed (exit code $STATUS)."
        echo "Check campaign_v4.log for details."
        exit 1
    fi
fi
