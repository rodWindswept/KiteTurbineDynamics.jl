#!/usr/bin/env bash
# Sweep 28 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: e8159b0 (sweep 27 section span end) -> 467ffc1, one draft mover:
#   38c77f8 (v0.42, the gate-margin column fold, author seat).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep28_core.log. Record only: not meant to be re-run.
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
echo '-- all commits, e8159b0..HEAD'
git log --oneline e8159b0..HEAD | cat
echo '-- count'
git rev-list --count e8159b0..HEAD
echo '-- draft movers'
git log --oneline e8159b0..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline e8159b0..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline e8159b0..HEAD -- "$G" | cat
echo '-- register movers, a7d09eb..HEAD'
git log --oneline a7d09eb..HEAD -- "$R" | cat
echo '-- numstat, register a7d09eb..HEAD (append-only check)'
git diff --numstat a7d09eb..HEAD -- "$R"
echo '-- numstat, gated files, e8159b0..HEAD'
git diff --numstat e8159b0..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker 38c77f8 vs HEAD'
git diff --stat 38c77f8..HEAD -- "$D" "$T"
echo '-- zero-diff readback: register 2510886 vs HEAD'
git diff --stat 2510886..HEAD -- "$R"
echo '-- zero-diff readback: build inputs 38c77f8 vs HEAD (draft, register, figures, scripts, checker)'
git diff --stat 38c77f8..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- zero-diff readback: all files 467ffc1 vs HEAD'
git diff --name-only 467ffc1..HEAD | cat
echo '-- ancestry of movers'
for c in 38c77f8 e8159b0 2510886 467ffc1 0f46aa7; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show e8159b0:"$D" > scratch/sw_sweep28_draft_v041.md
git show 38c77f8:"$D" > scratch/sw_sweep28_draft_v042.md
git show e8159b0:"$T" > scratch/sw_sweep28_tracker_v041.md
git show 38c77f8:"$T" > scratch/sw_sweep28_tracker_v042.md
wc -l scratch/sw_sweep28_draft_v04*.md scratch/sw_sweep28_tracker_v04*.md

echo '== 2b. full draft diff, e8159b0 -> 38c77f8 =='
git diff e8159b0 38c77f8 -- "$D" > scratch/sw_sweep28_draft_diff.txt
wc -l scratch/sw_sweep28_draft_diff.txt
echo '-- added non-blank lines (three-stage form)'
git diff e8159b0 38c77f8 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
echo '-- tracker diff'
git diff e8159b0 38c77f8 -- "$T" > scratch/sw_sweep28_tracker_diff.txt
wc -l scratch/sw_sweep28_tracker_diff.txt

