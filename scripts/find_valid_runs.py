import pandas as pd
import numpy as np

# Load metrics
csv_path = 'scripts/results/pitch_depower_campaign_v4/campaign_metrics.csv'
df = pd.read_csv(csv_path)

print(f"Total runs: {len(df)}")
print("Disqualification reasons count:")
print(df['disqualification_reason'].value_counts(dropna=False))

# Check valid runs
valid_df = df[df['is_disqualified'] == 0]
print(f"\nValid (non-disqualified) runs: {len(valid_df)}")

if len(valid_df) > 0:
    print("\nTop 10 Valid Runs sorted by composite_score:")
    cols_to_print = ['run_id', 'wind_speed', 'payout_duration', 'active_winch', 'damping_mode', 
                     'EA_back_line', 'c_back_line', 'i_pto', 'fos_buckling_min', 'slack_events', 
                     'slack_events_late', 'speed_ripple_rms', 'max_out_of_plane_accel', 'composite_score']
    print(valid_df[cols_to_print].sort_values(by='composite_score', ascending=False).head(10).to_string(index=False))
else:
    print("\nNo valid runs! Let's print the top 10 runs by 'fos_buckling_min':")
    cols_to_print = ['run_id', 'wind_speed', 'payout_duration', 'active_winch', 'damping_mode', 
                     'EA_back_line', 'c_back_line', 'i_pto', 'fos_buckling_min', 'slack_events', 
                     'slack_events_late', 'is_disqualified', 'disqualification_reason']
    print(df[cols_to_print].sort_values(by='fos_buckling_min', ascending=False).head(15).to_string(index=False))

print("\nCorrelations with fos_buckling_min:")
print(df.corr(numeric_only=True)['fos_buckling_min'].sort_values(ascending=False).head(10))
