#!/usr/bin/env bash
# Sweep 32 core run — science-writer, 2026-10-15 (branch bank-derate-cos2p65).
# Span: ffc63a7 (sweep 31 span end) -> HEAD, three draft movers:
#   171f3ea (v0.50, the kMppt plain pass), 1061878 (v0.51, the corner-machines fold),
#   b6cd166 (v0.52, the basics-of-TRPT refresher);
#   companion movers: tracker (same three), candidates, stale-phrases; register holds at cb862df.
# Record only: not meant to be re-run.
set -u
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
G=docs/reporting/glossary-candidates.md
S=docs/agents/stale-phrases.md
R=docs/reporting/numbers-register.md
BASE=ffc63a7

echo '== 0. preflight =='
git rev-parse --short HEAD
echo '-- working tree status, gated files (foreign entries only)'
git status --short -- "$D" "$T" "$G" "$S" "$R"
echo '-- tip readback'
git log --oneline -1 | cat
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
echo '-- all commits, BASE..HEAD (count first)'
git rev-list --count $BASE..HEAD
echo '-- draft movers'
git log --oneline $BASE..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline $BASE..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline $BASE..HEAD -- "$G" | cat
echo '-- stale-phrases movers'
git log --oneline $BASE..HEAD -- "$S" | cat
echo '-- register movers and numstat (append-only check)'
git log --oneline $BASE..HEAD -- "$R" | cat
git diff --numstat $BASE..HEAD -- "$R" | cat
echo '-- numstat, draft, per mover'
git diff --numstat 171f3ea^..171f3ea -- "$D" | cat
git diff --numstat 1061878^..1061878 -- "$D" | cat
git diff --numstat b6cd166^..b6cd166 -- "$D" | cat
git diff --numstat $BASE..HEAD -- "$T" | cat
echo '-- zero-diff readback: draft b6cd166 vs HEAD'
git diff --stat b6cd166..HEAD -- "$D" | cat
echo '-- zero-diff readback: register cb862df vs HEAD'
git diff --stat cb862df..HEAD -- "$R" | cat
echo '-- zero-diff readback: tracker b6cd166 vs HEAD'
git diff --stat b6cd166..HEAD -- "$T" | cat
echo '-- ancestry of span revs'
for c in $BASE 8169e36 171f3ea ef93b84 1061878 fc3a602 b6cd166 228adcd cb862df 2bf76a3 317d9cd f5c2d59 1b01453; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show 171f3ea^:"$D" > scratch/sw_sweep32_draft_v049.md
git show 171f3ea:"$D" > scratch/sw_sweep32_draft_v050.md
git show 1061878:"$D" > scratch/sw_sweep32_draft_v051.md
git show b6cd166:"$D" > scratch/sw_sweep32_draft_v052.md
git show $BASE:"$T" > scratch/sw_sweep32_tracker_base.md
git show b6cd166:"$T" > scratch/sw_sweep32_tracker_tip.md
git show $BASE:"$G" > scratch/sw_sweep32_candidates_base.md
git show HEAD:"$G" > scratch/sw_sweep32_candidates_tip.md
git show $BASE:"$S" > scratch/sw_sweep32_sp_base.md
git show HEAD:"$S" > scratch/sw_sweep32_sp_tip.md
wc -l scratch/sw_sweep32_draft_v05*.md scratch/sw_sweep32_tracker_*.md scratch/sw_sweep32_candidates_*.md scratch/sw_sweep32_sp_*.md

echo '== 2b. span diffs =='
git diff 171f3ea^ b6cd166 -- "$D" > scratch/sw_sweep32_draft_diff.txt
wc -l scratch/sw_sweep32_draft_diff.txt
echo '-- added non-blank lines; removed non-blank lines (span)'
git diff 171f3ea^ b6cd166 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff 171f3ea^ b6cd166 -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
echo '-- per-mover added non-blank lines'
git diff 171f3ea^ 171f3ea -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff 1061878^ 1061878 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff b6cd166^ b6cd166 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
echo '-- per-mover removed non-blank lines'
git diff 171f3ea^ 171f3ea -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
git diff 1061878^ 1061878 -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
git diff b6cd166^ b6cd166 -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
echo '-- changed-line numbers, per mover (unified hunks)'
git diff -U0 171f3ea^ 171f3ea -- "$D" | grep '^@@' 
git diff -U0 1061878^ 1061878 -- "$D" | grep '^@@'
git diff -U0 b6cd166^ b6cd166 -- "$D" | grep '^@@'
echo '-- files touched per mover'
git show --stat --oneline 171f3ea | cat
git show --stat --oneline 1061878 | cat
git show --stat --oneline b6cd166 | cat
git diff $BASE..b6cd166 -- "$T" > scratch/sw_sweep32_tracker_diff.txt
wc -l scratch/sw_sweep32_tracker_diff.txt

