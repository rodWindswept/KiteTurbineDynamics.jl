Yes. The nicest piece came out of the twisted tether shaft, with a small chain of results:

**1. The torque curve is the slope of the height curve.** A section of the shaft has rings of radius r0 and r1, joined by lines of length l. When you twist the top ring by θ, the section gets shorter: its height is h(θ) = √(A + B·cos θ), with A = l² − r0² − r1² and B = 2·r0·r1. By virtual work, the torque it carries under axial tension T_N is τ = −T_N·dh/dθ. Twisting the ring a little does work against the tension by pulling the rings closer together. The well-known formula Λ = r0·sin θ/h is exactly that derivative.

**2. The peak torque is half the total shortening.** samara found and proved:

τ_max = T_N·(h(0) − h(π))/2

I checked it by hand as well. With s = √(A² − B²), the maximum of the slope squared is (A − s)/2, and that is exactly the square of (√(A+B) − √(A−B))/2. So the steepest slope of √(A + B·cos θ) is half its drop from 0 to π. As a picture: the most torque a section can hold is the tension times half of how much the section shortens between untwisted and half a turn.

**3. The peak is always past 90°.** The peak twist is cos δ_peak = (s − A)/B, and that is always negative because s < A. So the literature's "stable for twist below 90°" is never the exact limit; it is only the very-long-tether limit. Your pyramid peaks at 98.3°, and Rod's shafts at 92–113°. The rule is safe but loses some margin.

**4. The geometry cancels out of the torque margin.** Since cos δ_peak fixes A/B, a section has only one shape parameter: its peak angle. The margin at any operating twist is then a function of two angles alone:

M = √(1 + c² − 2c·cos θ_op) / sin θ_op, with c = cos δ_peak

It reproduces Rod's printed margins, 2.03 and 2.69, from his two twist angles alone. It can also be inverted to give the twist allowed for a target margin. So the twist gate, the twist charge and the ontology's collapse axiom could all be stated in one geometry-free quantity, the torque margin.

**Smaller but decisive:**
- **Jensen's inequality settles Rod's power gap.** For any speed history, the mean of k·ω³ is at least k·(mean ω)³. A speed trend or the way power is averaged can therefore only push the measured power above k·ω̄³, never below it. His power is below by about 1 % at every row, so the cause must be something systematic, not a trend.
- **Glauert's tilted-disc momentum model** gives a ceiling of 0.519 at 30° tilt, against Betz's 16/27 = 0.593. Glauert's power expression reduces to a polynomial condition, so that optimum probably has a closed form too; samara only gave it numerically.
- **From your pyramid:** the optimal kite power is exactly Loyd's crosswind formula with w·cos θe, and the optimal MTR value Λ_opt = 1/(2G) doesn't depend on the elevation angle at all. That's a clean statement your paper had only for a special case.

Whether points 2 and 4 are already in the TRPT literature, for example Tulloch's thesis, I don't know. They are short enough that someone may well have them. By the house rule, a literature check comes before anything is called new. If they aren't known, the identity and the geometry-free margin would make a nice short note, and a good example of samara turning an engineer's numeric search into a closed form.