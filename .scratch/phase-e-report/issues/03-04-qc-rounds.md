# Ticket 3.0 — QC Round 1: Data Correctness (First Pass)

**What to build:** Verification that every plotted data point in each of the 5 figures matches a value in the source CSV. Diff-based: for each figure, list all (x, y) pairs plotted, check against CSV rows, flag discrepancies.

**Blocked by:** Ticket 2 (report must exist to check figures against)

**Method:**
1. For each of 5 figures, extract plotted data points from the `.tex` source
2. Cross-reference against source CSV (cited in figure header comment)
3. For scatter plots (F1): check every (x, y) ∈ CSV rows
4. For line plots (F3, F5): check at least 5 points along each curve
5. For annotations (F2 cascade threshold): verify the value matches the crossover analysis

**Output:** `docs/outreach/qc/round-1-data.md` — table per figure showing status

**Acceptance criteria:**
- [ ] All 5 figures checked
- [ ] Any data discrepancy flagged with CSV row reference
- [ ] QC report written to `docs/outreach/qc/`

**Status:** ready-for-agent

---
# Ticket 4.0 — QC Round 1: Visual + Style (First Pass)

**What to build:** Visual layout and typographic review of the compiled PDF against the existing diagram style conventions.

**Blocked by:** Ticket 2

**Method:**
1. Compile PDF with `latexmk -pdf`
2. Check each figure: axes labeled? legend present? no overlapping text?
3. Check consistent styling: font sizes match `docs/awes-forum-diagrams/` conventions
4. Check LaTeX log: no overfull hbox/vbox warnings, fonts embedded
5. Check page layout: margins, figure placement, no orphaned section headers

**Output:** `docs/outreach/qc/round-1-visual.md` — per-figure visual issues

**Acceptance criteria:**
- [ ] All 5 figures visually checked
- [ ] Any layout issues flagged with page/figure reference
- [ ] `latexmk` exit 0, no warnings in log

**Status:** ready-for-agent

---
# Ticket 3.1 — QC Round 2: Data Correctness (Corrections)

**What to build:** Re-check against corrected data after Round 1 fixes applied.

**Blocked by:** Tickets 3.0, 4.0 (must have Round 1 findings to know what was fixed)

**Output:** `docs/outreach/qc/round-2-data.md`

**Acceptance criteria:**
- [ ] All Round 1 data discrepancies resolved or acknowledged
- [ ] Fresh diff check against source CSVs passes

**Status:** ready-for-agent

---
# Ticket 4.1 — QC Round 2: Visual + Style (Corrections)

**Blocked by:** Tickets 3.0, 4.0

**Output:** `docs/outreach/qc/round-2-visual.md`

**Acceptance criteria:**
- [ ] All Round 1 visual issues resolved
- [ ] Fresh PDF compile clean

**Status:** ready-for-agent

---
# Ticket 3.2 — QC Round 3: Data Correctness (Final)

**Blocked by:** Tickets 3.1, 4.1

**Output:** `docs/outreach/qc/round-3-data.md`

**Acceptance criteria:**
- [ ] Zero data discrepancies across all 5 figures

**Status:** ready-for-agent

---
# Ticket 4.2 — QC Round 3: Visual + Style (Final)

**Blocked by:** Tickets 3.1, 4.1

**Output:** `docs/outreach/qc/round-3-visual.md`

**Acceptance criteria:**
- [ ] Zero visual issues
- [ ] PDF ready for Rod review

**Status:** ready-for-agent
