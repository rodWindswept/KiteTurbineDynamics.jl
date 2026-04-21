#!/bin/bash
set -e

echo "Starting Simulation Phase B..."

# Run scripts in parallel
echo "Running hub_excursion_long.jl..."
julia --project=. scripts/hub_excursion_long.jl > scripts/results/hub_excursion_long_output.txt 2>&1 &
PID1=$!

echo "Running mppt_twist_sweep_v2.jl..."
julia --project=. scripts/mppt_twist_sweep_v2.jl > scripts/results/mppt_twist_sweep_v2_output.txt 2>&1 &
PID2=$!

echo "Running power_curve_sweep.jl..."
julia --project=. scripts/power_curve_sweep.jl > scripts/results/power_curve_sweep_output.txt 2>&1 &
PID3=$!

# Wait for all processes to finish, printing a heartbeat
while kill -0 $PID1 2>/dev/null || kill -0 $PID2 2>/dev/null || kill -0 $PID3 2>/dev/null; do
    echo "Simulations are running... (waiting)"
    # Peek at the logs to show progress
    echo "--- mppt_twist_sweep_v2 progress ---"
    tail -n 2 scripts/results/mppt_twist_sweep_v2_output.txt || true
    echo "------------------------------------"
    sleep 30
done

wait $PID1
wait $PID2
wait $PID3
echo "Julia simulations finished."

echo "Starting Phase C: Post-Processing & Visualization..."
python3 scripts/make_diagrams.py
python3 scripts/plot_hub_excursion.py
python3 scripts/plot_mppt_sweep.py
python3 scripts/plot_mppt_individual.py

echo "All tasks completed successfully."