echo '== 2c. sections 4-5 region byte check =='
python3 - <<'EOF'
a = open('scratch/sw_sweep28_draft_v041.md').read()
b = open('scratch/sw_sweep28_draft_v042.md').read()
s, e = '## 4 Discussion', '## 6 Nomenclature'
ra, rb = a[a.index(s):a.index(e)], b[b.index(s):b.index(e)]
print('sections 4-5 region byte-equal:', ra == rb)
EOF

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" e8159b0 38c77f8 | tee scratch/sw_sweep28_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" e8159b0 38c77f8 | tee scratch/sw_sweep28_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" e8159b0 38c77f8 | tee scratch/sw_sweep28_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" e8159b0 38c77f8 | tee scratch/sw_sweep28_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" e8159b0 38c77f8 | tee scratch/sw_sweep28_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep28_draft_v041 sw_sweep28_draft_v042 sw_sweep28_tracker_v041 sw_sweep28_tracker_v042; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v042) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- stale-phrases sample'
grep -n "1861\|zeta = 1.5\|cold-start stall\|Settle/ODE mismatch" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- superseded values and internal forms (expect zero)'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
grep -n -- "+12.472\|+498.9\|5\.99" scratch/sw_sweep28_draft_v042.md || echo 'no internal form hit'
echo '-- display guard: rounded 27.363 standalone (expect none)'
grep -nE "27\.363([^0-9]|$)" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep28_draft_v042.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep28_draft_v042.md || echo 'breaks-only: no hit'
echo '-- safety set and detector forms'
grep -n 'armed across\|limits break detection\|never allows breaks\|always rejects the design\|broken rope' scratch/sw_sweep28_draft_v042.md
echo '-- the margin rows'
grep -n "| Power floor |\|pass, P_end 5.314 kW\|15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times\|pass, 5.468 m, margin +3.968 m\|+264.5 per cent, 3.65 times\|+64.913 deg / +65.7 per cent, 2.91 times\|least margin 2.03 at S1\|+102.9 per cent above unity\|the warm path rejects healthy winners" scratch/sw_sweep28_draft_v042.md
echo '-- FoS outcome cell'
grep -n "pass, 15.0 minimum" scratch/sw_sweep28_draft_v042.md
echo '-- glossary term sites'
grep -n -i "torsional capacity" scratch/sw_sweep28_draft_v042.md
grep -n "torsional capacity" docs/reporting/glossary-candidates.md
echo '-- shape lines present (held)'
grep -n 'gust cases\|one island of the campaign\|longer or broader\|do not prove an optimal gene set' scratch/sw_sweep28_draft_v042.md
echo '-- classified counts line'
grep -n 'Of the 930, 508 designs pass every gate' scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- seated markers count'
grep -c 'Figure seated:' scratch/sw_sweep28_draft_v042.md
echo '-- number-gate brackets'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep28_draft_v042.md
echo '-- held tokens 1.94 / 5.18 sites'
grep -n "1\.94\|5\.18" scratch/sw_sweep28_draft_v042.md
echo '-- held token 3.55 in tracker'
grep -n "3\.55" scratch/sw_sweep28_tracker_v042.md || echo 'no hit'
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- rename census: old form'
grep -n -i "gate penalt" scratch/sw_sweep28_draft_v042.md scratch/sw_sweep28_tracker_v042.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep28_draft_v042.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep28_draft_v042.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep28_draft_v042.md
echo '-- figure-map delta v33 line'
grep -n "v33 (2026-10-14)" docs/reporting/figures/figure-map.md | head -2
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226 adea1a3 c438398; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v042'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep28_draft_v042.md | sort -u -t: -k2 > scratch/sw_sweep28_hexrefs.txt
wc -l scratch/sw_sweep28_hexrefs.txt

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep28_draft_v042.md \
  "pass, P_end 5.314 kW" "margin +0.314 kW" "+6.28 per cent" \
  "15.0 on 2.5" "margin +12.5" "+500.0 per cent" "6.00 times" \
  "pass, 5.468 m, margin +3.968 m" "+264.5 per cent, 3.65 times" \
  "+64.913 deg / +65.7 per cent, 2.91 times" "least margin 2.03 at S1" \
  "+102.9 per cent above unity" "the warm path rejects healthy winners" \
  "Torsional capacity" "torsional capacity" "It never allows breaks"

echo '== 5c. arithmetic spot checks =='
python3 - <<'EOF'
print('power: 5.314-5.0 =', round(5.314-5.0,3), '; pct =', round((5.314-5.0)/5.0*100,2))
print('clearance: 5.468-1.5 =', round(5.468-1.5,3), '; pct =', round((5.468-1.5)/1.5*100,1), '; times =', round(5.468/1.5,2))
print('fos: 15.0-2.5 =', round(15.0-2.5,1), '; pct =', round((15.0-2.5)/2.5*100,1), '; times =', round(15.0/2.5,2))
d1, dc = 33.94561934829036, 98.85908296054023
print('twist: margin =', round(dc-d1,3), '; pct =', round((dc-d1)/dc*100,1), '; times =', round(dc/d1,2))
EOF

echo '== 6. register anchors =='
for r in 008 009 013 015 022 040 042 046; do echo "-- NR-$r"; grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-240; done
echo '-- the display-form note block'
grep -n "Display-form note: the gate-margin" docs/reporting/numbers-register.md | head -2

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-38c77f8-20261014-184207.docx
head -14 scratch/report-pdf-build/build-record-docx.txt
ls -la scratch/report-pdf-build/ | grep -i lock

echo '== 8. plate pins (hero set, sha256) =='
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.png
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.svg
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.pdf
sha256sum docs/reporting/figures/machine-winner-hero/checks.log

echo '== done =='
