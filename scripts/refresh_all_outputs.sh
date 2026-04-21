#!/usr/bin/env bash
# scripts/refresh_all_outputs.sh
# Phase D/E/F/G/H regeneration pipeline.
# Re-runs every cartography-layer script that consumes the elite-archive CSVs
# and produces fresh figures + docx. Safe to call repeatedly; each script is
# idempotent and overwrites its own outputs.
#
# Usage: ./scripts/refresh_all_outputs.sh [--skip-renders]

set -e
cd "$(dirname "$0")/.."

SKIP_RENDERS=0
for arg in "$@"; do
  case "$arg" in
    --skip-renders) SKIP_RENDERS=1 ;;
  esac
done

RESULTS="scripts/results/trpt_opt_v2"
CART="$RESULTS/cartography"
mkdir -p "$CART"

N_ARCHIVES=$(find "$RESULTS" -maxdepth 2 -name elite_archive.csv 2>/dev/null | wc -l)
N_LHS=$(find "$RESULTS/lhs" -maxdepth 1 -name '*.csv' 2>/dev/null | wc -l)
echo "[$(date -Is)] refresh: LHS csvs=$N_LHS, DE archives=$N_ARCHIVES"

# Phase D — heatmaps / Sobol / Pareto (LHS + archives)
echo "[$(date -Is)] Phase D: heatmaps"
python3 scripts/plot_cartography_heatmaps.py 2>&1 | tee "$CART/plot_cartography.log"

# Phase C — polygon family graphic (pure theory, no data dep)
echo "[$(date -Is)] Phase C: polygon family"
python3 scripts/plot_polygon_pair_graphic.py 2>&1 | tee "$CART/plot_polygon.log" || true

# Phase F — knuckle/nlines sensitivity
echo "[$(date -Is)] Phase F: sensitivity"
python3 scripts/plot_phase_f_sensitivity.py 2>&1 | tee "$CART/plot_phase_f.log"

# Phase E — envelope verification (only if archives exist)
if [ "$N_ARCHIVES" -gt 0 ]; then
  echo "[$(date -Is)] Phase E: envelope verification"
  julia --project=. scripts/verify_top_candidates_envelope.jl 2>&1 \
      | tee "$CART/phase_e.log"
else
  echo "[$(date -Is)] Phase E: skipped (no archives yet)"
fi

# Phase G — renders (can skip via --skip-renders for speed)
if [ "$N_ARCHIVES" -gt 0 ] && [ "$SKIP_RENDERS" -eq 0 ]; then
  echo "[$(date -Is)] Phase G: Makie renders"
  julia --project=. scripts/render_v2_screenshots.jl 2>&1 \
      | tee "$CART/phase_g_renders.log" || true
else
  echo "[$(date -Is)] Phase G: skipped"
fi

# Phase H — master report
echo "[$(date -Is)] Phase H: report.docx"
python3 scripts/produce_cartography_report.py 2>&1 | tee "$CART/phase_h.log"

echo "[$(date -Is)] refresh complete"
