#!/usr/bin/env bash
# Sweep 24 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: 68092dc (sweep 23 section span end) -> 5821a8f, one draft mover:
#   ed3d202 (v0.38, the safety-shorthand pass).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep24_core.log. Record only: not meant to be re-run.
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
echo '-- all commits, 68092dc..HEAD'
git log --oneline 68092dc..HEAD | cat
echo '-- draft movers'
git log --oneline 68092dc..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline 68092dc..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline 68092dc..HEAD -- "$G" | cat
echo '-- register movers, 9d96a4b..HEAD'
git log --oneline 9d96a4b..HEAD -- "$R" | cat
echo '-- numstat, register 9d96a4b..HEAD (append-only check; empty = no movement)'
git diff --numstat 9d96a4b..HEAD -- "$R"
echo '-- numstat, gated files, 68092dc..HEAD'
git diff --numstat 68092dc..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/candidates ed3d202 vs HEAD'
git diff --stat ed3d202..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register 9d96a4b vs HEAD'
git diff --stat 9d96a4b..HEAD -- "$R"
echo '-- zero-diff readback: build inputs ed3d202 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat ed3d202..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- ancestry of mover'
git merge-base --is-ancestor ed3d202 HEAD && echo "ed3d202 OK" || echo "ed3d202 FAIL"

echo '== 2. extracts =='
git show 68092dc:"$D" > scratch/sw_sweep24_draft_v037.md
git show ed3d202:"$D" > scratch/sw_sweep24_draft_v038.md
git show 68092dc:"$T" > scratch/sw_sweep24_tracker_v037.md
git show ed3d202:"$T" > scratch/sw_sweep24_tracker_v038.md
wc -l scratch/sw_sweep24_draft_v03*.md scratch/sw_sweep24_tracker_v03*.md

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 68092dc ed3d202 | tee scratch/sw_sweep24_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 68092dc ed3d202 | tee scratch/sw_sweep24_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 68092dc ed3d202 | tee scratch/sw_sweep24_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 68092dc ed3d202 | tee scratch/sw_sweep24_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 68092dc ed3d202 | tee scratch/sw_sweep24_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep24_draft_v037 sw_sweep24_draft_v038 sw_sweep24_tracker_v037 sw_sweep24_tracker_v038; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v038) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep24_draft_v038.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep24_draft_v038.md || echo 'breaks-only: no hit'
echo '-- safety set and detector form (expect hits)'
grep -n "arms the\|rope-break check\|judges only real operation\|never allows\|always rejects" scratch/sw_sweep24_draft_v038.md
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
echo '-- rename census: old form (expect none across draft/tracker/candidates)'
grep -n -i "gate penalt" scratch/sw_sweep24_draft_v038.md scratch/sw_sweep24_tracker_v038.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep24_draft_v038.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep24_draft_v038.md
echo '-- held tokens'
grep -n "1\.94\|5\.18" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
grep -n "3\.55" scratch/sw_sweep24_tracker_v038.md || echo 'no hit'
echo '-- Daisy sites'
grep -n "Daisy" scratch/sw_sweep24_draft_v038.md
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v038'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep24_draft_v038.md | sort -u -t: -k2 > scratch/sw_sweep24_hexrefs.txt
wc -l scratch/sw_sweep24_hexrefs.txt
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep24_draft_v038.md || echo 'no hit'
echo '-- repo census: old rename form'
grep -rn -i "gate penalt" docs/reporting/ | head -12 || echo 'no hit'

echo '== 6. register anchors =='
for r in 001 002 009 015 025 039 046; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -4; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-ed3d202-20261014-145837.docx
head -14 scratch/report-pdf-build/build-record-docx.txt

echo '== 8. plate pins =='
sha256sum docs/reporting/figures/ring-utilisation/ring-utilisation.png
sha256sum docs/reporting/figures/twist-limit/twist-limit.png

echo '== done =='
