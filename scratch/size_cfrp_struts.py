import pandas as pd
import numpy as np

# Load telemetry
df = pd.read_csv("scripts/results/diagnostics/hypothesis_testing_telemetry.csv")
cases = df["case"].unique()

E_CFRP = 70e9 # Pa
T_OVER_D = 0.05
FOS_TARGET = 1.8

print("=== CFRP Polygon Strut Sizing Analysis ===")
print(f"Target Buckling FoS: {FOS_TARGET}")

for case in cases:
    sub = df[df["case"] == case]
    peak_T = sub["T_max"].max()
    
    # Calculate inward radial force at a vertex (assuming tether angle of ~3.5 degrees)
    theta_taper = np.deg2rad(3.5)
    F_in = 2 * peak_T * np.sin(theta_taper / 2)
    
    # Compressive load on a pentagon strut segment (5-line system)
    N_comp = F_in / (2 * np.sin(np.pi / 5))
    
    # Now we want N_comp * FOS_TARGET = P_crit
    P_crit_req = N_comp * FOS_TARGET
    
    # P_crit = pi^2 * E_CFRP * I / L^2
    # Let's assume a representative ring radius of R = 1.6m (hub)
    # For a pentagon (5 vertices), L_beam = 2 * R * sin(pi/5) = 2 * 1.6 * sin(36 deg) ≈ 1.88 m
    R = 1.6
    L_beam = 2 * R * np.sin(np.pi / 5)
    
    # Required second moment of area I
    I_req = P_crit_req * (L_beam**2) / (np.pi**2 * E_CFRP)
    
    # For hollow circular tube with t/Do = 0.05:
    Do_req = (I_req / (np.pi/64 * (1 - 0.9**4)))**(0.25)
    t_req = Do_req * T_OVER_D
    
    # Mass of the ring = 5 * L_beam * A * rho
    rho_CFRP = 1600.0 # kg/m^3
    A = np.pi/4 * (Do_req**2 - (Do_req - 2*t_req)**2)
    m_ring = 5 * L_beam * A * rho_CFRP
    
    print(f"\nCase: {case}")
    print(f"  Peak Tether Tension: {peak_T:.1f} N")
    print(f"  Strut Compression N_comp: {N_comp:.1f} N")
    print(f"  Required P_crit (FoS={FOS_TARGET}): {P_crit_req:.1f} N")
    print(f"  Required CFRP Strut OD: {Do_req*1000:.2f} mm")
    print(f"  Required CFRP Wall Thickness: {t_req*1000:.2f} mm")
    print(f"  Estimated Hub Ring Mass: {m_ring:.3f} kg")
