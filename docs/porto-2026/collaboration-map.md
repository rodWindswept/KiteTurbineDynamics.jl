# Porto 2026 — Collaboration Map

> **Who to talk to, about what, and why.**
> Generated from the K1 knowledge graph (7,048 nodes, 9,775 edges, 586 individual paper graphs).
> Phase 1 analysis — 2026-06-23.

---

## Research Density Map

*Approximate topic distribution from Phase 1 keyword co-occurrence analysis of the K1 knowledge graph. Numbers represent edge-weighted keyword matches, not direct paper counts. Updated analysis against current graph structure recommended.*

```
Scaling/Design      ████████████████████████████████████████████████████████████ 591
Wind Resource       ████████████████████████████████ 311
Aerodynamics        ████████████████████████████████ 283
Control/Flight      ████████████████████████████████ 276
Tether/Drag         ███████████████████ 192
TRPT/Rotary         █████████████ 126
Economics/LCOE      ██████ 68
Ground-Gen/Yo-Yo    ██████ 64
Safety/Regulation   ████ 47
Structural          ████ 45
Multi-Kite/Farm     ████ 44   ← W&I's primary lane
Launch/Landing      ███ 34
```

---

## Where KTD Is Unique

| Gap Area | Graph Nodes | Signal |
|-----------|-------------|--------|
| Rigid rotor blade design for TRPT | 9 | Severe gap — barely studied |
| 50 kW-class economics | 10 | Thin — your niche |
| Coaxial/stacked rotors | 33 | Moderate but you own this |
| Multi-kite/farm configurations | 44 | Thin relative to strategic importance |

---

## Who to Talk To — Ranked by Windswept Relevance

| # | Researcher | Score | Covers |
|---|------------|-------|--------|
| 1 | **Roland Schmehl** | 32 | Tether, Scaling, Aero — convenor of the field |
| 2 | **Moritz Diehl** | 18 | TRPT, Tether, Scaling, Aero — power fundamentals |
| 3 | **Lorenzo Fagiano** | 11 | Tether, Scaling, Aero — control & optimisation |
| 4 | **Rachel Leuthold** | 11 | **TRPT**, Tether, Scaling, Aero — closest TRPT collaborator |
| 5 | **Jochem De Schutter** | 9 | **TRPT**, Tether, Scaling, **Multi-Kite** — rare multi-kite overlap |
| 6 | **Florian Bauer** | 8 | Tether, Scaling |
| 7 | **Christof Beaupoil** | 7 | **TRPT**, Tether, Scaling, Aero — someAWE Labs |
| 8 | **Oliver Tulloch** | 6 | **TRPT**, Tether, Scaling — TRPT inventor |
| 9 | **Mojtaba Kheiri** | 6 | Tether, Scaling, Aero — induction corrections |
| 10 | **Jannis Wacker** | — | Steady-state Daisy Kite optimisation (DTU, 2022) |

**TRPT people are rare** — approximately eight researchers in the graph have published specifically on TRPT/RAWES systems, and one of them is you. Rachel Leuthold and Jochem De Schutter are your closest natural collaborators: they touch TRPT + multi-kite/farm.

---

## Conversation Starters

### Roland Schmehl
*"Your AWE categorisation (Schmehl 2013/2018, updated 2019) is still the field's reference. KTD introduces a multi-rotor TRPT configuration that blurs the 'fixed ground station' category — the rotors stack along the tether rather than at a single station. How does your taxonomy handle multi-point airborne generation?"*

### Moritz Diehl
*"Your drag-mode power theorem (CD,power = CD/2) gives a clean torque/speed target. We've found that with TRPT's tether drag contribution, the optimum shifts — the ½ relationship doesn't hold when power transmission losses enter the equilibrium. Have you or your group modelled this?"*

### Rachel Leuthold / Jochem De Schutter
*"You're two of the only people in the world who've published on TRPT dynamics beyond Oliver Tulloch's foundational work. Our KTD solver now captures a 4.2× static-to-dynamic power gap — 50 kW static prediction becomes 12 kW in full multibody. Has your group seen anything comparable?"*

### Christof Beaupoil
*"Your cyclic pitch control on someAWE's helix TRPT is the most advanced rotor control I've seen on a flying RAWES. We're exploring whether independent rotor pitching could close the static-vs-dynamic gap in stacked configurations. What did you learn about wake interaction between segments?"*

### Oliver Tulloch
*"The TRPT model you built is the foundation we all stand on. One thing the KTD solver has revealed: MTR shouldn't be a fixed parameter — it needs to be a DE optimisation variable. At different scales and rotor counts, the optimal MTR shifts. Have you explored this?"*

---

## Organisations in the Graph

IEA Task 48, AWEurope, BVGA, Kitepower, Ampyx Power, Enerkite, kiteKRAFT, Skysails Power, TwingTec, Kitemill, someAWE Labs, **Windswept & Interesting** (listed as Stakeholder).

---

## Strategic Notes

- **Multi-kite/farm is your lane and it's thin** — 30 papers vs. 90 for control. The field has barely touched multi-rotor TRPT. Your V10 Tight result (4 rotors, 49.2 kg) is the only DE-optimised multi-rotor TRPT configuration validated against full multibody dynamics at 50 kW scale.
- **The 4.2× gap is your strongest talking point** — no one else has quantified the static-vs-dynamic discrepancy for TRPT. Literature consensus is 18-21% for conventional AWE; your 420% gap is an order of magnitude larger and TRPT-specific.
- **Don't pitch — ask.** The best Porto conversations start with "we've observed X, has your group seen anything similar?" rather than "we've solved X."
