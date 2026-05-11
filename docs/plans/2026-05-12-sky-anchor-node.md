# Implementing the "Sky Anchor" Node

**Status:** Proposed / Ready for next session
**Owner:** Next Agent
**Date:** 12 May 2026

## Context: The Furl Bug
In the previous session (`2026-05-11-lift-line-as-spring.md`), we fixed the frame-1 bearing "snap" and bridle asymmetry by replacing the 80° fixed-vector lift force on the bearing with a spring-based "cyan line" pulling toward a static `lifter_anchor` located on the 30° shaft axis. 

While this perfectly solved the static force balance at frame 0, it **broke the Furl scenario**. The furl mechanism relies on paying out the backline so that the kite's upward 80° lift can raise the TRPT rotor and spill wind. Since the `lifter_anchor` is currently a static point fixed at 30°, releasing the backline just makes the backline go slack—the hub doesn't rise.

## The Real-World Solution
In the physical kite turbine, the "cyan line" exists but is shorter. Its upper end forms a **three-way tether knot ("Sky Anchor")**. 
This Sky Anchor is the balance point between three forces:
1. **The Lifter Kite:** Pulling upwards at ~80° based on wind speed.
2. **The Backline:** Pulling downwards toward the ground anchor.
3. **The TRPT Load (Cyan Line):** Pulling downwards/downwind toward the bearing.

When the backline is paid out by the winch, its downward constraint relaxes. The 80° kite force wins the tug-of-war, pulling the Sky Anchor upwards. The Sky Anchor pulls the cyan line, which lifts the bearing, steepening the elevation angle and safely spilling wind from the TRPT rotor.

## Approach
We need to model the Sky Anchor as a real dynamic element in the ODE.

1. **New Node:** Introduce a `SkyAnchorNode` (similar to `BearingNode`) to the multibody system.
2. **Shift Forces:**
   - The **Aero Lift Force** (~80°) and the **Backline Catenary Force** currently applied to the `BearingNode` must be moved to the `SkyAnchorNode`.
   - The `BearingNode` will now only experience its own gravity, the symmetric bridles pulling from the hub, and the tension from the cyan line.
3. **Cyan Line Sub-segment:** Introduce a new `RopeSubSegment` representing the cyan line (connecting `BearingNode` to `SkyAnchorNode`). This acts as a standard spring-damper.

## Expected Steps
1. **`src/types.jl`**: Define `SkyAnchorNode`. Update `KiteTurbineSystem` to include its ID.
2. **`src/initialization.jl`**: 
   - Position the `SkyAnchorNode` dynamically at initialization based on the force balance of the lift kite, backline design length, and the new cyan line segment. 
   - Create a `RopeSubSegment` linking the bearing to the sky anchor.
3. **`src/ring_forces.jl`**: 
   - Move the `T_lift` calculation block to apply its force to `forces[sky_anchor_gid]`.
   - Move the backline catenary block to apply to `forces[sky_anchor_gid]`.
4. **`src/visualization.jl`**: 
   - The "Cyan Line" should read from the ODE state, linking the bearing position to the sky anchor position.
   - The "Deep Sky Blue" lift kite marker should originate from the sky anchor, not the bearing.

## Gate / Pass Condition
- **Furl Works:** Running `scripts/interactive_dashboard.jl` and selecting the "Furl" scenario results in the sky anchor and bearing rising cleanly, dropping the output power by spilling wind.
- **Frame 0 Alignment:** `test/test_bearing_alignment.jl` must remain completely green (bearing sits exactly on the shaft axis with equal bridle lengths at rated power).