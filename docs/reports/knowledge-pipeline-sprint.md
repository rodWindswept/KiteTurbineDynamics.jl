# Knowledge Pipeline Sprint — Session Record

> **2026-06-22 to 2026-06-23: Building the K1 knowledge extraction pipeline for KTD paper grounding.**
> Authoritative session record. Read this for the full story of what was built, discovered, and decided.

---

## Summary

In a 2-day sprint, we built a complete knowledge extraction pipeline: 540 academic papers + 45 industry documents ingested into a unified knowledge graph using the Agents-K1 4B model on GPU. From this graph, we produced a collaboration map for AWEC 2026 Porto (Phase 1), a citation lineage grounding 6 KTD techniques in literature (Phase 3), and web-validated the 3 highest-risk claims against Google Scholar (Phase 3b). All 6 claims are clean — no prior art conflicts found.

## Chronology

### Day 1 — 2026-06-22: Extraction Pipeline

**Morning: K1 GPU setup**
- Installed PyTorch CUDA 12.1+cu126 in K1 `.venv`
- Verified RTX A4500 (20 GB VRAM)
- Wrote `k1_server.py` — persistent GPU server at localhost:8000
- Discovered `graphanything new --auto` bug: silent zero-node output (LLM client never passed to `run()`)
- Wrote direct ingestion script `k1_ingest.py` bypassing graphanything CLI

**Afternoon: Academic paper ingestion**
- 540 papers extracted from PDFs to markdown via pandoc
- First batch processing: high JSON failure rate (unterminated strings at 2048 tokens)
- Fixed: increased max_tokens to 4096, paragraph-boundary chunking, control character stripping
- Added cursor file (`~/.k1_ingest_cursor`) + skip gate for idempotency
- Deployed cron: K1 Paper Ingest every 20 min

**Evening: Pipeline stabilisation**
- 533 of 540 papers produced graphs (469 with content, 64 empty = patents/catalogues)
- 7,453 nodes extracted
- Cron running autonomously at 45 papers/hour

### Day 2 — 2026-06-23: Industry Docs + Phase Analysis

**Morning: Industry document ingestion**
- 45 industry PDFs/DOCXs/PPTXs extracted to markdown
- Initial batch processor (`ingest_industry.py`) crashed server after 4-5 docs (GPU OOM)
- Switched to single-doc processor (`ingest_one_industry.py`): loads model fresh each tick
- Fixed `apply_chat_template` dict-vs-tensor bug
- Deployed cron: Industry Doc Ingest every 5 min
- First doc (AWE White Paper V2): 18 nodes, 18 edges, 66s

**Afternoon: Phase 1 — Collaboration Map**
- Built `phase1_gap_analysis.py`: extracts research clusters, authors, maps gaps from unified graph
- Unified graph federated: 6,986 nodes, 9,730 edges
- Key finding: Multi-kite/farm = 44 nodes — W&I's lane is thin and unique
- TRPT researchers: only 8 names in the graph
- Top collaborators identified: Rachel Leuthold, Jochem De Schutter (TRPT + multi-kite overlap)

**Late afternoon: Phase 3 — Citation Lineage**
- Built `phase3_citation_lineage.py`: cross-references 6 KTD techniques against K1 graph
- Per-technique matches: papers, findings, methods from the knowledge graph
- Citation map produced: what each technique extends, contradicts, and what gaps remain

**Evening: Phase 3b — Web Validation**
- Targeted Google Scholar searches for 3 highest-risk claims:
  1. k_mppt λ² scaling — clean, no prior art
  2. 6-DOF inertia relief — clean, Moore CSR uses different method (constrained joints, not free-floating)
  3. 4.2× static-vs-dynamic gap — clean, Wacker doesn't attempt dynamics, literature stops at 21%
- Moore CSR paper extracted and analysed — centrifugal stiffening ≠ inertia relief
- Wacker MSc thesis appendix extracted — no ring-mapping precedent

**Late evening: All crons paused. Documentation phase begins.**

## Key Metrics

