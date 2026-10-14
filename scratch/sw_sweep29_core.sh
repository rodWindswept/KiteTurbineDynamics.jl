#!/usr/bin/env bash
# Sweep 29 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: d2744fe (sweep 28 section span end) -> 8a1e552, one draft mover:
#   e5541e9 (v0.43, the round-5 wording set, author seat), the tracker mover
#   rides the same commit, one register landing: 94aa219 (NR-049, NR-050).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep29_core.log. Record only: not meant to be re-run.
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
echo '-- all commits, d2744fe..HEAD'
git log --oneline d2744fe..HEAD | cat
echo '-- count'
git rev-list --count d2744fe..HEAD
echo '-- draft movers'
git log --oneline d2744fe..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline d2744fe..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline d2744fe..HEAD -- "$G" | cat
echo '-- register movers, 2510886..HEAD'
git log --oneline 2510886..HEAD -- "$R" | cat
echo '-- numstat, register 2510886..HEAD (append-only check)'
git diff --numstat 2510886..HEAD -- "$R"
echo '-- numstat, gated files, d2744fe..HEAD'
git diff --numstat d2744fe..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker e5541e9 vs HEAD'
git diff --stat e5541e9..HEAD -- "$D" "$T"
echo '-- zero-diff readback: register 94aa219 vs HEAD'
git diff --stat 94aa219..HEAD -- "$R"
echo '-- zero-diff readback: build inputs e5541e9 vs HEAD'
git diff --stat e5541e9..HEAD -- "$D" "$R" docs/reporting/figures scripts scratch/sv_check_draft_citations.py
echo '-- zero-diff readback: all files 8a1e552 vs HEAD'
git diff --name-only 8a1e552..HEAD | cat
echo '-- ancestry of movers'
for c in e5541e9 94aa219 12f4b59 c177213 d2a57aa d2744fe 8a1e552; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show 38c77f8:"$D" > scratch/sw_sweep29_draft_v042.md
git show e5541e9:"$D" > scratch/sw_sweep29_draft_v043.md
git show 38c77f8:"$T" > scratch/sw_sweep29_tracker_v042.md
git show e5541e9:"$T" > scratch/sw_sweep29_tracker_v043.md
wc -l scratch/sw_sweep29_draft_v04*.md scratch/sw_sweep29_tracker_v04*.md

echo '== 2b. full draft diff, 38c77f8 -> e5541e9 =='
git diff 38c77f8 e5541e9 -- "$D" > scratch/sw_sweep29_draft_diff.txt
wc -l scratch/sw_sweep29_draft_diff.txt
echo '-- added non-blank lines (three-stage form)'
git diff 38c77f8 e5541e9 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
echo '-- tracker diff'
git diff 38c77f8 e5541e9 -- "$T" > scratch/sw_sweep29_tracker_diff.txt
wc -l scratch/sw_sweep29_tracker_diff.txt

echo '== 2c. sections 4 to the end byte check =='
python3 - <<'EOF'
a = open('scratch/sw_sweep29_draft_v042.md').read()
b = open('scratch/sw_sweep29_draft_v043.md').read()
s = '## 4 Discussion'
print('sections 4 to end byte-equal:', a[a.index(s):] == b[b.index(s):])
EOF

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 38c77f8 e5541e9 | tee scratch/sw_sweep29_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 38c77f8 e5541e9 | tee scratch/sw_sweep29_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 38c77f8 e5541e9 | tee scratch/sw_sweep29_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 38c77f8 e5541e9 | tee scratch/sw_sweep29_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 38c77f8 e5541e9 | tee scratch/sw_sweep29_attrib_tracker.txt

echo '== 4. STE gates =='
for f in sw_sweep29_draft_v042 sw_sweep29_draft_v043 sw_sweep29_tracker_v042 sw_sweep29_tracker_v043; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '-- offdiffs'
diff scratch/sw_sweep29_draft_v042_off.txt scratch/sw_sweep29_draft_v043_off.txt > scratch/sw_sweep29_offdiffs.txt
diff scratch/sw_sweep29_tracker_v042_off.txt scratch/sw_sweep29_tracker_v043_off.txt >> scratch/sw_sweep29_offdiffs.txt
wc -l scratch/sw_sweep29_offdiffs.txt

echo '== 5. greps (v043) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- stale-phrases sample'
grep -n "1861\|zeta = 1.5\|cold-start stall\|Settle/ODE mismatch" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- superseded values and internal forms (expect zero)'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
grep -n -- "+12.472\|+498.9\|5\.99" scratch/sw_sweep29_draft_v043.md || echo 'no internal form hit'
echo '-- display guard: rounded 27.363 standalone (expect none)'
grep -nE "27\.363([^0-9]|$)" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- safety guards: enabl / breaks only (expect none)'
grep -n -i "enabl" scratch/sw_sweep29_draft_v043.md || echo 'enabl: no hit'
grep -n "breaks only" scratch/sw_sweep29_draft_v043.md || echo 'breaks-only: no hit'
echo '-- safety set and detector forms'
grep -n 'armed across\|limits break detection\|never allows breaks\|always rejects the design\|broken rope' scratch/sw_sweep29_draft_v043.md
echo '-- the margin rows (hold)'
grep -n "| Power floor |\|pass, P_end 5.314 kW\|15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times\|pass, 5.468 m, margin +3.968 m\|+264.5 per cent, 3.65 times\|+64.913 deg / +65.7 per cent, 2.91 times\|least margin 2.03 at S1\|+102.9 per cent above unity\|the warm path rejects healthy winners" scratch/sw_sweep29_draft_v043.md
echo '-- FoS outcome cell'
grep -n "pass, 15.0 minimum" scratch/sw_sweep29_draft_v043.md
echo '-- cone census: 22 degrees sites'
grep -n "22 degrees" scratch/sw_sweep29_draft_v043.md
echo '-- bare-22 context dump'
python3 - <<'EOF'
import re
t = open('scratch/sw_sweep29_draft_v043.md').read()
n = 0
for m in re.finditer(r'(?<![\d.])22(?![\d.])', t):
    n += 1
    a = max(0, m.start()-140); b = min(len(t), m.end()+140)
    print('--- occurrence', n)
    print(t[a:b].replace('\n', ' '))
