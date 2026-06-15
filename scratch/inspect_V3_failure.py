# scratch/inspect_V3_failure.py
# Inspect the V3 campaign results to understand exactly when, where, and why the buckling occurs.

import pandas as pd
import numpy as np

def main():
    metrics_path = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/pitch_depower_campaign_v3/campaign_metrics.csv"
    print("========================================================================")
    print("Analyzing V3 Campaign Metrics")
    print("========================================================================")
    
    df_metrics = pd.read_csv(metrics_path)
    
    # 1. Total runs and disq rates
    total_runs = len(df_metrics)
    disq_runs = df_metrics[df_metrics["is_disqualified"] == 1]
    n_disq = len(disq_runs)
    print(f"Total Runs: {total_runs}")
    print(f"Disqualified Runs: {n_disq} ({n_disq/total_runs*100:.1f}%)")
    
    # Count reasons
    reasons = disq_runs["disqualification_reason"].value_counts()
    print("\nDisqualification Reasons:")
    for reason, count in reasons.items():
        print(f"  - {reason}: {count} ({count/total_runs*100:.1f}%)")
        
    # Check Buckling FoS range
    fos_min = df_metrics["fos_buckling_min"].min()
    fos_max = df_metrics["fos_buckling_min"].max()
    fos_mean = df_metrics["fos_buckling_min"].mean()
    print(f"\nBuckling FoS Range: {fos_min:.3f} to {fos_max:.3f} (Mean: {fos_mean:.3f})")
    
    # Find the "best" run in terms of buckling FoS
    best_run = df_metrics.sort_values(by="fos_buckling_min", ascending=False).iloc[0]
    best_run_id = int(best_run["run_id"])
    print(f"\nBest Run ID (highest buckling FoS): {best_run_id}")
    print(f"  - Wind Speed: {best_run['wind_speed']} m/s")
    print(f"  - Payout Duration: {best_run['payout_duration']} s")
    print(f"  - Active Winch: {best_run['active_winch']}")
    print(f"  - Damping Mode: {best_run['damping_mode']}")
    print(f"  - EA Backline: {best_run['EA_back_line']} N")
    print(f"  - c Backline: {best_run['c_back_line']} N*s/m")
    print(f"  - i PTO: {best_run['i_pto']} kg*m^2")
    print(f"  - Min Buckling FoS: {best_run['fos_buckling_min']:.3f}")
    print(f"  - Min Tension: {best_run['T_min']:.1f} N")
    print(f"  - Max Twist: {best_run['twist_max']:.3f} rad")
    
    # Let's inspect the timeseries of the best run and a typical failed run
    inspect_timeseries(best_run_id, "Best Run")
    
    # Let's find the worst run (lowest buckling FoS)
    worst_run = df_metrics.sort_values(by="fos_buckling_min", ascending=True).iloc[0]
    worst_run_id = int(worst_run["run_id"])
    print(f"\nWorst Run ID (lowest buckling FoS): {worst_run_id}")
    print(f"  - Min Buckling FoS: {worst_run['fos_buckling_min']:.3f}")
    inspect_timeseries(worst_run_id, "Worst Run")

def inspect_timeseries(run_id, label):
    ts_path = f"/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/pitch_depower_campaign_v3/timeseries_{run_id:04d}.csv"
    df_ts = pd.read_csv(ts_path)
    
    print(f"\n--- Timeseries Inspection for {label} (Run {run_id:04d}) ---")
    print(f"Total frames: {len(df_ts)}")
    
    # Find when tension goes to zero or when max tension changes
    # Let's print metrics at start, middle, and end
    t_arr = df_ts["t"].values
    omega_h = df_ts["omega_hub"].values
    omega_g = df_ts["omega_gnd"].values
    t_max = df_ts["T_max"].values
    payout = df_ts["backline_payout"].values
    
    # Find first index where payout starts (payout > 0.05)
    payout_starts = np.where(payout > 0.05)[0]
    t_payout_start = t_arr[payout_starts[0]] if len(payout_starts) > 0 else np.nan
    
    # Find min tension during payout
    payout_active = np.where(payout > 0.05)[0]
    if len(payout_active) > 0:
        min_t_payout = t_max[payout_active].min()
        min_t_idx = payout_active[t_max[payout_active].argmin()]
        t_min_t = t_arr[min_t_idx]
    else:
        min_t_payout = t_max.min()
        t_min_t = t_arr[t_max.argmin()]
        
    print(f"  - Payout starts at t = {t_payout_start:.2f} s")
    print(f"  - Minimum tension: {min_t_payout:.2f} N at t = {t_min_t:.2f} s")
    
    # Print state at key times
    print("\n  State timeline:")
    print("    t (s)  |  omega_hub  |  omega_gnd  |  T_max (N)  |  payout (m)")
    print("    -------------------------------------------------------------")
    for t_target in [0.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0]:
        idx = np.abs(t_arr - t_target).argmin()
        print(f"    {t_arr[idx]:5.1f}  |  {omega_h[idx]:9.3f}  |  {omega_g[idx]:9.3f}  |  {t_max[idx]:9.1f}  |  {payout[idx]:9.2f}")

if __name__ == "__main__":
    main()