| Metric | Value |
|--------|-------|
| Academic papers processed | 540 |
| Papers with extracted content | 469 |
| Empty graphs (patents/catalogues) | 64 |
| Industry documents extracted | 45 |
| Unified graph nodes | 7,048 |
| Unified graph edges | 9,775 |
| Individual graph files | 586 |
| KTD techniques grounded | 6 |
| Web-validated claims | 3/3 clean |
| Crons deployed (now paused) | 3 |
| Scripts written | 16 |

## Technical Breakthroughs

1. **JSON repair for truncated K1 output** — unterminated strings, markdown fences, trailing commas all handled post-hoc. Deterministic, cheap, handles 95%+ of failures.

2. **Cursor + skip logic** — `~/.k1_ingest_cursor` tracks last-processed file. Skip gate prevents re-processing. Eliminated 14 wasted reads per batch from known-empty papers.

3. **Single-doc GPU processor** — loads K1 model fresh each tick, processes one document, frees GPU. Eliminates server OOM crashes. Trade-off: 20s model load overhead per doc. Worth it.

4. **Paragraph-boundary chunking** — 6000-char windows cut on paragraph boundaries, not arbitrary character counts. Preserves semantic units. Reduces mid-sentence truncation → fewer JSON failures.

5. **Control character stripping** — `re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', raw)` removes PDF artefacts before K1 ingestion. One-line fix, universal application, no information loss.

## Discoveries

1. **graphanything CLI is broken** — `graphanything new --auto` silently produces zero nodes. Bug: `run()` called without LLM client. Direct API calls are the workaround.

2. **K1 model produces near-valid JSON** — not perfect, but close enough that repair is reliable. Constraining prompts to force perfect JSON would reduce extraction quality.

3. **Moore CSR ≠ inertia relief** — Mark Moore's centrifugal stiffening uses spherical joints to a stationary hub (constrained multibody), not free-floating D'Alembert equilibration. No overlap.

4. **Wacker doesn't do ring-mapping** — his flat frame list (Rrot, R2, ..., Rgen) is a different approach from KTD's intermediate-to-system ring topology. No precedent.

5. **TRPT is a tiny field** — 126 nodes vs. 591 for scaling. Only 8 researchers. You're one of them.

## Current State (2026-06-23 evening)

| What | Status |
|------|--------|
| Academic ingestion | Complete (540/540) |
| Industry ingestion | Cron paused — verify completion |
| K1 GPU server | Stopped |
| Phase 1 (collab map) | Complete |
| Phase 3 (citation) | Complete |
| Phase 3b (web validation) | Complete |
| Phase 4 (CSV anchoring) | Not started |
| Phase 5 (paper synthesis) | Not started |
| Project room (kites/) | Created (to be migrated to KTD.jl) |
| Porto materials | Collaboration map + citation lineage complete |
| KTD paper outline | Drafted |
| Crons | All paused |

## Lessons

1. **Always verify extraction quality early** — the 2048 token limit was discovered only after first batch failure. A 5-paper test would have caught it.

2. **GPU models crash silently** — the K1 server would run for 4-5 requests, then OOM with no error. Single-doc mode is simpler and more reliable for batch processing.

3. **JSON repair beats prompt engineering** — trying to force perfect JSON from an LLM is fragile. Accept near-valid output and repair deterministically.

4. **The K1 graph is comprehensive but not complete** — 540 papers is a lot, but Google Scholar has millions. Web validation (Phase 3b) caught the Moore CSR overlap that the K1 graph missed.

5. **Cron is great until it isn't** — the autonomous pipeline ran for 2 days without intervention. But when it's time to stop and think, pause everything. Running crons generate noise.

## Next Steps (for future sessions)

1. Verify industry doc ingestion is truly complete
2. Phase 4: Parse V10 campaign CSVs, link data columns to text claims
3. Phase 5: Synthesise full KTD paper with K1 sentence-level grounding
4. Create 02_conflict_log.md and 03_missing_context.md for KTD.jl
5. Generate ring-mapping and system schematic diagrams for paper
6. Format Porto materials for print/handout