echo '== 3. token tools: draft (four revs) =='
python3 $SK/scripts/draft-token-diff.py . "$D" 171f3ea^ 171f3ea 1061878 b6cd166 | tee scratch/sw_sweep32_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" 171f3ea^ 171f3ea 1061878 b6cd166 | tee scratch/sw_sweep32_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" 171f3ea^ 171f3ea 1061878 b6cd166 | tee scratch/sw_sweep32_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" $BASE 171f3ea 1061878 b6cd166 | tee scratch/sw_sweep32_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" $BASE 171f3ea 1061878 b6cd166 | tee scratch/sw_sweep32_attrib_tracker.txt

echo '== 4. STE gates and offenders =='
for f in sw_sweep32_draft_v049 sw_sweep32_draft_v050 sw_sweep32_draft_v051 sw_sweep32_draft_v052 sw_sweep32_tracker_base sw_sweep32_tracker_tip sw_sweep32_candidates_base sw_sweep32_candidates_tip sw_sweep32_sp_base sw_sweep32_sp_tip; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md | head -3
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l < scratch/${f}_off.txt
done
echo '-- offdiffs (draft per mover, tracker, candidates, sp)'
diff scratch/sw_sweep32_draft_v049_off.txt scratch/sw_sweep32_draft_v050_off.txt > scratch/sw_sweep32_offdiffs.txt
diff scratch/sw_sweep32_draft_v050_off.txt scratch/sw_sweep32_draft_v051_off.txt >> scratch/sw_sweep32_offdiffs.txt
diff scratch/sw_sweep32_draft_v051_off.txt scratch/sw_sweep32_draft_v052_off.txt >> scratch/sw_sweep32_offdiffs.txt
diff scratch/sw_sweep32_tracker_base_off.txt scratch/sw_sweep32_tracker_tip_off.txt >> scratch/sw_sweep32_offdiffs.txt
diff scratch/sw_sweep32_candidates_base_off.txt scratch/sw_sweep32_candidates_tip_off.txt >> scratch/sw_sweep32_offdiffs.txt
diff scratch/sw_sweep32_sp_base_off.txt scratch/sw_sweep32_sp_tip_off.txt >> scratch/sw_sweep32_offdiffs.txt
wc -l scratch/sw_sweep32_offdiffs.txt

echo '== 5. greps (v052) =='
echo '-- retired word hub (expect zero)'
grep -c -i 'hub' scratch/sw_sweep32_draft_v052.md || echo 'hub: zero'
echo '-- hero census (expect the slug only)'
grep -n -i 'hero' scratch/sw_sweep32_draft_v052.md || echo 'hero: zero'
echo '-- winner-form census'
grep -n 'Machine winner' scratch/sw_sweep32_draft_v052.md
grep -n -i 'machine winner' scratch/sw_sweep32_draft_v052.md | wc -l
echo '-- lifting-bridles census'
grep -n 'lifting bridles\|lifting-bridle' scratch/sw_sweep32_draft_v052.md
echo '-- bridle hold senses'
grep -n 'bridle' scratch/sw_sweep32_draft_v052.md
echo '-- topmost census (lines)'
grep -n -i 'topmost' scratch/sw_sweep32_draft_v052.md
echo '-- the count sentence, winner pair, title'
grep -n '508 feasible candidates' scratch/sw_sweep32_draft_v052.md
grep -n 'mean power of 5.309' scratch/sw_sweep32_draft_v052.md
grep -n '25.698 kilograms' scratch/sw_sweep32_draft_v052.md
grep -n 'The levers of Performance' scratch/sw_sweep32_draft_v052.md
echo '-- display guard forms and superseded reads'
grep -n '14\.97[^0-9]\|3\.816\|27\.363' scratch/sw_sweep32_draft_v052.md || echo 'guards: no loose hit'
echo '-- brackets and seated markers'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep32_draft_v052.md
grep -c 'Figure seated:' scratch/sw_sweep32_draft_v052.md
echo '-- held tokens'
grep -n '1\.94\|5\.18' scratch/sw_sweep32_draft_v052.md
grep -n '3\.55' scratch/sw_sweep32_tracker_tip.md || echo 'tracker 3.55: no hit'
echo '-- head status and stubs'
sed -n '1,10p' scratch/sw_sweep32_draft_v052.md
grep -n 'PENDING' scratch/sw_sweep32_draft_v052.md || echo 'no hit'
echo '-- the v0.52 operation block (digit-free, cite-free)'
grep -n 'At the top of the shaft' scratch/sw_sweep32_draft_v052.md
grep -n 'the machine settles onto one operating point' scratch/sw_sweep32_draft_v052.md
sed -n '228,246p' scratch/sw_sweep32_draft_v052.md
echo '-- block region digit/cite census (expect zero in 228-246)'
sed -n '228,246p' scratch/sw_sweep32_draft_v052.md | grep -nE '[0-9]|NR-[0-9]' || echo 'block: no digit, no cite'
echo '-- naming-trap near-hits (expect zero live)'
grep -n 'hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model' scratch/sw_sweep32_draft_v052.md || echo 'near-hits: none'
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 671ab96 e23f226 c438398 1af63fc d243b37 9241b23 a4b4057; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v052'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep32_draft_v052.md | sort -u -t: -k2 > scratch/sw_sweep32_hexrefs.txt
wc -l < scratch/sw_sweep32_hexrefs.txt

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep32_draft_v052.md \
  "down the lifting bridles" \
  "Machine winner" \
  "machine winner" \
  "machine-winner-hero" \
  "The search found 508 feasible candidates in the searched space (NR-002)." \
  "The best performing one had a mean power of 5.309 kW." \
  "Its airborne mass is 25.698 kilograms (NR-008, NR-018)." \
  "The levers of Performance" \
  "topmost ring" "topmost rotor ring" \
  "the topmost-ring and ground radii" \
  "The capture topmost ring" \
  "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021)." \
  "22 degrees" "shaft transition cone" "physics-validation era" \
  "pass, P_end 5.314 kW" "15.0 on 2.5" "pass, 15.0 minimum" \
  "the warm path rejects healthy winners" "It never allows breaks" "Torsional capacity" \
  "At the top of the shaft the rotor turns in the wind" \
  "The lowest ring turns the generator at the ground station." \
  "Under the generator load the machine settles onto one operating point." \
  "In the settled state the shaft runs twisted along its length."

