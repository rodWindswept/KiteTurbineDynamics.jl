#!/usr/bin/env bash
# Sweep 19 core checks — science-writer, read-only; writes one log to scratch/.
set -u
cd "$(dirname "$0")/.."
SKILL=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
DRAFT=docs/reporting/drafts/2026-10-08-report-first-draft.md
TRACK=docs/reporting/draft-tracker.md
REG=docs/reporting/numbers-register.md
LOG=scratch/sw_sweep19_core.log
{
echo "== sweep 19 core $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
echo
echo "== head =="
git rev-parse HEAD
echo
echo "== span log (all files) 0415d18..HEAD =="
git log --oneline 0415d18..HEAD
echo
echo "== span log (draft) eb0e08d..HEAD =="
git log --oneline eb0e08d..HEAD -- "$DRAFT"
echo
echo "== span log (register) 88277f6..HEAD =="
git log --oneline 88277f6..HEAD -- "$REG"
echo
echo "== span log (tracker) 2ebbd22..HEAD =="
git log --oneline 2ebbd22..HEAD -- "$TRACK"
echo
echo "== span log (queue) 6f22af1..HEAD =="
git log --oneline 6f22af1..HEAD -- docs/reporting/glossary-candidates.md
echo "(empty = no mover)"
echo
echo "== zero-diff checks (empty = zero) =="
echo "--- draft vs a90122b:"
git diff a90122b..HEAD -- "$DRAFT"
echo "--- register vs d7f8871:"
git diff d7f8871..HEAD -- "$REG"
echo "--- tracker working tree:"
git diff -- "$TRACK"
echo "(all empty = zero)"
echo
echo "== register append-only proof =="
git diff --numstat 88277f6..d7f8871 -- "$REG"
echo
echo "== register diff (the two display notes) =="
git diff 88277f6..d7f8871 -- "$REG"
echo
echo "== STE draft v0.30 =="
python3 ste-lint.py --fail-above 2.0 "$DRAFT"
echo "rc=$?"
echo
echo "== STE draft v0.29 (base extract) =="
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep19_draft_v029.md
echo "rc=$?"
echo
echo "== STE tracker base =="
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep19_tracker_base.md
echo "rc=$?"
echo
echo "== STE tracker tip =="
python3 ste-lint.py --fail-above 2.0 "$TRACK"
echo "rc=$?"
echo
echo "== offender diff draft v0.29 vs v0.30 =="
diff scratch/sw_sweep19_off_v029.txt scratch/sw_sweep19_off_v030.txt
echo "(header line only expected)"
echo
echo "== offender diff tracker base vs tip =="
diff scratch/sw_sweep19_off_tracker_base.txt scratch/sw_sweep19_off_tracker_tip.txt
echo "(header line only expected)"
echo
echo "== draft diff v0.29 -> v0.30 =="
git diff eb0e08d..a90122b -- "$DRAFT"
echo
echo "== tracker diff 2ebbd22 -> a90122b =="
git diff 2ebbd22..a90122b -- "$TRACK"
echo
echo "== token diff draft =="
python3 "$SKILL/scripts/draft-token-diff.py" . "$DRAFT" eb0e08d a90122b
echo
echo "== token attrib draft =="
python3 "$SKILL/scripts/token-attrib.py" . "$DRAFT" eb0e08d a90122b
echo
echo "== token diff tracker =="
python3 "$SKILL/scripts/draft-token-diff.py" . "$TRACK" 2ebbd22 a90122b
echo
echo "== token attrib tracker =="
python3 "$SKILL/scripts/token-attrib.py" . "$TRACK" 2ebbd22 a90122b
echo
echo "== retired phrasing =="
grep -n -i -E "adaptive|DifferentialEquations" "$DRAFT" || echo "no hit"
grep -n -i "hub rotor\|cyan\|bridle\|rigid driveshaft" "$DRAFT" || echo "no naming-trap hit"
echo
echo "== superseded forms =="
grep -n "63\.8695\|20\.1056\|14\.4651\|14\.46\|0\.101631" "$DRAFT" || echo "no hit"
echo
echo "== held tokens =="
grep -n "1\.94\|5\.18" "$DRAFT"
grep -n "3\.55" "$TRACK"
echo
echo "== display forms =="
echo "-- 15.0 sites:"
grep -nE "15\.0([^0-9]|$)" "$DRAFT"
echo "-- 14.972 in draft:"
grep -n "14\.972" "$DRAFT" || echo "none"
echo "-- 15.033 boundary:"
grep -n "15\.033" "$DRAFT"
echo "-- chain:"
grep -n "304\.6" "$DRAFT"
echo "-- retired chain operands:"
grep -n "20\.698468\|304\.58" "$DRAFT" || echo "none"
echo
echo "== arithmetic =="
python3 -c "v=1.5*20.698*9.81; print('rounded operands: {} -> 1dp {:.1f}'.format(v, v))"
python3 -c "print('full operands:', 1.5*20.69846825623688*9.81)"
echo
echo "== ancestry =="
for c in dd3cc6a a76c5e9 31ca00d eacf073 74cfef9 9cecee3 95c385d; do
  if git merge-base --is-ancestor "$c" HEAD; then echo "$c: ancestor OK"; else echo "$c: NOT ancestor"; fi
done
} > "$LOG"
echo "wrote $LOG"
