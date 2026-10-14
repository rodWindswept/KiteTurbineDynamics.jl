#!/usr/bin/env bash
# Sweep 27 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: ad56692 (sweep 26 section span end) -> e8159b0, one draft mover:
#   e8159b0 (v0.41, the machine winner hero fold, figures seat).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep27_core.log. Record only: not meant to be re-run.
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
echo '-- all commits, ad56692..HEAD'
git log --oneline ad56692..HEAD | cat
echo '-- count'
git rev-list --count ad56692..HEAD
echo '-- draft movers'
git log --oneline ad56692..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline ad56692..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline ad56692..HEAD -- "$G" | cat
echo '-- register movers, a7d09eb..HEAD'
git log --oneline a7d09eb..HEAD -- "$R" | cat
echo '-- numstat, register a7d09eb..HEAD (no-movement check)'
git diff --numstat a7d09eb..HEAD -- "$R"
echo '-- numstat, gated files, ad56692..HEAD'
git diff --numstat ad56692..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/candidates e8159b0 vs HEAD'
git diff --stat e8159b0..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register a7d09eb vs HEAD'
git diff --stat a7d09eb..HEAD -- "$R"
echo '-- zero-diff readback: build inputs e8159b0 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat e8159b0..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- zero-diff readback: all files e8159b0 vs HEAD'
git diff --name-only e8159b0..HEAD | cat
echo '-- ancestry of movers'
for c in e8159b0 0e7d396 a7d09eb c438398 599d0fb; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show 0e7d396:"$D" > scratch/sw_sweep27_draft_v040.md
git show e8159b0:"$D" > scratch/sw_sweep27_draft_v041.md
git show 0e7d396:"$T" > scratch/sw_sweep27_tracker_v040.md
git show e8159b0:"$T" > scratch/sw_sweep27_tracker_v041.md
wc -l scratch/sw_sweep27_draft_v04*.md scratch/sw_sweep27_tracker_v04*.md

echo '== 2b. full draft diff, 0e7d396 -> e8159b0 =='
git diff 0e7d396 e8159b0 -- "$D" > scratch/sw_sweep27_draft_diff.txt
wc -l scratch/sw_sweep27_draft_diff.txt
echo '-- added non-blank lines (three-stage form)'
git diff 0e7d396 e8159b0 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
echo '-- tracker diff'
git diff 0e7d396 e8159b0 -- "$T" > scratch/sw_sweep27_tracker_diff.txt
wc -l scratch/sw_sweep27_tracker_diff.txt

echo '== 2c. sections 4-5 region byte check =='
python3 - <<'EOF'
a = open('scratch/sw_sweep27_draft_v040.md').read()
b = open('scratch/sw_sweep27_draft_v041.md').read()
s, e = '## 4 Discussion', '## 6 Nomenclature'
ra, rb = a[a.index(s):a.index(e)], b[b.index(s):b.index(e)]
print('sections 4-5 region byte-equal:', ra == rb)
EOF

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 0e7d396 e8159b0 | tee scratch/sw_sweep27_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 0e7d396 e8159b0 | tee scratch/sw_sweep27_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 0e7d396 e8159b0 | tee scratch/sw_sweep27_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 0e7d396 e8159b0 | tee scratch/sw_sweep27_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 0e7d396 e8159b0 | tee scratch/sw_sweep27_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep27_draft_v040 sw_sweep27_draft_v041 sw_sweep27_tracker_v040 sw_sweep27_tracker_v041; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v041) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- stale-phrases sample'
grep -n "1861\|zeta = 1.5\|cold-start stall\|Settle/ODE mismatch" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- display guard: rounded 27.363 standalone (expect none)'
grep -nE "27\.363([^0-9]|$)" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep27_draft_v041.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep27_draft_v041.md || echo 'breaks-only: no hit'
echo '-- safety set and detector forms'
grep -n 'armed across\|limits break detection\|never allows breaks\|always rejects the design\|broken rope' scratch/sw_sweep27_draft_v041.md
echo '-- safety veto forms (old) expect none'
grep -n 'enables rope\|enabled across' scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- hero forms (v0.41 additions)'
grep -n 'machine winner hero\|machine-winner-hero\|Figure seated' scratch/sw_sweep27_draft_v041.md
echo '-- appendix count line'
grep -n 'All seven read dataset commit' scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- the number-gate brackets'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep27_draft_v041.md
echo '-- held tokens 1.94 / 5.18 sites'
grep -n "1\.94\|5\.18" scratch/sw_sweep27_draft_v041.md
echo '-- held token 3.55 in tracker'
grep -n "3\.55" scratch/sw_sweep27_tracker_v041.md || echo 'no hit'
echo '-- shape lines present (v0.40 additions, held)'
grep -n 'gust cases\|one island of the campaign\|longer or broader\|do not prove an optimal gene set' scratch/sw_sweep27_draft_v041.md
echo '-- classified counts line'
grep -n 'Of the 930, 508 designs pass every gate' scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- seated markers count'
grep -c 'Figure seated:' scratch/sw_sweep27_draft_v041.md
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- rename census: old form'
grep -n -i "gate penalt" scratch/sw_sweep27_draft_v041.md scratch/sw_sweep27_tracker_v041.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep27_draft_v041.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep27_draft_v041.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep27_draft_v041.md
echo '-- figure-map delta v32 line'
grep -n "v32 (2026-10-14)" docs/reporting/figures/figure-map.md | head -2
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226 adea1a3 c438398; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v041'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep27_draft_v041.md | sort -u -t: -k2 > scratch/sw_sweep27_hexrefs.txt
wc -l scratch/sw_sweep27_hexrefs.txt

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep27_draft_v041.md \
  "machine winner hero" "Machine winner hero" "machine-winner-hero" \
  "Figure seated: figure-map row 10" "All seven read dataset commit" \
  "soft constraint penalties" "It never allows breaks" "always rejects the design" \
  "broken rope" "The evaluator arms the rope-break check" "limits break detection"

echo '== 6. register anchors =='
for r in 001 002 009 015 021 022 039 043 046 047 048; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md | head -2; done
echo '-- NR-043 signed check'
grep -n "| NR-043 " docs/reporting/numbers-register.md | head -2

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-e8159b0-20261014-180159.docx
head -14 scratch/report-pdf-build/build-record-docx.txt
ls -la scratch/report-pdf-build/ | grep -i lock

echo '== 8. plate pins (hero set, sha256) =='
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.png
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.svg
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.pdf
sha256sum docs/reporting/figures/machine-winner-hero/checks.log

echo '== done =='
