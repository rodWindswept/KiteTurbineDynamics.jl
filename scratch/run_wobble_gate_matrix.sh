#!/usr/bin/env bash
# scratch/run_wobble_gate_matrix.sh
# Launch the wobble-gate full-protocol matrix: {lin_damp} x {dt, dt/2} = 8 runs,
# all in parallel (desktop PC, 32 cores). Each run is one independent process.
#
# Usage:  scratch/run_wobble_gate_matrix.sh [relax_s] [window_s]
# Output: .julia_depot/logs/wg_ld<LD>_dtf<F>.log + .csv
set -u
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
cd "$(dirname "$0")/.."
RELAX=${1:-120}
WINDOW=${2:-120}
GH=$(git rev-parse --short HEAD)
mkdir -p .julia_depot/logs
echo "matrix start $(date)  git=$GH  relax=$RELAX window=$WINDOW"
for LD in 0.05 0.30 0.60 0.00; do
    for DTF in 1 2; do
        TAG="wg_ld${LD}_dtf${DTF}"
        LOCK="/tmp/${TAG}.lock"
        if [ -e ".julia_depot/logs/${TAG}.done" ]; then
            echo "skip $TAG (already done)"
            continue
        fi
        (
            s=$(date +%s)
            julia --project=. scratch/probe_wobble_gate_run.jl "$LD" "$DTF" "$RELAX" "$WINDOW" "$TAG" \
                > ".julia_depot/logs/${TAG}.log" 2>&1
            rc=$?
            e=$(date +%s)
            echo "EXIT=$rc ELAPSED=$((e-s))s HASH=$GH" >> ".julia_depot/logs/${TAG}.log"
            [ $rc -eq 0 ] && touch ".julia_depot/logs/${TAG}.done"
        ) &
        echo "launched $TAG"
        sleep 3
    done
done
wait
echo "matrix done $(date)"
