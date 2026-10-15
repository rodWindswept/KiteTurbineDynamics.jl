#!/usr/bin/env bash
# Sweep 30 core run — science-writer, 2026-10-15 (branch bank-derate-cos2p65).
# Span: 8a1e552 (sweep 29 section span end) -> 4ded913, four draft movers:
#   2f79aae (v0.44), 34e3f81 (v0.45), 45ed95a (v0.46), d0ed902 (v0.47);
#   companion movers: tracker (e5541e9..HEAD set), candidates (69ec727, v16),
#   stale-phrases (50e0300); one register landing: cb862df (NR-051).
# Record only: not meant to be re-run.
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
G=docs/reporting/glossary-candidates.md
S=docs/agents/stale-phrases.md
R=docs/reporting/numbers-register.md

echo '== 0. preflight =='
git rev-parse --short HEAD
echo '-- working tree status, gated files (foreign entries only)'
git status --short -- "$D" "$T" "$G" "$S" "$R"
echo '-- tip readback'
git log --oneline -1 | cat
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
echo '-- all commits, 8a1e552..HEAD (count first)'
git rev-list --count 8a1e552..HEAD
echo '-- draft movers'
git log --oneline 8a1e552..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline 8a1e552..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline 8a1e552..HEAD -- "$G" | cat
echo '-- stale-phrases movers'
git log --oneline 8a1e552..HEAD -- "$S" | cat
echo '-- register movers and numstat (append-only check)'
git log --oneline 8a1e552..HEAD -- "$R" | cat
git diff --numstat 8a1e552..HEAD -- "$R"
echo '-- numstat, gated files, 8a1e552..HEAD'
git diff --numstat 8a1e552..HEAD -- "$D" "$T" "$G" "$S" "$R"
echo '-- zero-diff readback: draft d0ed902 vs HEAD'
git diff --stat d0ed902..HEAD -- "$D" | cat
echo '-- zero-diff readback: register cb862df vs HEAD'
git diff --stat cb862df..HEAD -- "$R" | cat
echo '-- ancestry of span revs'
for c in 8a1e552 2f79aae 34e3f81 45ed95a d0ed902 cb862df 69ec727 50e0300 4ded913; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show e5541e9:"$D" > scratch/sw_sweep30_draft_v043.md
git show 2f79aae:"$D" > scratch/sw_sweep30_draft_v044.md
git show 34e3f81:"$D" > scratch/sw_sweep30_draft_v045.md
git show 45ed95a:"$D" > scratch/sw_sweep30_draft_v046.md
git show d0ed902:"$D" > scratch/sw_sweep30_draft_v047.md
git show e5541e9:"$T" > scratch/sw_sweep30_tracker_v043.md
git show HEAD:"$T" > scratch/sw_sweep30_tracker_tip.md
git show 8a1e552:"$G" > scratch/sw_sweep30_candidates_base.md
git show HEAD:"$G" > scratch/sw_sweep30_candidates_tip.md
git show 8a1e552:"$S" > scratch/sw_sweep30_sp_base.md
git show HEAD:"$S" > scratch/sw_sweep30_sp_tip.md
wc -l scratch/sw_sweep30_draft_v04*.md scratch/sw_sweep30_tracker_*.md scratch/sw_sweep30_candidates_*.md scratch/sw_sweep30_sp_*.md

echo '== 2b. span diffs =='
git diff e5541e9 d0ed902 -- "$D" > scratch/sw_sweep30_draft_diff.txt
wc -l scratch/sw_sweep30_draft_diff.txt
echo '-- added non-blank lines (three-stage form)'
git diff e5541e9 d0ed902 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff e5541e9 HEAD -- "$T" > scratch/sw_sweep30_tracker_diff.txt
wc -l scratch/sw_sweep30_tracker_diff.txt
echo '-- draft v0.44/v0.46 pin-only check (no token moves expected)'
git diff 2f79aae^ 2f79aae -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | head -12
git diff 45ed95a^ 45ed95a -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | head -12

