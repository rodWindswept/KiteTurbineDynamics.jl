#!/bin/bash
echo "Starting full-length simulations in parallel..."
julia --project=. scripts/mppt_twist_sweep_v2.jl > sweep_mppt.log 2>&1 &
PID1=$!
julia --project=. scripts/hub_excursion_long.jl > sweep_hub.log 2>&1 &
PID2=$!
julia --project=. scripts/power_curve_sweep.jl > sweep_power.log 2>&1 &
PID3=$!

while kill -0 $PID1 2>/dev/null || kill -0 $PID2 2>/dev/null || kill -0 $PID3 2>/dev/null; do
  echo "[$(date '+%H:%M:%S')] Simulations are still running. Latest output:"
  tail -n 1 sweep_mppt.log sweep_hub.log sweep_power.log 2>/dev/null
  sleep 60
done

echo "Simulations complete. Running Python analysis..."
python3 scripts/make_diagrams.py
python3 scripts/plot_hub_excursion.py
python3 scripts/plot_mppt_sweep.py
python3 scripts/plot_mppt_individual.py
python3 scripts/produce_report.py
python3 scripts/produce_free_beta_report.py
python3 scripts/produce_kite_turbine_potential_report.py
echo "All tasks completed successfully."
