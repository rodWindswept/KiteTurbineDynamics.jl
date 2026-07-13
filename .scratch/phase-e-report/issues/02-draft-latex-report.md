# Ticket 2 — Draft LaTeX Community Report

**What to build:** `docs/outreach/phase-e-community-report.tex` — a complete LaTeX document that embeds the 5 generated figures and presents the Phase D findings to the AWES community.

**Blocked by:** Ticket 1 (needs figure `.tex` files to exist for `\input`)

**Structure:**
1. Title page: "TRPT Design Envelope — KiteTurbineDynamics.jl Phase D Findings"
2. Abstract: one paragraph — one viable design, ring compression boundary, invite collaboration
3. §1 Introduction: TRPT architecture, multi-rotor scaling, left-flank decision
4. §2 Method: test protocol, spoke implementation, crossover analysis
5. §3 Results: 5 figures embedded, Phase D data table
6. §4 Discussion: structural envelope interpretation, cascade failure mechanism
7. §5 Open Questions: ring topology, wake interaction, hardware validation
8. §6 Collaboration: Strathclyde, Freiburg, Christof, Ollie — specific invitations
9. References: Chen 2026, Amjad 2026, Tulloch 2023, Leuthold 2019, Beaupoil 2026

**Template:** Extend the existing `docs/community/ktd-community-report.tex` (preamble, styling). Keep the `\RB{}` convention retired — all numbers are post-fix Phase D.

**Tone:** Honest, data-forward, not promotional. "We found one viable design. Here's the structural boundary. Help us widen it."

**Acceptance criteria:**
- [ ] `latexmk -pdf` compiles clean (no errors, no overfull boxes)
- [ ] All 5 figures embedded with `\input{figures/...}`
- [ ] Phase D data table present with full 9-design sweep
- [ ] Authors: Rod Read, Windswept & Interesting Ltd
- [ ] References section complete

**Status:** ready-for-agent
