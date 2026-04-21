#!/usr/bin/env bash
# scripts/launch_autonomous_campaign.sh
# 168-hour unattended cartography campaign — Phase C of the master plan.
#
# Launches a grid of DE optimization islands spanning:
#   • 2 configurations   : 10 kW, 50 kW
#   • 3 beam profiles    : circular, elliptical, airfoil
#   • 5 axial profiles   : linear, elliptic, parabolic, trumpet, straight_taper
#   • 2 random seeds per (config, beam, axial) triple
#   = 60 islands total
#
# Each island runs for up to 10 hours and produces:
#   log.csv             — per-heartbeat progress
#   checkpoint.jls      — resumable state
#   elite_archive.csv   — top-200 unique feasible designs
#   best_design.json    — winner with full metadata
#
# We run a small number of islands in parallel (configurable, default 6)
# so total CPU load stays bounded. The campaign also kicks off the LHS
# cartography sweep and, when ready, the heatmap + Sobol analysis.
#
# Usage:
#   bash scripts/launch_autonomous_campaign.sh            # full campaign
#   PARALLEL=4 HOURS=8 bash scripts/launch_autonomous_campaign.sh
#   DRY_RUN=1 bash scripts/launch_autonomous_campaign.sh  # print commands only

set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$REPO_DIR"

OUT_ROOT="${OUT_ROOT:-scripts/results/trpt_opt_v2}"
PARALLEL="${PARALLEL:-6}"            # islands running at once
HOURS="${HOURS:-10}"                 # wall-clock cap per island
POP_SIZE="${POP_SIZE:-64}"
ARCHIVE_SIZE="${ARCHIVE_SIZE:-200}"
DRY_RUN="${DRY_RUN:-0}"

CONFIGS=(10kw 50kw)
BEAMS=(circular elliptical airfoil)
AXIALS=(linear elliptic parabolic trumpet straight_taper)
SEEDS=(1 2)

mkdir -p "$OUT_ROOT"
STATUS_FILE="$OUT_ROOT/campaign_status.md"
JOBLIST="$OUT_ROOT/joblist.txt"
PIDFILE="$OUT_ROOT/active_pids.txt"
: > "$JOBLIST"
: > "$PIDFILE"

# ── Generate job list ─────────────────────────────────────────────────────
JOBS=()
for cfg in "${CONFIGS[@]}"; do
  for beam in "${BEAMS[@]}"; do
    for ax in "${AXIALS[@]}"; do
      for seed in "${SEEDS[@]}"; do
        tag="${cfg}_${beam}_${ax}_s${seed}"
        outdir="$OUT_ROOT/$tag"
        JOBS+=("$cfg|$beam|$ax|$seed|$outdir|$tag")
        echo "$tag" >> "$JOBLIST"
      done
    done
  done
done
TOTAL=${#JOBS[@]}
echo "Campaign: $TOTAL islands, $PARALLEL in parallel, $HOURS h each"

# ── Status file ────────────────────────────────────────────────────────────
write_status_header() {
cat > "$STATUS_FILE" <<EOF
# TRPT Design Cartography — Autonomous Campaign Status

Started: $(date -Iseconds)
Repo: $REPO_DIR
Total islands: $TOTAL
Parallelism: $PARALLEL
Per-island budget: $HOURS h
Beam profiles: ${BEAMS[*]}
Axial profiles: ${AXIALS[*]}
Seeds: ${SEEDS[*]}

## Thesis for this phase

The previous B2 report sized TRPT beams on a 7-DoF linear-taper search.
Phase C expands to 12 DoF across five radial-vs-axial curve families, with
n_lines (hence n_polygon_sides and n_blades) and knuckle_mass_kg promoted
to decision variables, and with centripetal vertex loading subtracted from
the inward line force (blade mass lumped at the hub ring dominates).

We run 60 DE islands so each (config, beam, axial) triple has two independent
seeds. Each island maintains a 200-element elite archive of diverse feasible
designs rather than just the winner — this feeds the Phase-D cartography.

Phase C success criteria:
  • Every (config, beam, axial) triple produces a ≥200-member feasible archive
  • Best masses across axial profiles differ by > 3% so family choice matters
  • Winners should reveal either fewer-sections-bigger-radius or the opposite,
    quantitatively.

EOF
}
write_status_header

# ── Launcher helper ────────────────────────────────────────────────────────
launch_one() {
  local cfg=$1 beam=$2 ax=$3 seed=$4 outdir=$5 tag=$6
  mkdir -p "$outdir"
  local cmd=(
    julia --project=. scripts/run_trpt_optimization_v2.jl
    --config "$cfg"
    --beam-profile "$beam"
    --axial-profile "$ax"
    --seed "$seed"
    --pop-size "$POP_SIZE"
    --max-hours "$HOURS"
    --elite-archive-size "$ARCHIVE_SIZE"
    --output-dir "$outdir"
  )
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry] %s\n' "${cmd[*]}"
    return 0
  fi
  nohup "${cmd[@]}" > "$outdir/stdout.log" 2> "$outdir/stderr.log" &
  local pid=$!
  echo "$tag pid=$pid" >> "$PIDFILE"
  echo "launched $tag (pid $pid)"
}

# ── Scheduler ──────────────────────────────────────────────────────────────
count_running() {
  local cnt=0
  while read -r line; do
    [[ -z "$line" ]] && continue
    local p="${line##*pid=}"
    if kill -0 "$p" 2>/dev/null; then cnt=$((cnt+1)); fi
  done < "$PIDFILE"
  echo "$cnt"
}

for job in "${JOBS[@]}"; do
  IFS='|' read -r cfg beam ax seed outdir tag <<< "$job"
  while [[ "$DRY_RUN" != "1" && "$(count_running)" -ge "$PARALLEL" ]]; do
    sleep 30
  done
  launch_one "$cfg" "$beam" "$ax" "$seed" "$outdir" "$tag"
  sleep 2   # stagger start so filesystem writes don't collide
done

echo "All $TOTAL islands launched. See $PIDFILE for PIDs and $STATUS_FILE for status."

# ── Monitor ──────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != "1" ]]; then
  nohup bash "$REPO_DIR/scripts/monitor_campaign.sh" "$OUT_ROOT" \
      > "$OUT_ROOT/monitor.log" 2>&1 &
  echo "monitor pid=$!" >> "$PIDFILE"
fi
