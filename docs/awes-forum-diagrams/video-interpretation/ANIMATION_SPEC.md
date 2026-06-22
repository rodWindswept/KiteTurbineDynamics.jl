# Animation Specifications & Data Visualizations

This document outlines the technical requirements, rendering parameters, and asset sourcing for animating the TRPT optimization data and 3D kite turbine models.

---

## 1. 3D Model Rendering Specs (Blender/FreeCAD)

To show the physical meaning of the optimization parameters, we overlay structural and aerodynamic forces on the 3D turbine model.

### Key Renders Required:
* **The Polygon Ring Node (Knuckle Detail)**:
  * **Visual**: Close-up of a carbon-fiber sleeve connecting the ring beams to the tethers.
  * **Dynamic Action**: Scale the knuckle and beam diameter. Transition from V6.2 uncorrected knuckle (a tiny, fixed 5g dot) to V6.2/V6.3 coupled knuckle (a styled CFRP cuff scaling with beam diameter $D_o$ and wall thickness $t$).
  * **Overlay**: Text showing knuckle mass dynamically updating (e.g., `0.005 kg` in red → morphing to `0.101 kg` in cyan).
* **The 45° vs 35° Bank Angle (Airfoil Back-winding)**:
  * **Visual**: Close-up of an expansion rotor blade banked relative to the apparent wind vector.
  * **Dynamic Action**: Rotate the blade's bank angle from 35° to 45°.
  * **Overlay**: Render the apparent wind vector (blue arrow) and airfoil chord line. At 45°, highlight the airfoil stalling/back-winding with turbulent red flow lines. Show the collapse risk at 45° with inward-pointing force vectors, and steady outward radial force (cyan arrow) at 35°.
* **The "Many Small Fans" Layout (V6.2 vs V6.3)**:
  * **Visual**: Side-by-side comparison of the TRPT shaft.
    * **Left (V6.2)**: 1 massive hub rotor (10.6m span, 12 blades) at the hub ring.
    * **Right (V6.3)**: 6 tiny rotors (1.8m span, 8 blades each) distributed down the 8 rings.
  * **Overlay**: Glowing thrust vectors (arrows) along the shaft. Show how the V6.3 design distributes thrust smoothly, reducing local stress concentration.

---

## 2. 2D/3D Data Animations (Manim/Makie)

These animations will visualize the actual campaign outputs (converged points, trajectories, and non-dimensional boundaries).

### Animation Scene 1: The Slenderness Gate
* **Source Asset**: [SPEC-d3-mass-scaling.md](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/SPEC-d3-mass-scaling.md) and [v10-traced-paths.md](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-traced-paths.md).
* **Visual Representation**:
  * Plot of **Total Mass (kg)** vs **Beam Slenderness ($L_r/D$)**.
  * Draw a solid red vertical line at $L_r/D = 21$. Shade the region to the left ($L_r/D < 21$) in a translucent red.
  * **Action**: Data points of different designs fly onto the chart. Points entering the red zone are instantly vaporized or marked with an "Air Brake / Drag Infeasible" label. Points crossing to the right of the gate slide down a smooth curve towards the minimum mass region at $L_r/D \approx 39$.

### Animation Scene 2: The PCA Trajectory (V10 Campaign)
* **Source Data**: `convergence_history.csv` and parameter traces from V10/V6.2/V6.3.
* **Visual Representation**:
  * PCA space with axes PC1 (Structural Scale) and PC2 (Configuration).
  * Draw iso-mass contours as glowing white dotted concentric curves (80kg, 100kg, 150kg).
  * **Action**: Scatter 60 islands as white diamonds at random starting positions. As the timer (iteration count) increments, animate the paths tracing orange "spiderweb" lines.
  * **Path Splitting**:
    * Show 25/31 islands (Cyan) smoothly descending and channeling into a deep valley around $PC1 \approx 0, PC2 \approx -2.0$ (Basin A, 76.7 kg).
    * Show 6/31 islands (Crimson) getting trapped in the upper shelf valley around $PC1 \approx 0.5, PC2 \approx -0.5$ (Basin B, 80-81 kg).
  * **Callout**: Highlight the "Lambda Gradient ($\lambda_{bot}/\lambda_{top}$)" color scale on the background. Show how Basin B designs are stuck with high gradients (8-15), while Basin A designs succeed by reducing it to ~4.

---

## 3. Reference Manim Script Structure (Python)

Below is the template Python script for compiling the PCA path animation using **Manim**:

```python
from manim import *
import pandas as pd
import numpy as np

class PCATrajectory(Scene):
    def construct(self):
        # 1. Set up high-contrast dark theme
        self.camera.background_color = "#0B0C10"
        
        # 2. Add Title and Axes
        title = Text("V10 Campaign: PCA Convergence", font_size=24, color="#66FCF1").to_edge(UP)
        self.play(Write(title))
        
        ax = Axes(
            x_range=[-3, 3, 1],
            y_range=[-3, 1, 1],
            tips=False,
            axis_config={"color": "#1F2833", "include_numbers": True}
        )
        labels = ax.get_axis_labels(x_label="PC1: Structural Scale", y_label="PC2: Configuration")
        self.play(Create(ax), Write(labels))
        
        # 3. Create static contours (representing mass)
        # (Placeholder for real contour rendering - using circles for visual representation)
        contours = VGroup(*[
            Annulus(inner_radius=r, outer_radius=r+0.05, color=GREY, fill_opacity=0.2)
            for r in [1.5, 2.2, 3.0]
        ])
        self.play(FadeIn(contours))
        
        # 4. Load Campaign Data (Example)
        # df = pd.read_csv("convergence_history.csv")
        
        # 5. Animate Trajectories
        # Generate paths using actual DE iteration data
        path_cyan = ax.plot_line_graph(
            x_values=[-2.5, -1.0, 0.0],
            y_values=[0.5, -1.2, -2.0],
            line_color="#66FCF1",
            vertex_dot_style={"color": "#66FCF1", "radius": 0.05}
        )
        path_red = ax.plot_line_graph(
            x_values=[-2.5, -0.8, 0.5],
            y_values=[0.5, -0.2, -0.5],
            line_color="#FF0055",
            vertex_dot_style={"color": "#FF0055", "radius": 0.05}
        )
        
        # Show convergence paths drawing dynamically
        self.play(Create(path_cyan, run_time=4), Create(path_red, run_time=4))
        
        # Highlight global optimum
        optimum_dot = Dot(ax.coords_to_point(0.0, -2.0), color=YELLOW, radius=0.08)
        optimum_label = Text("Optimum (76.75 kg)", font_size=16, color=YELLOW).next_to(optimum_dot, DOWN)
        self.play(FadeIn(optimum_dot), Write(optimum_label))
        self.wait(2)
```

---

## 4. Key Formulas for Screen Overlays

To emphasize the rigor of the dynamic-structural codes, overlay these equations in clean, white LaTeX styling at matching script moments:

1. **Knuckle Geometry Coupling**:
   $$m_{knuckle} = \rho_{CFRP} \cdot V_{cuff}(D_o, t)$$
   *Appears at 0:40 to show the transition from decoupled to coupled mass.*

2. **The Slenderness Gate (Buckling Demand)**:
   $$\text{Feasible Zone} \implies \frac{L_r}{D} > 21$$
   *Appears at 1:25 as the red wall constraint is crossed.*

3. **Blade Scaling Power and Mass**:
   $$\text{Blade Mass} \propto \lambda^3 \quad \text{vs} \quad \text{Aerodynamic Drag} \propto \lambda^2$$
   *Appears at 2:10 to explain why the V6.3 optimizer scaled expansion blades down ($\lambda = 0.2$).*

---

## 5. Visualizing the V10 Campaign Lessons (Motion Graphics Guidelines)

This section maps the specific visual findings in the campaign report diagrams to direct cinematic instructions to ensure the lessons are visually clear:

### A. The Decoupled PCA Axes (Translating `v10-landscape.png` and `v10-nondimensional-atlas.png`)
* **Lesson**: Mass minimization decomposes into two near-orthogonal sub-problems (structural scale PC1 vs configuration PC2).
* **Cinematic Action**: 
  1. Display the dark 2D PCA landscape. Animate a coordinate grid overlay.
  2. Isolate **PC1 (Structural Scale)**: Highlight the x-axis, sliding a cursor left-to-right. Show a thumbnail 3D model of the TRPT growing larger, thicker, and heavier.
  3. Isolate **PC2 (Configuration)**: Highlight the y-axis, sliding a cursor up-and-down. Show a thumbnail model adding rotors and tilting bank angles.
  4. Bring both together: Show that the valley curves are wide and shallow along each axis separately, proving they can be optimized independently.

### B. Animating the Slenderness Gate (Translating `v10-traced-paths.png` bottom-left panel)
* **Lesson**: Below $L_r/D = 21$, structural drag exceeds aerodynamic power, acting as an air brake.
* **Cinematic Action**:
  1. Render a plot of **Mass vs. Slenderness ($L_r/D$)**.
  2. Draw the vertical red "Slenderness Gate" line at 21. 
  3. Animate the 31 island lines drawing themselves. Show the lines on the left ($L_r/D < 21$) spawning massive, vertical spikes to $10^6$ kg (representing the optimizer's penalty barrier).
  4. When an island line crosses to the right of the red gate, animate a soft "unlocking" chime, and show the line dropping smoothly along the descent corridor to the 76.75 kg basin.

### C. The Two-Basin Divergence Trap (Translating `v10-traced-paths.png` bottom-middle panel)
* **Lesson**: The optimization space is not a smooth bowl. It has a local attractor trap (Basin B) that islands cannot escape due to a high-mass fitness barrier.
* **Cinematic Action**:
  1. Tilt the 2D PCA landscape into 3D, creating a mass-elevation map (where lower mass = deeper valley).
  2. Highlight **Basin A (Optimum)** as a deep, glowing cyan pool and **Basin B (Local Trap)** as a shallower red pool. Highlight the ridge between them.
  3. Animate the 6 divergent paths (red lines) falling into Basin B. Show them trying to escape but bouncing off the surrounding walls.
  4. Draw the **Lambda Gradient ($\lambda_{bot}/\lambda_{top}$)** color scale as a color contour overlay. Highlight that Basin B is bounded by a high gradient (8-15) wind shear bias, while Basin A requires lowering it below 7.