echo '== 3. token tools: draft (five revs) =='
python3 $SK/scripts/draft-token-diff.py . "$D" e5541e9 2f79aae 34e3f81 45ed95a d0ed902 | tee scratch/sw_sweep30_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" e5541e9 2f79aae 34e3f81 45ed95a d0ed902 | tee scratch/sw_sweep30_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" e5541e9 2f79aae 34e3f81 45ed95a d0ed902 | tee scratch/sw_sweep30_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" e5541e9 HEAD | tee scratch/sw_sweep30_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" e5541e9 HEAD | tee scratch/sw_sweep30_attrib_tracker.txt

echo '== 4. STE gates and offenders =='
for f in sw_sweep30_draft_v043 sw_sweep30_draft_v047 sw_sweep30_tracker_v043 sw_sweep30_tracker_tip sw_sweep30_candidates_base sw_sweep30_candidates_tip sw_sweep30_sp_base sw_sweep30_sp_tip; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md | head -3
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l < scratch/${f}_off.txt
done
echo '-- offdiffs (draft, tracker, candidates, sp)'
diff scratch/sw_sweep30_draft_v043_off.txt scratch/sw_sweep30_draft_v047_off.txt > scratch/sw_sweep30_offdiffs.txt
diff scratch/sw_sweep30_tracker_v043_off.txt scratch/sw_sweep30_tracker_tip_off.txt >> scratch/sw_sweep30_offdiffs.txt
diff scratch/sw_sweep30_candidates_base_off.txt scratch/sw_sweep30_candidates_tip_off.txt >> scratch/sw_sweep30_offdiffs.txt
diff scratch/sw_sweep30_sp_base_off.txt scratch/sw_sweep30_sp_tip_off.txt >> scratch/sw_sweep30_offdiffs.txt
wc -l scratch/sw_sweep30_offdiffs.txt

echo '== 5. greps (v047) =='
echo '-- retired word (expect zero, raw and word)'
grep -c -i 'hub' scratch/sw_sweep30_draft_v047.md || echo 'hub: zero'
echo '-- topmost census (lines)'
grep -n -i 'topmost' scratch/sw_sweep30_draft_v047.md
echo '-- the count sentence, winner pair, title'
grep -n '508 feasible candidates' scratch/sw_sweep30_draft_v047.md
grep -n 'mean power of 5.309' scratch/sw_sweep30_draft_v047.md
grep -n '25.698 kilograms' scratch/sw_sweep30_draft_v047.md
grep -n 'The levers of Performance' scratch/sw_sweep30_draft_v047.md
echo '-- era table rows and failure table rows'
grep -n 'Before the bank derate\|The wind-authority era\|The cp fix and the folded class' scratch/sw_sweep30_draft_v047.md
grep -n 'rotor-to-ring off-by-one\|stale-gain re-gate\|FoS=Inf guard gap' scratch/sw_sweep30_draft_v047.md
echo '-- carryovers (cone, slots, cold path, era phrase, Tulloch guard)'
grep -n '22 degrees' scratch/sw_sweep30_draft_v047.md
grep -n 'blade_scale_top\|blade_scale_bottom\|bank_bottom' scratch/sw_sweep30_draft_v047.md
grep -n 'scored every design on the cold path\|ODE path is :cold' scratch/sw_sweep30_draft_v047.md
grep -n -i 'physics-validation' scratch/sw_sweep30_draft_v047.md
grep -n -i 'tulloch\|jensen' scratch/sw_sweep30_draft_v047.md || echo 'tulloch/jensen: no hit'
echo '-- display guard forms and superseded reads'
grep -n '14\.97[^0-9]\|3\.816\|27\.363' scratch/sw_sweep30_draft_v047.md || echo 'guards: no loose hit'
echo '-- brackets and seated markers'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep30_draft_v047.md
grep -c 'Figure seated:' scratch/sw_sweep30_draft_v047.md
echo '-- held tokens'
grep -n '1\.94\|5\.18' scratch/sw_sweep30_draft_v047.md
grep -n '3\.55' scratch/sw_sweep30_tracker_tip.md || echo 'tracker 3.55: no hit'
echo '-- head status and stubs'
sed -n '1,16p' scratch/sw_sweep30_draft_v047.md
grep -n 'PENDING' scratch/sw_sweep30_draft_v047.md || echo 'no hit'
echo '-- naming-trap near-hits (expect zero live)'
grep -n 'hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model' scratch/sw_sweep30_draft_v047.md || echo 'near-hits: none'
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 671ab96 e23f226 c438398 1af63fc d243b37; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v047'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep30_draft_v047.md | sort -u -t: -k2 > scratch/sw_sweep30_hexrefs.txt
wc -l < scratch/sw_sweep30_hexrefs.txt

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep30_draft_v047.md \
  "the topmost-ring and ground radii" \
  "The top-segment helix force reads about 1278 N/vertex (NR-048)." \
  "The capture topmost ring" \
  "Topmost ring radius" \
  "topmost ring radius is 4.580 metres" \
  "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021)." \
  "The topmost ring radius is 4.580 m and the ground radius is 0.804 m." \
  "The middle rotor landed on the topmost ring." \
  "the topmost ring (2026-08-26)" \
  "one ring toward the top" \
  "The search found 508 feasible candidates in the searched space (NR-002)." \
  "The best performing one had a mean power of 5.309 kW." \
  "Its airborne mass is 25.698 kilograms (NR-008, NR-018)." \
  "The levers of Performance" \
  "topmost ring" "topmost rotor ring" \
  "22 degrees" "shaft transition cone" "physics-validation era" \
  "The base span reads 0.75 of the rotor radius" "the base chord reads 0.113 of it" \
  "pass, P_end 5.314 kW" "15.0 on 2.5" "pass, 15.0 minimum" \
  "the warm path rejects healthy winners" "It never allows breaks" "Torsional capacity"

