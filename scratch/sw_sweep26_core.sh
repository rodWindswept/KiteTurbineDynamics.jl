#!/usr/bin/env bash
# Sweep 26 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: 7d46148 (sweep 25 section span end) -> ad56692, one draft mover:
#   0e7d396 (v0.40, the decision shape, PL13).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep26_core.log. Record only: not meant to be re-run.
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
G=docs/reporting/glossary-candidates.md
R=docs/reporting/numbers-register.md
C=docs/reporting/2026-10-08-room-consultation.md

echo '== 0. preflight =='
git rev-parse --short HEAD
echo '-- working tree status, gated files (empty means clean)'
git status --short -- "$D" "$T" "$G" "$R"
echo '-- tip readback'
git log --oneline -1 | cat
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
echo '-- all commits, 7d46148..HEAD'
git log --oneline 7d46148..HEAD | cat
echo '-- draft movers'
git log --oneline 7d46148..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline 7d46148..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline 7d46148..HEAD -- "$G" | cat
echo '-- register movers, d2bf63d..HEAD'
git log --oneline d2bf63d..HEAD -- "$R" | cat
echo '-- numstat, register d2bf63d..HEAD (append-only check)'
git diff --numstat d2bf63d..HEAD -- "$R"
git diff d2bf63d..HEAD -- "$R" > scratch/sw_sweep26_reg_append.txt
wc -l scratch/sw_sweep26_reg_append.txt
echo '-- numstat, consultation and .ste-exempt, 7d46148..HEAD'
git diff --numstat 7d46148..HEAD -- "$C" .ste-exempt
echo '-- numstat, gated files, 7d46148..HEAD'
git diff --numstat 7d46148..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/candidates 0e7d396 vs HEAD'
git diff --stat 0e7d396..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register a7d09eb vs HEAD'
git diff --stat a7d09eb..HEAD -- "$R"
echo '-- zero-diff readback: build inputs 0e7d396 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat 0e7d396..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- zero-diff readback: all files 0e7d396 vs HEAD'
git diff --name-only 0e7d396..HEAD | cat
echo '-- ancestry of movers'
for c in 0e7d396 a7d09eb; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show 12a5753:"$D" > scratch/sw_sweep26_draft_v039.md
git show 0e7d396:"$D" > scratch/sw_sweep26_draft_v040.md
git show 12a5753:"$T" > scratch/sw_sweep26_tracker_v039.md
git show 0e7d396:"$T" > scratch/sw_sweep26_tracker_v040.md
wc -l scratch/sw_sweep26_draft_v04*.md scratch/sw_sweep26_tracker_v04*.md

echo '== 2b. full draft diff, 12a5753 -> 0e7d396 =='
git diff 12a5753 0e7d396 -- "$D" > scratch/sw_sweep26_draft_diff.txt
wc -l scratch/sw_sweep26_draft_diff.txt

echo '== 2c. sections 4-5 region byte check =='
python3 - <<'EOF'
a = open('scratch/sw_sweep26_draft_v039.md').read()
b = open('scratch/sw_sweep26_draft_v040.md').read()
s, e = '## 4 Discussion', '## 6 Nomenclature'
ra, rb = a[a.index(s):a.index(e)], b[b.index(s):b.index(e)]
print('sections 4-5 region byte-equal:', ra == rb)
EOF

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 12a5753 0e7d396 | tee scratch/sw_sweep26_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 12a5753 0e7d396 | tee scratch/sw_sweep26_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 12a5753 0e7d396 | tee scratch/sw_sweep26_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 12a5753 0e7d396 | tee scratch/sw_sweep26_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 12a5753 0e7d396 | tee scratch/sw_sweep26_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep26_draft_v039 sw_sweep26_draft_v040 sw_sweep26_tracker_v039 sw_sweep26_tracker_v040; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v040) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- display guard: rounded 27.363 standalone (expect none)'
grep -nE "27\.363([^0-9]|$)" scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep26_draft_v040.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep26_draft_v040.md || echo 'breaks-only: no hit'
echo '-- safety set and detector forms'
grep -n 'armed across\|limits break detection\|never allows breaks\|always rejects the design\|broken rope' scratch/sw_sweep26_draft_v040.md
echo '-- safety veto forms (old) expect none'
grep -n 'enables rope\|enabled across' scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- detector and safety forms, wrap-tolerant flat check'
python3 - <<'EOF'
import re
t = open('scratch/sw_sweep26_draft_v040.md').read()
flat = re.sub(r'\s+', ' ', t)
for s in ['The evaluator arms the rope-break check across the relax and the window',
          'The ruling limits break detection to the measurement window',
          'The evaluator runs the rope-break gate across the relax run as well as the window',
          'It never allows breaks',
          'always rejects the design',
          'No design passes with a broken rope at its operating point']:
    print('  %dx %s' % (flat.count(s), s))
EOF
echo '-- k-story rows and cites'
grep -n "NR-047\|NR-048" scratch/sw_sweep26_draft_v040.md
echo '-- the number-gate brackets'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep26_draft_v040.md
echo '-- held tokens 1.94 / 5.18 sites'
grep -n "1\.94\|5\.18" scratch/sw_sweep26_draft_v040.md
echo '-- held token 3.55 in tracker'
grep -n "3\.55" scratch/sw_sweep26_tracker_v040.md || echo 'no hit'
echo '-- shape lines present (v0.40 additions)'
grep -n 'gust cases\|one island of the campaign\|longer or broader\|do not prove an optimal gene set' scratch/sw_sweep26_draft_v040.md
echo '-- classified counts line'
grep -n 'Of the 930, 508 designs pass every gate' scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- seated markers count'
grep -c 'Figure seated:' scratch/sw_sweep26_draft_v040.md
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- rename census: old form'
grep -n -i "gate penalt" scratch/sw_sweep26_draft_v040.md scratch/sw_sweep26_tracker_v040.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep26_draft_v040.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep26_draft_v040.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep26_draft_v040.md
echo '-- Daisy sites'
grep -n "Daisy" scratch/sw_sweep26_draft_v040.md
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226 adea1a3; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v040'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep26_draft_v040.md | sort -u -t: -k2 > scratch/sw_sweep26_hexrefs.txt
wc -l scratch/sw_sweep26_hexrefs.txt
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep26_draft_v040.md || echo 'no hit'

echo '== 6. register anchors =='
for r in 001 002 009 015 025 039 046 047 048; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -3; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-0e7d396-20261014-164352.docx
head -14 scratch/report-pdf-build/build-record-docx.txt

echo '== 8. plate pins =='
sha256sum docs/reporting/figures/ring-utilisation/ring-utilisation.png
sha256sum docs/reporting/figures/twist-limit/twist-limit.png

echo '== done =='
