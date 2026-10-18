#!/usr/bin/env bash
# sweep 34 core run — science-writer, 2026-10-18.
# record only: not meant to be re-run. Span de18442..7e60f37.
# One draft mover (a9dc348, v0.65), one tracker mover, one ledger mover.
set -u
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
L=docs/reporting/value-claims-ledger.md
R=docs/reporting/numbers-register.md
S=docs/reporting/glossary-candidates.md
SP=docs/agents/stale-phrases.md
BASE=de18442
TIP=7e60f37

echo '== 1. preflight =='
git log --oneline -1
git status -sb | head -3
git rev-list --left-right --count origin/bank-derate-cos2p65...HEAD

echo '== 2. span enumeration =='
git log --oneline "$BASE".."$TIP" | cat
echo '-- draft movers'
git log --oneline "$BASE".."$TIP" -- "$D" | cat
echo '-- tracker movers'
git log --oneline "$BASE".."$TIP" -- "$T" | cat
echo '-- ledger movers'
git log --oneline "$BASE".."$TIP" -- "$L" | cat
echo '-- register movers (expect none)'
git log --oneline "$BASE".."$TIP" -- "$R" | cat
echo '-- candidates movers (expect none)'
git log --oneline "$BASE".."$TIP" -- "$S" | cat
echo '-- stale-phrases movers (expect none)'
git log --oneline "$BASE".."$TIP" -- "$SP" | cat
echo '-- register numstat (expect empty)'
git diff --numstat "$BASE".."$TIP" -- "$R" | cat

echo '== 3. extracts =='
git show "$BASE:$D" > scratch/sw_sweep34_draft_base.md
git show "$TIP:$D"  > scratch/sw_sweep34_draft_tip.md
git show "$BASE:$T" > scratch/sw_sweep34_tracker_base.md
git show "$TIP:$T"  > scratch/sw_sweep34_tracker_tip.md
git show "$BASE:$L" > scratch/sw_sweep34_ledger_base.md
git show "$TIP:$L"  > scratch/sw_sweep34_ledger_tip.md
git show "$BASE:$SP" > scratch/sw_sweep34_sp_base.md
git show "$TIP:$SP"  > scratch/sw_sweep34_sp_tip.md
head -3 scratch/sw_sweep34_draft_base.md
head -3 scratch/sw_sweep34_draft_tip.md

echo '== 4. token tools =='
SK=$HOME/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
python3 "$SK/scripts/draft-token-diff.py" . "$D" "$BASE" "$TIP"
python3 "$SK/scripts/draft-token-diff.py" . "$T" "$BASE" "$TIP"
python3 "$SK/scripts/draft-token-diff.py" . "$L" "$BASE" "$TIP"
python3 "$SK/scripts/token-attrib.py" . "$D" "$BASE" "$TIP" > scratch/sw_sweep34_attrib_draft.txt
python3 "$SK/scripts/token-attrib.py" . "$T" "$BASE" "$TIP" > scratch/sw_sweep34_attrib_tracker.txt
python3 "$SK/scripts/token-attrib.py" . "$L" "$BASE" "$TIP" > scratch/sw_sweep34_attrib_ledger.txt

echo '== 5. STE gates =='
for f in scratch/sw_sweep34_draft_base.md scratch/sw_sweep34_draft_tip.md \
         scratch/sw_sweep34_tracker_base.md scratch/sw_sweep34_tracker_tip.md \
         scratch/sw_sweep34_ledger_base.md scratch/sw_sweep34_ledger_tip.md; do
  python3 ste-lint.py --fail-above 2.0 "$f" || true
done

echo '== 6. offender sets =='
for f in base tip; do
  python3 "$SK/scripts/lint-offenders.py" ste-lint.py "scratch/sw_sweep34_draft_$f.md" > "scratch/sw_sweep34_draft_${f}_off.txt" || true
  python3 "$SK/scripts/lint-offenders.py" ste-lint.py "scratch/sw_sweep34_tracker_$f.md" > "scratch/sw_sweep34_tracker_${f}_off.txt" || true
  python3 "$SK/scripts/lint-offenders.py" ste-lint.py "scratch/sw_sweep34_ledger_$f.md" > "scratch/sw_sweep34_ledger_${f}_off.txt" || true
done
diff scratch/sw_sweep34_draft_base_off.txt scratch/sw_sweep34_draft_tip_off.txt > scratch/sw_sweep34_offdiffs_draft.txt || true
diff scratch/sw_sweep34_tracker_base_off.txt scratch/sw_sweep34_tracker_tip_off.txt > scratch/sw_sweep34_offdiffs_tracker.txt || true
diff scratch/sw_sweep34_ledger_base_off.txt scratch/sw_sweep34_ledger_tip_off.txt > scratch/sw_sweep34_offdiffs_ledger.txt || true
echo 'offdiffs:'; cat scratch/sw_sweep34_offdiffs_draft.txt scratch/sw_sweep34_offdiffs_tracker.txt scratch/sw_sweep34_offdiffs_ledger.txt

echo '== 7. greps and censuses =='
echo '-- seat checks, draft tip (expect zero)'
grep -n "seat checks" scratch/sw_sweep34_draft_tip.md || echo ZERO
echo '-- seat checks, ledger tip (expect zero)'
grep -n "seat checks" scratch/sw_sweep34_ledger_tip.md || echo ZERO
echo '-- the pipeline, draft tip'
grep -n "the pipeline" scratch/sw_sweep34_draft_tip.md || echo ZERO
echo '-- the pipeline, ledger tip'
grep -n "the pipeline" scratch/sw_sweep34_ledger_tip.md || echo ZERO
echo '-- adaptive / DifferentialEquations, draft tip'
grep -n "adaptive\|DifferentialEquations" scratch/sw_sweep34_draft_tip.md || echo ZERO

echo '== 8. freeze check (re-frozen block, new md5) =='
python3 - <<'EOF'
import pathlib, hashlib
md5 = lambda t: hashlib.md5(t.encode()).hexdigest()
block = pathlib.Path('scratch/sw_levers_reading_block.md').read_text()
draft = pathlib.Path('scratch/sw_sweep34_draft_tip.md').read_text()
s = 'The two plates map the same search in two views.'
e = 'The gene-level effects wait on the landscape extracts.'
region = draft[draft.index(s):draft.index(e) + len(e)]
print('block md5 (as written):', md5(block))
print('declared (re-freeze):   0d9001e4c19c78cc239cc22f8ac6dba7')
print('draft region == block (strip basis):', region == block.strip('\n'))
EOF

echo '== 9. review copy =='
md5sum scratch/report-pdf-build/draft-live.docx 2>/dev/null || echo 'no copy file'

echo '== 10. cited-commit ancestry =='
for c in $(grep -oE '[0-9a-f]{7,40}' scratch/sw_sweep34_draft_tip.md | sort -u); do
  git merge-base --is-ancestor "$c" HEAD 2>/dev/null && echo "$c OK" || echo "$c FAIL"
done | sort | uniq -c | sort -rn | head -20

echo '== done =='