echo '== 6. register anchors =='
for r in 002 008 018 021 046 048 051; do echo "-- NR-$r"; grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-260; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
head -18 scratch/report-pdf-build/build-record-docx.txt
echo '-- copy inputs diff, d0ed902..HEAD (draft + register; expect empty)'
git diff --name-only d0ed902..HEAD -- "$D" "$R" | cat
echo '-- figures diffs since stamp (records and the unseated corner kit)'
git diff --name-only d0ed902..HEAD -- docs/reporting/figures | wc -l

echo '== 8. plate pins (seated kits, sha256) =='
for k in ring-utilisation twist-limit eval-timeline machine-evolution-strip machine-winner-hero; do
  for ext in svg png; do f=docs/reporting/figures/$k/$k.$ext; [ -f "$f" ] && sha256sum "$f"; done
done
sha256sum docs/reporting/figures/system-anatomy/system-anatomy.pdf 2>/dev/null || ls docs/reporting/figures/system-anatomy/ | head -12

echo '== 9. freeze check (levers-reading block) =='
python3 - <<'EOF'
import pathlib, hashlib
md5 = lambda t: hashlib.md5(t.encode()).hexdigest()
repo = pathlib.Path('.')
block = (repo / 'scratch/sw_levers_reading_block.md').read_text()
receipt = (repo / 'docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md').read_text()
B, E = '<!-- LEVERS-READING-START -->', '<!-- LEVERS-READING-END -->'
seg = receipt.split(B, 1)[1].split(E, 1)[0].strip('\n')
draft = (repo / 'scratch/sw_sweep30_draft_v047.md').read_text()
s = 'The two plates map the same search in two views.'
e = 'The gene-level effects wait on the landscape extracts.'
region = draft[draft.index(s):draft.index(e) + len(e)]
print('block md5 (as written):', md5(block))
print('receipt region == block:', seg == block.strip('\n'))
print('draft region == block:', region == block.strip('\n'))
print('declared block md5: 7bbd964db09d2b33269ce5cb8c334054')
EOF

echo '== 10. pins check (appendix cells) =='
python3 $SK/scripts/pins-check.py . "$D" | tail -6

echo '== done =='
