#!/usr/bin/env bash
# scripts/monitor_campaign.sh
# Periodically aggregate heartbeat logs from every island and publish a
# human-readable status markdown file. Intended to run in the background
# for the whole duration of the campaign.
#
# Usage: bash scripts/monitor_campaign.sh scripts/results/trpt_opt_v2

set -euo pipefail
ROOT="${1:-scripts/results/trpt_opt_v2}"
PERIOD="${PERIOD:-600}"   # seconds between refreshes
STATUS="$ROOT/campaign_status.md"
DISPATCH="$ROOT/dispatch_note.md"

while true; do
  {
    head -n 20 "$STATUS" 2>/dev/null
    echo
    echo "## Latest snapshot ($(date -Iseconds))"
    echo
    echo "| island | gen | evals | best_mass | FOS | archive | status |"
    echo "|---|---:|---:|---:|---:|---:|---|"
    for d in "$ROOT"/*/; do
      tag=$(basename "$d")
      [[ -z "$tag" || "$tag" == "." ]] && continue
      log="$d/log.csv"
      [[ -f "$log" ]] || continue
      last=$(tail -n 1 "$log")
      # CSV columns: ts,gen,evals,best_mass,best_fos,infeas,elapsed,archive,Do_top,...
      gen=$(echo "$last" | awk -F, '{print $2}')
      evals=$(echo "$last" | awk -F, '{print $3}')
      mass=$(echo "$last" | awk -F, '{printf "%.2f", $4}')
      fos=$(echo "$last" | awk -F, '{printf "%.2f", $5}')
      archive=$(echo "$last" | awk -F, '{print $8}')
      if pgrep -f "run_trpt_optimization_v2.jl.*$tag" >/dev/null 2>&1; then
        st="running"
      else
        st="done"
      fi
      printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
        "$tag" "$gen" "$evals" "$mass" "$fos" "$archive" "$st"
    done
    echo
    echo "## Elite archive summary (top 5 per island, all configs)"
    echo
    for d in "$ROOT"/*/; do
      tag=$(basename "$d")
      arc="$d/elite_archive.csv"
      [[ -f "$arc" ]] || continue
      echo "### $tag"
      head -n 6 "$arc"
      echo
    done
  } > "${STATUS}.tmp"
  mv "${STATUS}.tmp" "$STATUS"

  # Separate short dispatch-friendly note for Rod
  {
    echo "# Cowork dispatch note — $(date -Iseconds)"
    echo
    echo "168h cartography campaign status."
    echo
    live=$(pgrep -fc run_trpt_optimization_v2.jl || true)
    echo "- Islands active: **${live:-0}**"
    done_count=$(find "$ROOT" -name best_design.json 2>/dev/null | wc -l)
    echo "- Islands completed: **$done_count**"
    total_evals=0
    total_arch=0
    for f in "$ROOT"/*/log.csv; do
      [[ -f "$f" ]] || continue
      last=$(tail -n1 "$f")
      e=$(echo "$last" | awk -F, '{print $3}')
      a=$(echo "$last" | awk -F, '{print $8}')
      total_evals=$((total_evals + ${e:-0}))
      total_arch=$((total_arch + ${a:-0}))
    done
    echo "- Cumulative evaluations: **$total_evals**"
    echo "- Cumulative archive entries: **$total_arch**"
    echo
    echo "Best feasible across all islands (lowest mass):"
    best_file=""
    best_mass="999999"
    for j in "$ROOT"/*/best_design.json; do
      [[ -f "$j" ]] || continue
      m=$(grep best_mass_kg "$j" | head -n1 | sed 's/[^0-9.]//g')
      if awk -v a="$m" -v b="$best_mass" 'BEGIN{exit !(a < b)}' 2>/dev/null; then
        best_mass="$m"
        best_file="$j"
      fi
    done
    if [[ -n "$best_file" ]]; then
      echo
      echo '```json'
      cat "$best_file"
      echo '```'
    else
      echo "_no final best yet_"
    fi
  } > "${DISPATCH}.tmp"
  mv "${DISPATCH}.tmp" "$DISPATCH"

  sleep "$PERIOD"
done
