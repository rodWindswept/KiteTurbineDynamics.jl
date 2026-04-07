"""
Generate four mechanism/concept diagrams for the TRPT Lift Device Analysis document.
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patches as patches
from matplotlib.patches import FancyArrowPatch, Arc, FancyBboxPatch
from matplotlib.path import Path
import matplotlib.patheffects as pe

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/lift_kite/"

BLUE  = "#1F497D"
TEAL  = "#17A589"
ORANGE= "#E67E22"
RED   = "#C0392B"
GREEN = "#27AE60"
GREY  = "#7F8C8D"
LBLUE = "#AED6F1"
LGRN  = "#A9DFBF"

# ─────────────────────────────────────────────────────────────────────────────
# 1.  TRPT SYSTEM GEOMETRY DIAGRAM
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(9, 7))
ax.set_aspect('equal')
ax.set_xlim(-1.5, 8)
ax.set_ylim(-0.5, 8)
ax.axis('off')
ax.set_facecolor('#F8F9FA')
fig.patch.set_facecolor('#F8F9FA')

ax.set_title("TRPT System — Side View Geometry", fontsize=14, fontweight='bold', color=BLUE, pad=12)

# Ground
ax.axhline(0, color='#BDC3C7', lw=1.5, zorder=0)
ax.fill_between([-1.5, 8], [-0.5, -0.5], [0, 0], color='#D5D8DC', zorder=0)
ax.text(3, -0.3, 'Ground', ha='center', fontsize=9, color=GREY)

# Ground station box
gbox = FancyBboxPatch((0.1, 0), 0.8, 0.6, boxstyle="round,pad=0.05",
                       facecolor=BLUE, edgecolor='white', lw=1.5, zorder=3)
ax.add_patch(gbox)
ax.text(0.5, 0.3, 'GND\nSTN', ha='center', va='center', fontsize=7,
        color='white', fontweight='bold', zorder=4)

# TRPT shaft
beta = 30.0
beta_r = np.radians(beta)
L_shaft = 30.0
scale = 7.5 / L_shaft

gnd_x, gnd_y = 0.5, 0.3
hub_x = gnd_x + L_shaft*scale*np.cos(beta_r)
hub_y = gnd_y + L_shaft*scale*np.sin(beta_r)

# Shaft tether lines
for dy in [-0.04, 0.04]:
    ax.plot([gnd_x, hub_x], [gnd_y + dy, hub_y + dy], color=TEAL, lw=1.2, alpha=0.5, zorder=2)

# Ring nodes
n_rings = 16
for i in range(n_rings + 1):
    t = i / n_rings
    rx = gnd_x + t * (hub_x - gnd_x)
    ry = gnd_y + t * (hub_y - gnd_y)
    ring = plt.Circle((rx, ry), 0.07, color=TEAL, zorder=3, alpha=0.8)
    ax.add_patch(ring)

ax.text(gnd_x + (hub_x-gnd_x)*0.45 - 0.4, gnd_y + (hub_y-gnd_y)*0.45,
        'TRPT shaft\n(16 rings)', fontsize=8, color=TEAL, ha='center',
        rotation=beta, rotation_mode='anchor')

# Hub node
hub_circ = plt.Circle((hub_x, hub_y), 0.18, color=ORANGE, zorder=5)
ax.add_patch(hub_circ)
ax.text(hub_x + 0.25, hub_y, 'Hub\n(ring 16)', fontsize=8, color=ORANGE,
        fontweight='bold', va='center')

# Rotor
rotor_x = hub_x + 0.5
rotor_y = hub_y + 0.3
ax.plot([hub_x, rotor_x], [hub_y, rotor_y], color=RED, lw=2, zorder=4)
R_rotor = 0.6
for angle in [90, 210, 330]:
    a_r = np.radians(angle)
    ax.plot([rotor_x, rotor_x + R_rotor*np.cos(a_r)],
            [rotor_y, rotor_y + R_rotor*np.sin(a_r)],
            color=RED, lw=3, solid_capstyle='round', zorder=4)
rotor_circ = plt.Circle((rotor_x, rotor_y), 0.12, color=RED, zorder=5)
ax.add_patch(rotor_circ)
ax.text(rotor_x + 0.75, rotor_y, 'Rotor\n(R=5m)', fontsize=8, color=RED, va='center')
ax.annotate('', xy=(rotor_x + 0.3, rotor_y + 0.3),
            xytext=(rotor_x + 0.5, rotor_y + 0.1),
            arrowprops=dict(arrowstyle='->', color=RED, lw=1.5))
ax.text(rotor_x + 0.52, rotor_y + 0.35, 'ω', fontsize=11, color=RED, style='italic')

# Lift line
lift_len = 2.5
lift_angle = 80.0
lift_ar = np.radians(lift_angle)
kite_x = hub_x + lift_len * np.cos(lift_ar)
kite_y = hub_y + lift_len * np.sin(lift_ar)
ax.plot([hub_x, kite_x], [hub_y, kite_y], color=GREEN, lw=2, ls='--', zorder=4)
kite = patches.FancyArrow(kite_x - 0.05, kite_y, 0, 0.01, width=0.4, head_width=0.4,
                           head_length=0.3, color=GREEN, alpha=0.85, zorder=5)
ax.add_patch(kite)
ax.text(kite_x + 0.55, kite_y + 0.1, 'Lift\ndevice', fontsize=8, color=GREEN,
        fontweight='bold', va='center')

# Elevation angle arc
arc = Arc((gnd_x, gnd_y), 1.4, 1.4, angle=0, theta1=0, theta2=beta,
          color=BLUE, lw=1.5, zorder=4)
ax.add_patch(arc)
ax.text(gnd_x + 0.95, gnd_y + 0.2, f'β={beta:.0f}°', fontsize=9, color=BLUE, fontweight='bold')

# Hub altitude
ax.annotate('', xy=(hub_x, hub_y), xytext=(hub_x, 0),
            arrowprops=dict(arrowstyle='<->', color=GREY, lw=1.5))
ax.text(hub_x + 0.15, hub_y / 2, 'Hub alt.\n15 m', fontsize=8, color=GREY, va='center')

# Horizontal distance
ax.annotate('', xy=(hub_x, -0.25), xytext=(gnd_x, -0.25),
            arrowprops=dict(arrowstyle='<->', color=GREY, lw=1.2))
ax.text((gnd_x + hub_x)/2, -0.42, '26 m', fontsize=8, color=GREY, ha='center')

# Shaft length
ax.annotate('', xy=(hub_x, hub_y), xytext=(gnd_x, gnd_y),
            arrowprops=dict(arrowstyle='<->', color=BLUE, lw=1.2,
                            connectionstyle='arc3,rad=-0.2'))
mid_x = (gnd_x + hub_x)/2
mid_y = (gnd_y + hub_y)/2
ax.text(mid_x - 0.7, mid_y + 0.1, 'L=30 m\nshaft', fontsize=8, color=BLUE,
        ha='center', fontweight='bold')

# Wind arrow
ax.annotate('', xy=(7.2, 4.5), xytext=(5.8, 4.5),
            arrowprops=dict(arrowstyle='->', color=ORANGE, lw=2.5))
ax.text(6.0, 4.8, 'v_wind', fontsize=9, color=ORANGE, fontweight='bold')
ax.text(6.0, 4.3, '(v_mean = 11 m/s\nI = 0.15 Class A)', fontsize=7.5, color=ORANGE)

ax.annotate('T_lift\n(from lift device)', xy=(hub_x, hub_y),
            xytext=(hub_x - 1.5, hub_y + 1.0),
            fontsize=7.5, color=GREEN, fontweight='bold',
            arrowprops=dict(arrowstyle='->', color=GREEN, lw=1.2))
ax.annotate('T_shaft\n(rotor thrust +\ngravity reaction)', xy=(hub_x, hub_y),
            xytext=(hub_x + 0.5, hub_y - 1.2),
            fontsize=7.5, color=TEAL, fontweight='bold',
            arrowprops=dict(arrowstyle='->', color=TEAL, lw=1.2))

plt.tight_layout()
plt.savefig(OUT + 'diag_trpt_system.png', dpi=150, bbox_inches='tight')
plt.close()
print("Saved diag_trpt_system.png")


# ─────────────────────────────────────────────────────────────────────────────
# 2.  THREE LIFT DEVICE ARCHITECTURES
# ─────────────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(13, 7))
fig.patch.set_facecolor('#F8F9FA')
fig.suptitle("Lift Device Architectures — Comparison", fontsize=14,
             fontweight='bold', color=BLUE, y=0.97)

titles   = ["Single Kite", "Stacked Kites ×3", "Rotary Lifter"]
subtitles= ["21.4 m²  |  CV_T = 30%", "3×7.1 m²  |  CV_T = 30%", "R=1.5 m rotor  |  CV_T = 3.6%"]
colors   = [GREEN, TEAL, ORANGE]

for col, ax in enumerate(axes):
    ax.set_facecolor('#F8F9FA')
    ax.set_xlim(-2.5, 2.5)
    ax.set_ylim(-0.5, 8.0)
    ax.axis('off')

    hub_y = 0.4
    ax.plot(0, hub_y, 'o', color=ORANGE, ms=12, zorder=5)
    ax.text(0, 0.0, 'Hub node', ha='center', fontsize=8, color=ORANGE, fontweight='bold')
    ax.set_title(titles[col], fontsize=12, fontweight='bold', color=colors[col], pad=8)
    ax.text(0, -0.35, subtitles[col], ha='center', fontsize=8.5, color=colors[col],
            fontweight='bold')

    if col == 0:
        line_top = 6.5
        ax.plot([0, 0], [hub_y, line_top], color=GREEN, lw=2, zorder=3)
        kx = np.array([-1.0, 0, 1.0, 0, -1.0])
        ky = np.array([6.5, 7.2, 6.5, 5.8, 6.5])
        ax.fill(kx, ky, color=GREEN, alpha=0.6, zorder=4)
        ax.plot(kx, ky, color=GREEN, lw=1.5, zorder=5)
        ax.text(0, 6.5, '21.4 m²', ha='center', fontsize=9, color='white',
                fontweight='bold', zorder=6)
        ax.text(1.15, 6.5, 'para-foil', fontsize=8, color=GREEN, va='center')
        ax.annotate('', xy=(0, hub_y + 0.1), xytext=(0, 2.5),
                    arrowprops=dict(arrowstyle='->', color=RED, lw=2.5))
        ax.text(0.25, 1.8, 'T ∝ v²\nCV_T = 2I\n= 30%', fontsize=8.5, color=RED,
                fontweight='bold')
        ax.annotate('gust v+σ', xy=(0.8, 5.5), xytext=(1.5, 5.2),
                    fontsize=8, color=ORANGE,
                    arrowprops=dict(arrowstyle='->', color=ORANGE, lw=1.2))
        ax.text(0.2, 4.5, '→ T rises\nas (v+σ)²', fontsize=7.5, color=RED, style='italic')

    elif col == 1:
        kite_positions = [6.2, 4.4, 2.6]
        for i, ky_pos in enumerate(kite_positions):
            line_start = hub_y if i == len(kite_positions)-1 else kite_positions[i+1] + 0.2
            ax.plot([0, 0], [line_start, ky_pos - 0.2], color=TEAL, lw=2)
            scale_k = 0.7
            kx = np.array([-scale_k, 0, scale_k, 0, -scale_k])
            ky2 = np.array([ky_pos, ky_pos+0.55, ky_pos, ky_pos-0.55, ky_pos])
            ax.fill(kx, ky2, color=TEAL, alpha=0.6, zorder=4)
            ax.plot(kx, ky2, color=TEAL, lw=1.5, zorder=5)
            ax.text(0, ky_pos, f'7.1 m²', ha='center', fontsize=8, color='white',
                    fontweight='bold', zorder=6)
            ax.text(1.0, ky_pos, f'kite {3-i}', fontsize=7.5, color=TEAL, va='center')
        ax.annotate('', xy=(-1.5, kite_positions[-1]-0.5),
                    xytext=(-1.5, kite_positions[0]+0.5),
                    arrowprops=dict(arrowstyle='<->', color=TEAL, lw=1.5))
        ax.text(-2.2, (kite_positions[0]+kite_positions[-1])/2,
                'Total\n21.3 m²\n(same!)', ha='center', fontsize=8, color=TEAL,
                fontweight='bold', va='center')
        ax.annotate('', xy=(0, hub_y + 0.1), xytext=(0, 1.8),
                    arrowprops=dict(arrowstyle='->', color=RED, lw=2.5))
        ax.text(0.25, 1.3, 'T_total ∝ v²\nCV_T = 30%\n(unchanged)', fontsize=8,
                color=RED, fontweight='bold')

    else:
        rotor_y = 5.2
        ax.plot([0, 0], [hub_y, rotor_y - 0.25], color=ORANGE, lw=2, zorder=3)
        disc = plt.Circle((0, rotor_y), 1.35, color=ORANGE, alpha=0.12,
                          zorder=3, linewidth=2, edgecolor=ORANGE)
        ax.add_patch(disc)
        for angle_deg in [90, 210, 330]:
            a = np.radians(angle_deg)
            ax.plot([0, 1.35 * np.cos(a)],
                    [rotor_y, rotor_y + 1.35 * np.sin(a)],
                    color=ORANGE, lw=5, solid_capstyle='round', alpha=0.8, zorder=4)
        rotor_hub = plt.Circle((0, rotor_y), 0.18, color=ORANGE, zorder=5)
        ax.add_patch(rotor_hub)
        arc_r = Arc((0, rotor_y), 2.2, 2.2, angle=0, theta1=30, theta2=150,
                    color=RED, lw=2)
        ax.add_patch(arc_r)
        ax.annotate('', xy=(-1.07, rotor_y + 0.36),
                    xytext=(-0.9, rotor_y + 0.75),
                    arrowprops=dict(arrowstyle='->', color=RED, lw=2))
        ax.text(-1.9, rotor_y + 1.0, 'ω=33\nrad/s', fontsize=8.5, color=RED, fontweight='bold')
        # v_app vector diagram
        vx, vy = 0.8, rotor_y - 1.8
        ax.annotate('', xy=(vx + 0.7, vy), xytext=(vx, vy),
                    arrowprops=dict(arrowstyle='->', color=ORANGE, lw=2))
        ax.text(vx + 0.35, vy - 0.25, 'v_wind 11m/s', ha='center', fontsize=7, color=ORANGE)
        ax.annotate('', xy=(vx, vy + 0.9), xytext=(vx, vy),
                    arrowprops=dict(arrowstyle='->', color=TEAL, lw=2))
        ax.text(vx + 0.12, vy + 0.45, 'ωr≈30m/s', ha='left', fontsize=7, color=TEAL)
        ax.annotate('', xy=(vx + 0.7, vy + 0.9), xytext=(vx, vy),
                    arrowprops=dict(arrowstyle='->', color=RED, lw=2.5))
        ax.text(vx + 0.8, vy + 0.3, 'v_app\n31.7m/s', ha='left', fontsize=7.5,
                color=RED, fontweight='bold')
        ax.text(0, 1.5, 'v_app ≈ ωr >> v_wind\n→ gust is small fraction\n→ CV_T = 3.6%',
                ha='center', fontsize=8.5, color=RED, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='#FDEBD0', edgecolor=RED, alpha=0.8))

    for yi in [7.5, 7.2, 6.9]:
        ax.annotate('', xy=(2.2, yi), xytext=(1.5, yi),
                    arrowprops=dict(arrowstyle='->', color='#BDC3C7', lw=1.0))
    ax.text(1.8, 7.75, 'wind', fontsize=7, color=GREY, ha='center')

plt.tight_layout(rect=[0, 0.02, 1, 0.96])
plt.savefig(OUT + 'diag_lift_devices.png', dpi=150, bbox_inches='tight')
plt.close()
print("Saved diag_lift_devices.png")


# ─────────────────────────────────────────────────────────────────────────────
# 3.  TENSION CV — TIME SERIES CONCEPT DIAGRAM
# ─────────────────────────────────────────────────────────────────────────────
np.random.seed(42)
dt = 0.05
t_arr = np.arange(0, 60, dt)
n = len(t_arr)
T_L = 31.0
phi = np.exp(-dt / T_L)
I = 0.15
v_mean = 11.0

w = np.zeros(n)
for i in range(1, n):
    w[i] = phi * w[i-1] + np.sqrt(1 - phi**2) * np.random.randn()
sigma_v = I * v_mean
v = v_mean + sigma_v * w

T_mean_kite = 1603.0
T_kite = T_mean_kite * (v / v_mean)**2
CV_kite = np.std(T_kite) / np.mean(T_kite) * 100

omega_r = 33.0 * 0.9
v_app = np.sqrt(v**2 + omega_r**2)
v_app_mean = np.sqrt(v_mean**2 + omega_r**2)
T_rot_mean = 399.0
T_rot = T_rot_mean * (v_app / v_app_mean)**2
CV_rot = np.std(T_rot) / np.mean(T_rot) * 100

fig, axes = plt.subplots(3, 1, figsize=(12, 8), gridspec_kw={'height_ratios': [1.2, 1.5, 1.5]})
fig.patch.set_facecolor('#F8F9FA')
fig.suptitle("Tension Coefficient of Variation (CV_T) — Physical Mechanism",
             fontsize=13, fontweight='bold', color=BLUE)

ax0 = axes[0]
ax0.set_facecolor('#F8F9FA')
ax0.plot(t_arr, v, color=ORANGE, lw=1.0, alpha=0.9, label='v_wind(t)')
ax0.axhline(v_mean, color=ORANGE, lw=1.5, ls='--', alpha=0.6)
ax0.fill_between(t_arr, v_mean - sigma_v, v_mean + sigma_v,
                 color=ORANGE, alpha=0.12, label=f'±σ_v = ±{sigma_v:.1f} m/s  (I=0.15)')
ax0.set_ylabel('Wind speed (m/s)', fontsize=9)
ax0.set_xlim(0, 60)
ax0.legend(fontsize=8, loc='upper right')
ax0.set_title(f'IEC Class A turbulence  |  v_mean={v_mean} m/s, I=0.15, T_L≈31 s  '
              f'[same wind applied to all devices]', fontsize=9, color=GREY)
ax0.grid(True, alpha=0.3)
ax0.tick_params(labelbottom=False)

ax1 = axes[1]
ax1.set_facecolor('#F8F9FA')
ax1.plot(t_arr, T_kite, color=GREEN, lw=0.9, alpha=0.9,
         label=f'Single kite  T(t) ∝ v²   →   CV_T = {CV_kite:.1f}%')
ax1.axhline(np.mean(T_kite), color=GREEN, lw=2, ls='--', alpha=0.7)
ax1.fill_between(t_arr, np.mean(T_kite) - np.std(T_kite), np.mean(T_kite) + np.std(T_kite),
                 color=GREEN, alpha=0.15, label=f'±1σ band  (σ_T = ±{np.std(T_kite):.0f} N)')
ax1.set_ylabel('Lift tension (N)', fontsize=9)
ax1.set_xlim(0, 60)
ax1.text(1, np.mean(T_kite) + np.std(T_kite) * 1.25,
         f'CV_T = σ_T / T_mean = {CV_kite:.1f}%   ← T ∝ v²  so  CV_T = 2·I = 2×15% = 30%',
         fontsize=9, color=GREEN, fontweight='bold')
ax1.legend(fontsize=8, loc='upper right')
ax1.grid(True, alpha=0.3)
ax1.tick_params(labelbottom=False)

ax2 = axes[2]
ax2.set_facecolor('#F8F9FA')
ax2.plot(t_arr, T_rot, color=ORANGE, lw=0.9, alpha=0.9,
         label=f'Rotary lifter  T(t) ∝ v_app²  [v_app = √(v²+(ωr)²)]   →   CV_T = {CV_rot:.1f}%')
ax2.axhline(np.mean(T_rot), color=ORANGE, lw=2, ls='--', alpha=0.7)
ax2.fill_between(t_arr, np.mean(T_rot) - np.std(T_rot), np.mean(T_rot) + np.std(T_rot),
                 color=ORANGE, alpha=0.15, label=f'±1σ band  (σ_T = ±{np.std(T_rot):.1f} N)')
ax2.set_ylabel('Lift tension (N)', fontsize=9)
ax2.set_xlabel('Simulation time (s)', fontsize=9)
ax2.set_xlim(0, 60)
ratio = CV_kite / CV_rot
ax2.text(1, np.mean(T_rot) + np.std(T_rot) * 2.8,
         f'CV_T = {CV_rot:.1f}%   ← ωr ≈ 30 m/s >> v_wind ≈ 11 m/s  →  gust is small fraction of v_app',
         fontsize=9, color=ORANGE, fontweight='bold')
ax2.text(43, np.mean(T_rot) - np.std(T_rot)*3.5,
         f'{ratio:.0f}× less\nvariable', ha='center', fontsize=12,
         color=ORANGE, fontweight='bold',
         bbox=dict(boxstyle='round,pad=0.4', facecolor='#FDEBD0', edgecolor=ORANGE))
ax2.legend(fontsize=8, loc='upper right')
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(OUT + 'diag_cv_mechanism.png', dpi=150, bbox_inches='tight')
plt.close()
print("Saved diag_cv_mechanism.png")


# ─────────────────────────────────────────────────────────────────────────────
# 4.  HUB NODE FORCE BALANCE
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 7))
ax.set_aspect('equal')
ax.set_xlim(-4.5, 4.5)
ax.set_ylim(-4.5, 3.8)
ax.axis('off')
ax.set_facecolor('#F8F9FA')
fig.patch.set_facecolor('#F8F9FA')
ax.set_title("Hub Node — Free Body Diagram  (v = 11 m/s, β = 30°)", fontsize=13,
             fontweight='bold', color=BLUE, pad=10)

hub = plt.Circle((0, 0), 0.28, color=ORANGE, zorder=5)
ax.add_patch(hub)
ax.text(0, 0, 'HUB', ha='center', va='center', fontsize=9,
        color='white', fontweight='bold', zorder=6)

arrow_kw = dict(lw=3, mutation_scale=20)

# Lift force
theta_lift = np.radians(80)
lift_scale = 2.8
ax.annotate('', xy=(lift_scale*np.cos(theta_lift), lift_scale*np.sin(theta_lift)),
            xytext=(0, 0),
            arrowprops=dict(arrowstyle='->', color=GREEN, **arrow_kw), zorder=4)
ax.text(lift_scale*np.cos(theta_lift) + 0.2, lift_scale*np.sin(theta_lift),
        'T_lift = 1,603 N\n(lift line at θ=80°)\nLine tension from\nkite/lifter above',
        fontsize=8.5, color=GREEN, fontweight='bold', va='center')
arc_lift = Arc((0, 0), 1.3, 1.3, angle=0, theta1=0, theta2=80, color=GREEN, lw=1.5)
ax.add_patch(arc_lift)
ax.text(0.8, 0.35, 'θ=80°', fontsize=8, color=GREEN)

# Gravity
grav_scale = 0.65
ax.annotate('', xy=(0, -grav_scale), xytext=(0, 0),
            arrowprops=dict(arrowstyle='->', color=RED, **arrow_kw), zorder=4)
ax.text(0.2, -grav_scale*0.5, 'W = 173 N\n(17.6 kg airborne\nmass, gravity)', fontsize=8.5,
        color=RED, va='center')

# TRPT shaft force (reaction down-along-shaft)
beta_r = np.radians(30)
shaft_scale = 1.8
ax.annotate('', xy=(-shaft_scale*np.cos(beta_r), -shaft_scale*np.sin(beta_r)),
            xytext=(0, 0),
            arrowprops=dict(arrowstyle='->', color=TEAL, **arrow_kw), zorder=4)
ax.text(-shaft_scale*np.cos(beta_r) - 0.15, -shaft_scale*np.sin(beta_r) - 0.2,
        'T_shaft ≈ 726 N\n(rotor thrust back-\ntransmitted down shaft\nat β=30°)',
        fontsize=8.5, color=TEAL, fontweight='bold', ha='right', va='top')
arc_beta = Arc((0, 0), 0.9, 0.9, angle=0, theta1=180, theta2=210, color=TEAL, lw=1.5)
ax.add_patch(arc_beta)
ax.text(-0.8, -0.28, 'β=30°', fontsize=8, color=TEAL)

# Equilibrium equation box
eq_text = (
    "Vertical equilibrium:   T_lift·sin(θ) − W − T_shaft·sin(β)  =  0\n"
    "      1,603·sin(80°)   −  173   −  726·sin(30°)  ≈  0  ✓\n"
    "              1,579    −  173   −       363       ≈  1,043 N net upward\n\n"
    "Hub moves vertically when T_lift oscillates:\n"
    "      Δz_hub  ≈  ΔT_lift · sin(θ) / k_shaft\n"
    "      k_shaft ≈ 117 kN/m  →  hub_z std ≈ CV_T · T_mean · sin(θ) / k_shaft"
)
ax.text(0, -2.8, eq_text, ha='center', va='top', fontsize=8.5, color=BLUE,
        fontfamily='monospace',
        bbox=dict(boxstyle='round,pad=0.55', facecolor='#EBF5FB', edgecolor=BLUE, alpha=0.9))

# Axes
ax.annotate('', xy=(3.8, 0), xytext=(-0.4, 0),
            arrowprops=dict(arrowstyle='->', color='#BDC3C7', lw=1.2))
ax.text(3.9, 0, '+x', fontsize=8, color=GREY, va='center')
ax.annotate('', xy=(0, 3.4), xytext=(0, -0.4),
            arrowprops=dict(arrowstyle='->', color='#BDC3C7', lw=1.2))
ax.text(0.12, 3.5, '+z', fontsize=8, color=GREY)

plt.tight_layout()
plt.savefig(OUT + 'diag_hub_forces.png', dpi=150, bbox_inches='tight')
plt.close()
print("Saved diag_hub_forces.png")

print("\nAll diagrams complete.")
