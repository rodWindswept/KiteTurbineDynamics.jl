# Outreach Document Set

This directory replaces the monolithic `ktd-community-report.pdf` (v0.1, July 2026), decomposed by audience and shelf-life:

| Document | Audience | Shelf-life | Standard |
|---|---|---|---|
| `technical-report.md` | Anyone citing the work | Years (versioned) | Versioned report → Zenodo DOI (arXiv optional) |
| `brief-strathclyde.md` | Yue / Chen / Amjad / Carroll | Until answered | One-page personalized brief, sent by email |
| `brief-freiburg.md` | Diehl group | Until answered | One-page personalized brief, sent by email |
| `brief-someawe-labs.md` | Christof Beaupoil | Oct 2026 visit | One-page personalized brief, sent by email |
| `brief-tulloch.md` | Oliver Tulloch | Standing | Attribution/co-authorship invitation |
| `GET-INVOLVED.md` | Open-source contributors | Evergreen | Merge into README / CONTRIBUTING.md |

## What was deliberately removed

**The funding section (§6 of v0.1) stays internal.** Grant deadlines expire and date the whole document; the pipeline is already maintained as a living doc on the Windswept drive (17 opportunities, updated weekly). Outreach documents carry one sentence: *"consortium formation needed within ~4 weeks — pipeline available on request."*

## Publication gates (do not ship until)

1. **Control-map re-run through the fixed settle completes.** The v0.1 headline (4.2×/4.1× static–dynamic gap) was computed with the broken settle stage; all ⟨RB⟩-marked numbers in the technical report await re-baseline. Shipping the old numbers under hostile scrutiny invites exactly the retraction we've been doing internally.
2. **Figures regenerated per `docs/reporting-charts-prd.md`**: white background, provenance footer (script @ git-hash · data · model · date), confidence badge (currently P everywhere), consistency stamps. The v0.1 figures were dark-background dashboard exports with none of these.
3. **Internal consistency check**: v0.1 said 4.2× in the abstract and 4.1× in §3.1. One number, stated once, computed from the re-run.

## Sequencing

Technical report freezes → Zenodo DOI minted → briefs go out referencing the DOI → GET-INVOLVED merges into README. The briefs should never point at a moving target.
