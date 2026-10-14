#!/usr/bin/env bash
# Sweep 23 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: a3ca2f6 (sweep 22 tip) -> 68092dc, one draft mover:
#   7dd91a9 (v0.37, the consistency sweep, PL9).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep23_core.log. Record only: not meant to be re-run.
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
echo '-- all commits, a3ca2f6..HEAD'
git log --oneline a3ca2f6..HEAD | cat
echo '-- draft movers'
git log --oneline a3ca2f6..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline a3ca2f6..HEAD -- "$T" | cat
echo '-- glossary movers (both files)'
git log --oneline a3ca2f6..HEAD -- "$G" docs/reporting/glossary.md | cat
echo '-- register movers, 4a86e6f..HEAD'
git log --oneline 4a86e6f..HEAD -- "$R" | cat
echo '-- numstat, register 4a86e6f..HEAD (append-only check)'
git diff --numstat 4a86e6f..HEAD -- "$R"
echo '-- numstat, gated files, a3ca2f6..HEAD'
git diff --numstat a3ca2f6..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/candidates 7dd91a9 vs HEAD'
git diff --stat 7dd91a9..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register 9d96a4b vs HEAD'
git diff --stat 9d96a4b..HEAD -- "$R"
echo '-- zero-diff readback: build inputs 7dd91a9 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat 7dd91a9..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- ancestry of movers'
for c in 7dd91a9 9d96a4b; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show a3ca2f6:"$D" > scratch/sw_sweep23_draft_v036.md
git show 7dd91a9:"$D" > scratch/sw_sweep23_draft_v037.md
git show a3ca2f6:"$T" > scratch/sw_sweep23_tracker_v036.md
git show 7dd91a9:"$T" > scratch/sw_sweep23_tracker_v037.md
wc -l scratch/sw_sweep23_draft_v0*.md scratch/sw_sweep23_tracker_v0*.md

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" a3ca2f6 7dd91a9 | tee scratch/sw_sweep23_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" a3ca2f6 7dd91a9 | tee scratch/sw_sweep23_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" a3ca2f6 7dd91a9 | tee scratch/sw_sweep23_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" a3ca2f6 7dd91a9 | tee scratch/sw_sweep23_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" a3ca2f6 7dd91a9 | tee scratch/sw_sweep23_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep23_draft_v036 sw_sweep23_draft_v037 sw_sweep23_tracker_v036 sw_sweep23_tracker_v037; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v037) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
echo '-- rename census: old form (expect none across draft/tracker/candidates)'
grep -n -i "gate penalt" scratch/sw_sweep23_draft_v037.md scratch/sw_sweep23_tracker_v037.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep23_draft_v037.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- kg-equivalent count'
grep -c "kg-equivalent" scratch/sw_sweep23_draft_v037.md
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep23_draft_v037.md
echo '-- held tokens'
grep -n "1\.94\|5\.18" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
grep -n "3\.55" scratch/sw_sweep23_tracker_v037.md || echo 'no hit'
echo '-- Daisy sites'
grep -n "Daisy" scratch/sw_sweep23_draft_v037.md
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v037'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep23_draft_v037.md | sort -u -t: -k2 > scratch/sw_sweep23_hexrefs.txt
wc -l scratch/sw_sweep23_hexrefs.txt
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep23_draft_v037.md || echo 'no hit'
echo '-- repo census: old rename form (records may quote it; the gate is draft + glossary)'
grep -rn -i "gate penalt" docs/reporting/ || echo 'no hit'

echo '== 6. register anchors =='
for r in 001 002 005 009 015 039 046; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -4; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-7dd91a9-20261014-141528.docx

echo '== 8. plate pins =='
sha256sum docs/reporting/figures/ring-utilisation/ring-utilisation.png
sha256sum docs/reporting/figures/twist-limit/twist-limit.png

echo '== done =='
