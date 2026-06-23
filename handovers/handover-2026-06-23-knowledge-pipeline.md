# Handover — Knowledge Pipeline Sprint

> **Date:** 2026-06-23
> **From:** 2-day K1 knowledge extraction sprint
> **To:** Next session (Phase 4+5, Porto prep)

---

## What We Built

A complete knowledge extraction pipeline serving KTD.jl's literature grounding:

- **540 academic papers + 45 industry documents** ingested via K1 4B GPU model
- **Unified knowledge graph:** 6,986 nodes, 9,730 edges at `~/Documents/kites/awes_graph/awes_unified.graph.json`
- **16 Python scripts** at `~/Documents/kites/scripts/` — full ingestion, analysis, and synthesis pipeline
- **Phase 1:** Collaboration map for AWEC 2026 Porto
- **Phase 3:** Citation lineage for 6 KTD techniques
- **Phase 3b:** Web validation — all 3 high-risk claims clean (Moore CSR ≠ inertia relief; Wacker ≠ ring-mapping; 4.2× gap is TRPT-unique)

## What's Paused

- **All 3 crons paused** — K1 Paper Ingest, Industry Doc Ingest, AWES Paper Ingest
- **K1 GPU server stopped** — use single-doc mode if needed
- **GPU free** for other work

## Key Files

| File | Purpose |
|------|---------|
| `docs/porto-2026/collaboration-map.md` | Who to talk to at Porto, conversation starters |
| `docs/porto-2026/citation-lineage.md` | 6 techniques — what to cite, extend, contradict |
| `docs/porto-2026/KTD-paper-outline.md` | Paper skeleton with evidence table and citation map |
| `docs/reports/knowledge-pipeline-sprint.md` | Full session record — chronology, metrics, discoveries |
| `PROJECT_ROOM.md` | Updated with Phase 1–3b results |
| `DECISIONS.md` | Appended with 6 pipeline decisions |
| `01_source_inventory.md` | Updated external pipeline section |

## What's Next (Phase 4–5)

1. **Phase 4 — CSV data anchoring:** Parse V10 campaign CSVs, link data columns to text claims
   - Source: `scripts/results/v10_campaign_50kw/` and `v10_campaign_50kw_old/`
   - Goal: per-claim evidence with exact column references
2. **Phase 5 — Paper synthesis:** Full KTD paper with K1 sentence-level grounding
   - Use `docs/porto-2026/KTD-paper-outline.md` as skeleton
   - Ground each claim in both K1 graph AND campaign CSV data
3. **Verify industry doc ingestion** — are all 45 truly complete?
4. **Create 02_conflict_log.md** and **03_missing_context.md** (referenced but not yet created)
5. **Generate diagrams** for paper (ring-mapping, static-vs-dynamic gap, system schematic)

## Quick Start

```bash
# Check graph state
python3 -c "
import json
g = json.load(open('/home/rod/Documents/kites/awes_graph/awes_unified.graph.json'))
print(f'{len(g[\"nodes\"])} nodes, {len(g[\"edges\"])} edges')
"

# View Porto materials
ls docs/porto-2026/

# Check cron status (via Hermes agent)
# All should show 'paused'
```

## Pitfalls

- **graphanything CLI is broken** — `graphanything new --auto` silently produces zero nodes. Use direct API calls via `k1_ingest.py`.
- **K1 server OOM** — persistent server crashes after 4-5 requests. Use single-doc mode (`ingest_one_industry.py`) for any new documents.
- **Control characters in PDF text** — always strip with `re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', raw)` before K1 ingestion.
- **JSON repair is required** — K1 output is near-valid, not perfect. `k1_ingest.py` handles this.
- **Two-repo pitfall** — KTD.jl (this repo) ≠ TRPTKiteTurbineJulia (legacy). Always work in KTD.jl on `master`.
- **Do not restart crons** without explicit direction — they'll start sending Signal notifications again.

## Contacts

- **Rod Read** — rod@windswept.energy, Signal (at AWEC 2026 Porto ~1 week from now)
- **K1 model** — local GPU, no external API needed
- **Knowledge graph** — local files, no database server
