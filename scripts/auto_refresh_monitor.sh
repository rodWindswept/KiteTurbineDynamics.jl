#!/usr/bin/env bash
# scripts/auto_refresh_monitor.sh
# Background monitor that re-runs the cartography + report pipeline whenever
# a new elite_archive.csv appears or any archive is updated.
#
# Designed to be launched with nohup: it sleeps 15 minutes between checks and
# only re-runs the pipeline when something has changed since last refresh.
#
# Exits when a STOP file appears in the results dir or after MAX_HOURS.

set -u
cd "$(dirname "$0")/.."

RESULTS="scripts/results/trpt_opt_v2"
STAMP_FILE="$RESULTS/.last_refresh_stamp"
STOP_FILE="$RESULTS/.stop_monitor"
LOG_FILE="$RESULTS/auto_refresh.log"
SLEEP_SECS="${SLEEP_SECS:-900}"        # 15 min
MAX_HOURS="${MAX_HOURS:-170}"          # cap at ~week
SKIP_RENDERS="${SKIP_RENDERS:-1}"      # default skip heavy renders

mkdir -p "$RESULTS"
START=$(date +%s)
iter=0

echo "[$(date -Is)] auto_refresh_monitor starting (sleep=${SLEEP_SECS}s, max=${MAX_HOURS}h, skip_renders=${SKIP_RENDERS})" | tee -a "$LOG_FILE"

while true; do
  # Stop conditions
  if [ -f "$STOP_FILE" ]; then
    echo "[$(date -Is)] STOP file found, exiting" | tee -a "$LOG_FILE"
    break
  fi
  NOW=$(date +%s)
  ELAPSED=$(( (NOW - START) / 3600 ))
  if [ "$ELAPSED" -ge "$MAX_HOURS" ]; then
    echo "[$(date -Is)] reached MAX_HOURS=$MAX_HOURS, exiting" | tee -a "$LOG_FILE"
    break
  fi

  # Find newest mtime across archives
  NEWEST=$(find "$RESULTS" -maxdepth 2 -name elite_archive.csv -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
  LAST=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
  NEED_REFRESH=0
  if [ -n "$NEWEST" ] && awk -v n="$NEWEST" -v l="$LAST" 'BEGIN{exit !(n>l)}'; then
    NEED_REFRESH=1
  fi
  # Force a refresh every 4 hours regardless (so docx timestamp ticks)
  LAST_WALL=$(stat -c %Y "$STAMP_FILE" 2>/dev/null || echo 0)
  if [ $(( NOW - LAST_WALL )) -ge 14400 ]; then
    NEED_REFRESH=1
  fi

  if [ "$NEED_REFRESH" -eq 1 ]; then
    iter=$((iter+1))
    echo "[$(date -Is)] refresh iter=$iter (newest=$NEWEST, last=$LAST)" | tee -a "$LOG_FILE"
    if [ "$SKIP_RENDERS" = "1" ]; then
      ./scripts/refresh_all_outputs.sh --skip-renders >> "$LOG_FILE" 2>&1 || true
    else
      ./scripts/refresh_all_outputs.sh >> "$LOG_FILE" 2>&1 || true
    fi
    echo "$NEWEST" > "$STAMP_FILE"
    touch "$STAMP_FILE"
  else
    echo "[$(date -Is)] no changes; skipping refresh" | tee -a "$LOG_FILE"
  fi

  sleep "$SLEEP_SECS"
done

echo "[$(date -Is)] auto_refresh_monitor exiting (ran $iter refreshes)" | tee -a "$LOG_FILE"
