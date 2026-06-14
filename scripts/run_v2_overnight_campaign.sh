#!/bin/bash
# ── run_v2_overnight_campaign.sh ──
# Windswept & Interesting Ltd
# Pitch Depower V2 Parameter Sweep — Visual Audit & High-Fidelity PDF Assembly
# Automated overnight execution runner.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
V2_OUT_DIR="$SCRIPT_DIR/results/pitch_depower_campaign/v2_analysis_reporting_results"
BRAIN_DIR="/home/rod/.gemini/antigravity/brain/7cde38d4-52cf-4237-80e5-e487435d1a6b"

echo "========================================================================="
echo "  Starting Pitch Depower V2 Campaign Automated Overnight visual compiler"
echo "  Target Output: $V2_OUT_DIR"
echo "  Staging Brain: $BRAIN_DIR"
echo "========================================================================="

# 1. Initialize output directory
mkdir -p "$V2_OUT_DIR"
mkdir -p "$BRAIN_DIR"

# 2. Run the master python visual compiler
echo ""
echo "[Step 1/4] Running generate_v2_report.py Visual Compiler..."
python3 "$SCRIPT_DIR/generate_v2_report.py"

# 3. Verify and perform the validation audit
echo ""
echo "[Step 2/4] Running Post-Generation Structural Validation Audit..."
valid=true
file_count=0

# List of expected visual bases to check
figures=(
    "01_heatmaps_smoothness"
    "02_heatmaps_tension"
    "03_heatmap_brake_time"
    "04_parallel_coordinates"
    "05_ranked_configs"
    "06_3d_surface_duration_elev"
    "07_3d_surface_payout_dmode"
    "08_timeseries_best5"
    "09_timeseries_worst5"
    "10_composite_waterfall"
    "11_sensitivity_bar"
    "12_disqualifications"
    "13_control_efficacy"
    "science_phase_portrait"
    "science_survival_envelope"
    "science_control_surface_3d"
    "science_tulloch_fft"
    "science_design_space_3d"
    "science_safety_intersection"
    "science_event_cascade"
    "science_regime_bifurcation"
    "science_tension_hysteresis"
    "science_torque_speed_phase"
    "science_torsional_energy"
    "science_parallel_multivariate"
    "science_tension_violin"
    "science_torsional_slip_hysteresis"
    "science_torsional_twist_profile"
    "science_latching_window"
    "science_spider_chart"
    "science_manifold_gradient"
    "science_correlation_matrix"
    "science_torsional_spectrogram"
)

for fig in "${figures[@]}"; do
    png_file="$V2_OUT_DIR/$fig.png"
    svg_file="$V2_OUT_DIR/$fig.svg"
    
    # Check PNG exists and is > 0 bytes
    if [ ! -s "$png_file" ]; then
        echo "  [FAIL] $fig.png is missing or empty!"
        valid=false
    else
        file_count=$((file_count+1))
    fi
    
    # Check SVG exists and is > 0 bytes
    if [ ! -s "$svg_file" ]; then
        echo "  [FAIL] $fig.svg is missing or empty!"
        valid=false
    else
        file_count=$((file_count+1))
    fi
done

# Check PDF exists and is > 0 bytes
pdf_file="$V2_OUT_DIR/analysis_report_v2.pdf"
if [ ! -s "$pdf_file" ]; then
    echo "  [FAIL] analysis_report_v2.pdf is missing or empty!"
    valid=false
else
    file_count=$((file_count+1))
fi

if [ "$valid" = true ]; then
    echo "  [PASS] All structural integrity checks passed successfully!"
    echo "  Total visual files successfully validated: $file_count / $((2 * ${#figures[@]} + 1))"
else
    echo "  [FAIL] Structural validation audit reported errors. Please review logs."
    exit 1
fi

# 4. Copy completed assets to conversation brain folder for artifact visualization
echo ""
echo "[Step 3/4] Staging completed vector and raster assets to conversation brain..."
cp -R "$V2_OUT_DIR"/* "$BRAIN_DIR"/

# Verify that they are copied successfully
echo "  ✓ Successfully staged copy of all high-fidelity assets in conversation brain folder!"

# 5. Finished overnight compilation run
echo ""
echo "========================================================================="
echo "  ✓ Overnight Campaign Visual Compiler successfully completed!"
echo "  Unified Report: $pdf_file"
echo "  Vector Directory: $V2_OUT_DIR"
echo "========================================================================="
