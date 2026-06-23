# Scientific Accuracy Audit — Pass 1 Notes

> **Date:** 2026-06-23
> **Scope:** All 5 KTD.jl documentation files
> **Method:** Cross-reference every numeric claim, paper reference, and factual assertion against live data sources (unified graph, file system, web-extracted papers).

---

## Critical Factual Errors Found

### 1. Graph stats — STALE EVERYWHERE
**Affected files:** collaboration-map.md, citation-lineage.md, KTD-paper-outline.md, knowledge-pipeline-sprint.md, domain.md

- **Documents say:** 6,986 nodes, 9,730 edges, 587 graph files
- **Actual (2026-06-23 15:30):** 7,048 nodes, 9,775 edges, 586 graph files, 878 paper nodes, 1,426 author nodes
- **Root cause:** Numbers captured mid-day before final industry doc federation. build_awes_graph.py ran after those numbers were written.

### 2. Density map numbers — UNVERIFIABLE
**Affected file:** collaboration-map.md

- Document lists: Scaling 591, Wind Resource 311, Aerodynamics 283, Control 276, Tether 192, TRPT 126, Economics 68, Ground-Gen 64, Safety 47, Structural 45, Multi-Kite 44, Launch 34
- Actual keyword match counts from current graph (label-only search on all node types):
  - control: 399, aerodynamics: 341, scaling: 231, tether: 226, ground-gen: 149, economics: 136, wind resource: 106, safety: 89, multi-kite: 86, structural: 69, launch: 44, trpt: 32
- **Root cause:** Phase 1 script used a different node type filter and different keyword sets. The numbers aren't reproducible from the current graph using the documented method.
- **Fix:** Re-derive density from current graph with documented keyword sets, or run Phase 1 script fresh and capture output.

### 3. Technique-specific K1 match counts — INACCURATE
**Affected file:** citation-lineage.md

| Technique | Document Claim | Actual (keyword match on labels) |
|-----------|---------------|----------------------------------|
| TRPT MTR | "12 papers, 25 findings, 30 methods" | 8 papers, 4 findings, 8 methods (TRPT-specific) |
| Tether drag | "2 papers, 9 findings" | 1 paper, 4 findings, 2 methods |
| Induction factor | "12 findings" | 16 findings |
| Power + equilibrium | "118 papers" | 124 findings with "power", 9 with "equilibrium/static" |

**Root cause:** Phase 3 script used intersection logic (A AND B AND C keywords) producing different count semantics than "all papers touching this topic."

### 4. TRPT researcher count — NEEDS QUALIFIER
**Affected files:** collaboration-map.md, knowledge-pipeline-sprint.md

- Document says: "only 8 names in the entire graph"
- Actual: 281 authors connected to TRPT-related nodes, but most are tangential (co-authors on broad AWE papers). Core TRPT researchers who've published specifically on TRPT/RAWES: Diehl, Leuthold, De Schutter, Beaupoil, Tulloch, Wacker, Read, Unterweger, Kheiri — approximately 8-12.
- **Fix:** "only ~8 researchers with TRPT-specific publications in the graph"

### 5. Tulloch PhD date — AMBIGUOUS
**Affected file:** citation-lineage.md

- Document says: "Tulloch PhD thesis (2019/2021)"
- Tulloch's PhD was awarded 2021 (University of Strathclyde). The 2019 reference may be to an earlier thesis submission or a separate MSc. His Energies paper is 2023.
- **Fix:** "Tulloch (2021 PhD, University of Strathclyde)"

### 6. V6.3 — DYNAMICALLY IMPOSSIBLE (not flagged)
**Affected file:** domain.md

- Campaign table shows V6.3 at 52.6 kg without caveat
- DECISIONS.md and windswept-knowledge skill both document V6.3 as "dynamically impossible — parasitic drag 14,277× aero power"
- **Fix:** Add "⚠ dynamically impossible" note to V6.3 row

### 7. Schmehl categorisation year — LIKELY WRONG
**Affected file:** collaboration-map.md (conversation opener)

- Document references "2019 AWE categorisation diagram"
- Schmehl's AWE book with the categorisation was published 2013 (2nd ed 2018). The 2019 may refer to a conference presentation.
- **Fix:** "Your AWE categorisation (Schmehl 2013/2018)"

### 8. "Only published multi-rotor TRPT optimisation at 50 kW" — OVERSTATEMENT
**Affected file:** collaboration-map.md

- Wacker (2022) published multi-rotor Daisy Stack optimisation. Tulloch (2023) discusses multi-rotor TRPT.
- **Fix:** "only DE-optimised multi-rotor TRPT configuration validated against full multibody dynamics at 50 kW"

---

## Minor Issues

9. **"469 with content"** — session record says 469 papers with content. Current graph has 878 paper nodes (including industry docs). Need to clarify: 469 of 540 academic papers produced non-empty graphs.

10. **"12 papers, 25 findings, 30 methods" for TRPT** — the "most-cited node" claim is true qualitatively (Tulloch's TRPT paper is central) but the numeric count can't be verified as stated.

11. **Citation-lineage.md §5 references NASA TM-1995-13233** — actual NASA document number needs verification. The web search found a 1995 NASA report by Ludwiczak on inertia relief, but TM number may differ.

12. **KTD-paper-outline.md says "6 novel techniques"** — technique 4 (ring-mapping) is explicitly "no publication credit — internal architecture." Should say "5 publishable techniques + 1 internal architectural fix."

---

## Next: Pass 2 — Citation Verification
Verify that every cited paper exists and is attributed correctly.
