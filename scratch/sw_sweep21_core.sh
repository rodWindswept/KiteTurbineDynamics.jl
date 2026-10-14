#!/usr/bin/env bash
# Sweep 21 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: 76655cb (v0.31) -> dcf8213 (v0.33), two draft movers: 5a7a6b4 (v0.32), dcf8213 (v0.33).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep21_core.log. Record only: not meant to be re-run.
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
R=docs/reporting/numbers-register.md

echo '== 1. span enumeration =='
echo '-- draft movers'
git log --oneline 76655cb..HEAD -- $D
echo '-- tracker movers'
git log --oneline 76655cb..HEAD -- $T
echo '-- register movers since 6255268 (sweep 20 register base)'
git log --oneline 6255268..HEAD -- $R
echo '-- numstat, register/tracker/draft, 76655cb..HEAD'
git diff --numstat 76655cb..HEAD -- $R $T $D
echo '-- numstat, register/tracker/draft, 76655cb..dcf8213'
git diff --numstat 76655cb..dcf8213 -- $R $T $D
echo '-- zero-diff to tip: draft and tracker at dcf8213 vs HEAD'
git diff dcf8213..HEAD -- $D $T
echo '-- zero-diff: register 6255268 vs HEAD'
git diff 6255268..HEAD -- $R
echo '-- zero-diff readback complete'

echo '== 2. extracts =='
git show 76655cb:$D > scratch/sw_sweep21_draft_v031.md
git show 5a7a6b4:$D > scratch/sw_sweep21_draft_v032.md
git show dcf8213:$D > scratch/sw_sweep21_draft_v033.md
git show 76655cb:$T > scratch/sw_sweep21_tracker_v031.md
git show 5a7a6b4:$T > scratch/sw_sweep21_tracker_v032.md
git show dcf8213:$T > scratch/sw_sweep21_tracker_v033.md
wc -l scratch/sw_sweep21_draft_v0*.md scratch/sw_sweep21_tracker_v0*.md

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . $D 76655cb 5a7a6b4 dcf8213 | tee scratch/sw_sweep21_tokdiff_draft.txt
echo '== token attrib: draft =='
python3 $SK/scripts/token-attrib.py . $D 76655cb 5a7a6b4 dcf8213 | tee scratch/sw_sweep21_attrib_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . $T 76655cb 5a7a6b4 dcf8213 | tee scratch/sw_sweep21_tokdiff_tracker.txt
echo '== token attrib: tracker =='
python3 $SK/scripts/token-attrib.py . $T 76655cb 5a7a6b4 dcf8213 | tee scratch/sw_sweep21_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep21_draft_v031 sw_sweep21_draft_v032 sw_sweep21_draft_v033 sw_sweep21_tracker_v031 sw_sweep21_tracker_v032 sw_sweep21_tracker_v033; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps =='
echo '-- retired phrasing, v033'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep21_draft_v033.md || echo 'no hit'
echo '-- superseded values 3.816 / 14.972, v033'
grep -n "3\.816\|14\.972" scratch/sw_sweep21_draft_v033.md || echo 'no hit'
echo '-- near-hits driveshaft/bridle/cyan, v033'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep21_draft_v033.md || echo 'no hit'
echo '-- pending marker, v033'
grep -n "pending" scratch/sw_sweep21_draft_v033.md || echo 'no hit'
echo '-- pass notes, v033 head'
grep -n "pass by" scratch/sw_sweep21_draft_v033.md | head -8
echo '-- held tokens'
grep -n "1\.94\|5\.18\|3\.55" scratch/sw_sweep21_draft_v033.md scratch/sw_sweep21_tracker_v033.md || echo 'no hit'
echo '-- cited commits'
for c in dd3cc6a a76c5e9 31ca00d eacf073 74cfef9 9cecee3 95c385d; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v033'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep21_draft_v033.md | sort -u -t: -k2 | head -40

echo '== 6. register row anchors for the value cross-check =='
for r in 001 002 005 006 008 009 011 015 017 018 021 022 036 039 040 044 045; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -8; done

echo '== done =='
