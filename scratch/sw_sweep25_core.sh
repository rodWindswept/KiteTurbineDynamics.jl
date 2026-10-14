#!/usr/bin/env bash
# Sweep 25 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: 5821a8f (sweep 24 section span end) -> 7d46148, one draft mover:
#   12a5753 (v0.39, the k = 2.24 story fold).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep25_core.log. Record only: not meant to be re-run.
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
G=docs/reporting/glossary-candidates.md
R=docs/reporting/numbers-register.md

echo '== 0. preflight =='
git rev-parse --short HEAD
echo '-- working tree status, gated files (empty means clean)'
git status --short -- "$D" "$T" "$G" "$R"
echo '-- tip readback'
git log --oneline -1 | cat
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
echo '-- all commits, 5821a8f..HEAD'
git log --oneline 5821a8f..HEAD | cat
echo '-- draft movers'
git log --oneline 5821a8f..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline 5821a8f..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline 5821a8f..HEAD -- "$G" | cat
echo '-- register movers, 9d96a4b..HEAD'
git log --oneline 9d96a4b..HEAD -- "$R" | cat
echo '-- numstat, register 9d96a4b..HEAD (append-only check)'
git diff --numstat 9d96a4b..HEAD -- "$R"
echo '-- numstat, gated files, 5821a8f..HEAD'
git diff --numstat 5821a8f..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/candidates 12a5753 vs HEAD'
git diff --stat 12a5753..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register d2bf63d vs HEAD'
git diff --stat d2bf63d..HEAD -- "$R"
echo '-- zero-diff readback: build inputs 12a5753 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat 12a5753..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- ancestry of movers'
for c in 12a5753 d2bf63d; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show 5821a8f:"$D" > scratch/sw_sweep25_draft_v038.md
git show 12a5753:"$D" > scratch/sw_sweep25_draft_v039.md
git show 5821a8f:"$T" > scratch/sw_sweep25_tracker_v038.md
git show 12a5753:"$T" > scratch/sw_sweep25_tracker_v039.md
wc -l scratch/sw_sweep25_draft_v03*.md scratch/sw_sweep25_tracker_v03*.md

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 5821a8f 12a5753 | tee scratch/sw_sweep25_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 5821a8f 12a5753 | tee scratch/sw_sweep25_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 5821a8f 12a5753 | tee scratch/sw_sweep25_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 5821a8f 12a5753 | tee scratch/sw_sweep25_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 5821a8f 12a5753 | tee scratch/sw_sweep25_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep25_draft_v038 sw_sweep25_draft_v039 sw_sweep25_tracker_v038 sw_sweep25_tracker_v039; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v039) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep25_draft_v039.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep25_draft_v039.md || echo 'breaks-only: no hit'
echo '-- k-story rows and cites'
grep -n "NR-047\|NR-048" scratch/sw_sweep25_draft_v039.md
echo '-- the old k-faults bracket and its values'
grep -n "holds a register row\|other values need rows" scratch/sw_sweep25_draft_v039.md || echo 'bracket: no hit'
grep -n "1\.94\|5\.18" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
grep -n "3\.55\|5\.39" scratch/sw_sweep25_draft_v039.md scratch/sw_sweep25_tracker_v039.md || echo 'no hit'
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
echo '-- rename census: old form'
grep -n -i "gate penalt" scratch/sw_sweep25_draft_v039.md scratch/sw_sweep25_tracker_v039.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep25_draft_v039.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep25_draft_v039.md
echo '-- held tokens'
grep -n "3\.55" scratch/sw_sweep25_tracker_v039.md || echo 'no hit'
echo '-- Daisy sites'
grep -n "Daisy" scratch/sw_sweep25_draft_v039.md
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226 adea1a3; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v039'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep25_draft_v039.md | sort -u -t: -k2 > scratch/sw_sweep25_hexrefs.txt
wc -l scratch/sw_sweep25_hexrefs.txt
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep25_draft_v039.md || echo 'no hit'
echo '-- repo census: old rename form'
grep -rn -i "gate penalt" docs/reporting/ | head -12 || echo 'no hit'

echo '== 6. register anchors =='
for r in 001 002 009 015 025 039 046 047 048; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -4; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-12a5753-20261014-155048.docx
head -14 scratch/report-pdf-build/build-record-docx.txt

echo '== 8. plate pins =='
sha256sum docs/reporting/figures/ring-utilisation/ring-utilisation.png
sha256sum docs/reporting/figures/twist-limit/twist-limit.png

echo '== done =='
