#!/bin/bash
# scripts/launch_trpt_optimization.sh
# Item B2 — Step 6: Launch the 168-hour TRPT sizing optimization as detached
# background processes, one per (config, beam-profile) pair.  Logs are written
# to scripts/results/trpt_opt/<config>_<profile>/.
#
# Usage:
#   bash scripts/launch_trpt_optimization.sh            # launches all 6
#   bash scripts/launch_trpt_optimization.sh --hours 12 # cap each run at 12h
#
# The script writes a PID file so you can monitor or kill the runs later:
#   scripts/results/trpt_opt/pids.txt   — list of "<label> <PID>"

set -euo pipefail

cd "$(dirname "$0")/.."   # repo root

MAX_HOURS=${MAX_HOURS:-168}
if [[ "${1:-}" == "--hours" && -n "${2:-}" ]]; then
    MAX_HOURS="$2"
    shift 2
fi

RESULTS_DIR="scripts/results/trpt_opt"
PID_FILE="$RESULTS_DIR/pids.txt"
mkdir -p "$RESULTS_DIR"
: > "$PID_FILE"

echo "=============================================================="
echo "Launching TRPT Optimization — Item B2, Step 6"
echo "Repo root  : $(pwd)"
echo "Max hours  : $MAX_HOURS per run"
echo "Results    : $RESULTS_DIR"
echo "=============================================================="

CONFIGS=(10kw 50kw)
PROFILES=(circular elliptical airfoil)

SEED_BASE=42
seed_idx=0

for cfg in "${CONFIGS[@]}"; do
  for prof in "${PROFILES[@]}"; do
    label="${cfg}_${prof}"
    outdir="$RESULTS_DIR/$label"
    mkdir -p "$outdir"
    logfile="$outdir/stdout.log"
    seed=$((SEED_BASE + seed_idx))
    seed_idx=$((seed_idx + 1))

    echo ">>> Starting $label (seed=$seed)"
    nohup julia --project=. scripts/run_trpt_optimization.jl \
          --config "$cfg" \
          --profile "$prof" \
          --output-dir "$outdir" \
          --seed "$seed" \
          --max-hours "$MAX_HOURS" \
          > "$logfile" 2>&1 &
    PID=$!
    echo "$label $PID" >> "$PID_FILE"
    echo "    PID=$PID  log=$logfile"
    disown $PID || true
    sleep 0.5
  done
done

echo "=============================================================="
echo "All 6 runs launched. PIDs written to: $PID_FILE"
echo "Tail any log with: tail -f $RESULTS_DIR/<label>/stdout.log"
echo "Kill all: kill \$(awk '{print \$2}' $PID_FILE)"
echo "=============================================================="
