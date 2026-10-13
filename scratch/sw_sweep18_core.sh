#!/usr/bin/env bash
# Sweep 18 core checks — science-writer, read-only; writes one log to scratch/.
set -u
cd "$(dirname "$0")/.."
SKILL=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
LOG=scratch/sw_sweep18_core.log
{
echo "== sweep 18 core $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
echo
echo "== head =="
git rev-parse HEAD
echo
echo "== span log (all files) =="
git log --oneline f5e8e7d..HEAD
echo
echo "== span log (tracker) =="
git log --oneline f5e8e7d..HEAD -- docs/reporting/draft-tracker.md
echo
echo "== span log (draft) =="
git log --oneline f5e8e7d..HEAD -- docs/reporting/drafts/2026-10-08-report-first-draft.md
echo "(empty = no mover)"
echo
echo "== span log (register) =="
git log --oneline f5e8e7d..HEAD -- docs/reporting/numbers-register.md
echo "(empty = no mover)"
echo
echo "== span log (queue) =="
git log --oneline f5e8e7d..HEAD -- docs/reporting/glossary-candidates.md
echo "(empty = no mover)"
echo
echo "== zero-diff checks (empty = zero) =="
echo "--- draft vs eb0e08d:"
git diff eb0e08d..HEAD -- docs/reporting/drafts/2026-10-08-report-first-draft.md
echo "--- register vs 88277f6:"
git diff 88277f6..HEAD -- docs/reporting/numbers-register.md
echo "--- tracker working tree:"
git diff -- docs/reporting/draft-tracker.md
echo "(all empty = zero)"
echo
echo "== STE draft tip =="
python3 ste-lint.py --fail-above 2.0 docs/reporting/drafts/2026-10-08-report-first-draft.md
echo "rc=$?"
echo
echo "== STE tracker base =="
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep18_tracker_base.md
echo "rc=$?"
echo
echo "== STE tracker tip =="
python3 ste-lint.py --fail-above 2.0 docs/reporting/draft-tracker.md
echo "rc=$?"
echo
echo "== offender diff tracker base vs tip =="
diff scratch/sw_sweep18_off_base.txt scratch/sw_sweep18_off_new.txt
echo "(only the header line differs)"
echo
echo "== token diff tracker =="
python3 "$SKILL/scripts/draft-token-diff.py" . docs/reporting/draft-tracker.md f5e8e7d 2ebbd22
echo
echo "== token attrib tracker =="
python3 "$SKILL/scripts/token-attrib.py" . docs/reporting/draft-tracker.md f5e8e7d 2ebbd22
echo
echo "== ancestry =="
for c in 2db50f9 8fb529e eb0e08d 9cecee3 88277f6; do
  if git merge-base --is-ancestor "$c" HEAD; then echo "$c: ancestor OK"; else echo "$c: NOT ancestor"; fi
done
echo
echo "== held tokens =="
grep -n "3\.55" docs/reporting/draft-tracker.md
grep -n "1\.94\|5\.18" docs/reporting/drafts/2026-10-08-report-first-draft.md
} > "$LOG"
echo "wrote $LOG"