print('bare-22 count:', n)
EOF
echo '-- Tulloch/Jensen guard (expect no hit)'
grep -n -i "tulloch\|jensen" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- slot names'
grep -n "blade_scale_top\|blade_scale_bottom\|bank_bottom" scratch/sw_sweep29_draft_v043.md
echo '-- cold-path line and the standing :cold sentence'
grep -n "scored every design on the cold path" scratch/sw_sweep29_draft_v043.md
grep -n "ODE path is :cold" scratch/sw_sweep29_draft_v043.md
echo '-- physics-validation era phrase: draft and candidates'
grep -n -i "physics-validation" scratch/sw_sweep29_draft_v043.md
grep -n -i "physics-validation" docs/reporting/glossary-candidates.md || echo 'candidates: no entry'
echo '-- shaft transition cone census'
grep -n "shaft transition cone\|shaft/TRPT" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- glossary term sites'
grep -n -i "torsional capacity" scratch/sw_sweep29_draft_v043.md
grep -n "torsional capacity" docs/reporting/glossary-candidates.md
echo '-- shape lines present (held)'
grep -n 'gust cases\|one island of the campaign\|longer or broader\|do not prove an optimal gene set' scratch/sw_sweep29_draft_v043.md
echo '-- classified counts line'
grep -n 'Of the 930, 508 designs pass every gate' scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- seated markers count'
grep -c 'Figure seated:' scratch/sw_sweep29_draft_v043.md
echo '-- number-gate brackets'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep29_draft_v043.md
echo '-- held tokens 1.94 / 5.18 sites'
grep -n "1\.94\|5\.18" scratch/sw_sweep29_draft_v043.md
echo '-- held token 3.55 in tracker'
grep -n "3\.55" scratch/sw_sweep29_tracker_v043.md || echo 'no hit'
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- rename census: old form'
grep -n -i "gate penalt" scratch/sw_sweep29_draft_v043.md scratch/sw_sweep29_tracker_v043.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep29_draft_v043.md docs/reporting/glossary-candidates.md || echo 'no hit'
echo '-- pending markers'
grep -n "PENDING" scratch/sw_sweep29_draft_v043.md || echo 'no hit'
echo '-- head block'
sed -n '1,16p' scratch/sw_sweep29_draft_v043.md
echo '-- figure-map delta v34 line'
grep -n "v34 (2026-10-14)" docs/reporting/figures/figure-map.md | head -2
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226 adea1a3 c438398; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v043'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep29_draft_v043.md | sort -u -t: -k2 > scratch/sw_sweep29_hexrefs.txt
wc -l scratch/sw_sweep29_hexrefs.txt
echo '-- hex ref diff vs v042 inventory (expect empty)'
sed 's/^[0-9]*://' scratch/sw_sweep29_hexrefs.txt | sort -u > scratch/sw_sweep29_hexrefs_norm.txt
sed 's/^[0-9]*://' scratch/sw_sweep28_hexrefs.txt | sort -u > scratch/sw_sweep29_hexrefs_v042_norm.txt
diff scratch/sw_sweep29_hexrefs_v042_norm.txt scratch/sw_sweep29_hexrefs_norm.txt || true

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep29_draft_v043.md \
  "The base span reads 0.75 of the rotor radius" \
  "the base chord reads 0.113 of it" \
  "The shaft transition cone holds one fixed angle, 22 degrees, by construction." \
  "in every machine of the campaign" \
  "It is not a search gene" \
  "A later campaign can vary it." \
  "The campaign scored every design on the cold path" \
  "This campaign is the first screen after the physics-validation era." \
  "Larger and wider campaigns sit ahead." \
  "The machine held a steady operating point through the measurement window." \
  "each weather band would need its own single kite" \
  "That kite would reach giant sizes and be too hard to handle." \
  "The report also assumes a staged launch of the stack." \
  "A staged launch is easier to handle than one giant kite." \
  "The main-rotor slot" \
  "The second-rotor slot" \
  "The second bank slot holds" \
  "at the top of its search box" \
  "22 degrees" "blade_scale_top" "blade_scale_bottom" "bank_bottom" \
  "physics-validation era" "shaft transition cone" \
  "pass, P_end 5.314 kW" "15.0 on 2.5" "pass, 15.0 minimum" \
  "the warm path rejects healthy winners" "It never allows breaks" "Torsional capacity"

echo '== 6. register anchors =='
for r in 011 012 017 043 046 047; do echo "-- NR-$r"; grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-240; done
echo '-- NR-049 row'
grep -n "| NR-049 " docs/reporting/numbers-register.md | head -1 | cut -c1-400
echo '-- NR-050 row'
grep -n "| NR-050 " docs/reporting/numbers-register.md | head -1 | cut -c1-400

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
md5sum scratch/report-pdf-build/draft-e5541e9-20261014-200839.docx
head -16 scratch/report-pdf-build/build-record-docx.txt
ls -la scratch/report-pdf-build/ | grep -i lock

echo '== 8. plate pins (hero set, sha256) =='
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.png
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.svg
sha256sum docs/reporting/figures/machine-winner-hero/machine-winner-hero.pdf
sha256sum docs/reporting/figures/machine-winner-hero/checks.log

echo '== done =='
