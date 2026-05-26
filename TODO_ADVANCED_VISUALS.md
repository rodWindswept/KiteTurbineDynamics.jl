# TODO: Advanced Visual Evidence Base for TRPT Optimisation

This list tracks the development of high-impact visual and descriptive assets to be generated from the `KiteTurbineDynamics.jl` codebase. These assets aim to make the structural and aerodynamic findings of the v4/v5 campaigns visceral and accessible.

## 1. Torsional Collapse Animation (The "Failure Mode" Demo)
*   **Goal:** Visually demonstrate why the v2 Euler-only designs were physically invalid.
*   **Action:** Script a simulation that loads a v2 winner (e.g., 2.8 kg design) and applies rated 10 kW torque.
*   **Output:** `.mp4` or `.gif` showing the helical shaft twisting up and the ground rings collapsing (torsional buckling).
*   **Comparison:** Side-by-side with a v5 stable design showing the "twist-but-hold" behavior.
*   **Status:** Ready to script.

## 2. 3D Design Space "Feasibility Cloud" (Voxel Render)
*   **Goal:** Map the intersection of Euler and Torsional physics regimes.
*   **Action:** Run a high-density Latin Hypercube Sample (LHC) or Grid Sweep ($>10^5$ points) over $(r_{hub}, r_{bottom}, \text{target\_Lr})$.
*   **Visual:** Use GLMakie to render a 3D volume where:
    *   **Green Voxels:** Fully feasible designs.
    *   **Red Voxels:** Euler buckling failure only.
    *   **Blue Voxels:** Torsional collapse failure only.
    *   **Purple Voxels:** Both constraints violated.
*   **Insight:** Visually proves the "Optimal Corner" where both constraints become active simultaneously.

## 3. DE Population Evolution "Flow" Animation
*   **Goal:** Demonstrate the robustness of the Differential Evolution convergence.
*   **Action:** Extract the full population state for all 64 individuals at every 1,000 generations of a winning island.
*   **Visual:** Plot the population in 3D space $(Mass, r_{hub}, r_{bottom})$. Animate their migration from a scattered cloud to a tight cluster at the global optimum.
*   **Status:** Requires extraction of population history (currently only best is logged).

## 4. Aero-Structural Efficiency Topology
*   **Goal:** Solve the "n_lines = 8" paradox visually.
*   **Visual:** A 3D surface plot mapping $n_{lines}$ and $TSR$ on the horizontal plane, with **Specific Power (W/kg)** on the vertical axis.
*   **Insight:** Clearly shows the "structural cliff"—how structural mass spikes at low line counts, dragging down the system-level power-to-weight ratio even if aerodynamic efficiency is slightly higher.

## 5. Interactive WebGL/HTML Models
*   **Goal:** Allow researchers to inspect the winning geometries manually.
*   **Action:** Use `WGLMakie` to export the node-and-beam system of the 10 kW and 50 kW winners.
*   **Output:** Standalone `.html` files for inclusion in web reports or Substack.

## 6. System Interdependency Map (Unified Physics Ribbon)
*   **Goal:** Show the "Work" being done along the shaft.
*   **Visual:** A 3D render of the TRPT shaft where:
    *   **Beam Color:** Euler FOS (utilization).
    *   **Beam Glow/Pulse:** Torque transmission intensity.
    *   **Vector Arrows:** Dynamically show vertex forces ($F_v$) and tether tension ($T_{line}$) at rated wind.
*   **Status:** Implementation planned for Monograph section 2.