echo '== 5c. v0.52 block sentence census (ten sentences, once each) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep32_draft_v052.md \
  "At the top of the shaft the rotor turns in the wind." \
  "The blades sweep a ring in the air." \
  "The shaft carries that torque down to the ground." \
  "The tension holds the shaft true." \
  "The lowest ring turns the generator at the ground station." \
  "The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048)." \
  "A low-wind lull is harmless under the load law." \
  "The team refuses to ease k as the high-wind substitute."

echo '== 6. register anchors =='
for r in 002 008 018 021 044 046 048 051; do echo "-- NR-$r"; grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-260; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
head -20 scratch/report-pdf-build/build-record-docx.txt
echo '-- copy inputs diff, b6cd166..HEAD (draft + register; expect empty)'
git diff --name-only b6cd166..HEAD -- "$D" "$R" | cat
echo '-- figures diffs since stamp'
git diff --name-only b6cd166..HEAD -- docs/reporting/figures | wc -l
echo '-- build dir census'
ls -la scratch/report-pdf-build/*.docx | cat

echo '== 8. plate pins (seated kits, sha256) =='
for k in ring-utilisation twist-limit eval-timeline machine-evolution-strip machine-winner-hero machine-corner-grid; do
  for ext in svg png; do f=docs/reporting/figures/$k/$k.$ext; [ -f "$f" ] && sha256sum "$f"; done
done
sha256sum docs/reporting/figures/system-anatomy/system-anatomy.pdf docs/reporting/figures/system-anatomy/system-anatomy.png 2>/dev/null

echo '== 9. freeze check (levers-reading block) =='
python3 - <<'EOF'
import pathlib, hashlib
md5 = lambda t: hashlib.md5(t.encode()).hexdigest()
repo = pathlib.Path('.')
block = (repo / 'scratch/sw_levers_reading_block.md').read_text()
receipt = (repo / 'docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md').read_text()
B, E = '<!-- LEVERS-READING-START -->', '<!-- LEVERS-READING-END -->'
seg = receipt.split(B, 1)[1].split(E, 1)[0].strip('\n')
draft = (repo / 'scratch/sw_sweep32_draft_v052.md').read_text()
s = 'The two plates map the same search in two views.'
e = 'The gene-level effects wait on the landscape extracts.'
region = draft[draft.index(s):draft.index(e) + len(e)]
print('block md5 (as written):', md5(block))
print('receipt region == block:', seg == block.strip('\n'))
print('draft region == block:', region == block.strip('\n'))
print('declared block md5: 7bbd964db09d2b33269ce5cb8c334054')
EOF

echo '== 10. pins check (appendix cells) =='
python3 $SK/scripts/pins-check.py . "$D" | tail -8

echo '== done =='
