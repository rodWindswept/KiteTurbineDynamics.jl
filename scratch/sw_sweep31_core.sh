#!/usr/bin/env bash
# Sweep 31 core run — science-writer, 2026-10-15 (branch bank-derate-cos2p65).
# Span: 4ded913 (sweep 30 section span end) -> ffc63a7 tip, two draft movers:
#   6f19eee (v0.48, the SA pins), 8169e36 (v0.49, the re-keys);
#   companion movers: tracker (6f19eee, 8169e36), candidates (97eefdc, v17),
#   stale-phrases (b32bbb2); no register landing in the span.
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
echo '-- all commits, 4ded913..HEAD (count first)'
git rev-list --count 4ded913..HEAD
echo '-- draft movers'
git log --oneline 4ded913..HEAD -- "$D" | cat
echo '-- tracker movers'
git log --oneline 4ded913..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline 4ded913..HEAD -- "$G" | cat
echo '-- stale-phrases movers'
git log --oneline 4ded913..HEAD -- "$S" | cat
echo '-- register movers and numstat (append-only check)'
git log --oneline 4ded913..HEAD -- "$R" | cat
git diff --numstat 4ded913..HEAD -- "$R" | cat
echo '-- numstat, gated files, d0ed902..8169e36 (draft) and 4ded913..HEAD (tracker)'
git diff --numstat d0ed902..8169e36 -- "$D" | cat
git diff --numstat 4ded913..HEAD -- "$T" | cat
echo '-- zero-diff readback: draft 8169e36 vs HEAD'
git diff --stat 8169e36..HEAD -- "$D" | cat
echo '-- zero-diff readback: register cb862df vs HEAD'
git diff --stat cb862df..HEAD -- "$R" | cat
echo '-- ancestry of span revs'
for c in 4ded913 d0ed902 6f19eee 8169e36 cb862df 97eefdc b32bbb2 382727c ffc63a7; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show d0ed902:"$D" > scratch/sw_sweep31_draft_v047.md
git show 6f19eee:"$D" > scratch/sw_sweep31_draft_v048.md
git show 8169e36:"$D" > scratch/sw_sweep31_draft_v049.md
git show 4ded913:"$T" > scratch/sw_sweep31_tracker_base.md
git show 8169e36:"$T" > scratch/sw_sweep31_tracker_tip.md
git show 4ded913:"$G" > scratch/sw_sweep31_candidates_base.md
git show HEAD:"$G" > scratch/sw_sweep31_candidates_tip.md
git show 4ded913:"$S" > scratch/sw_sweep31_sp_base.md
git show HEAD:"$S" > scratch/sw_sweep31_sp_tip.md
wc -l scratch/sw_sweep31_draft_v04*.md scratch/sw_sweep31_tracker_*.md scratch/sw_sweep31_candidates_*.md scratch/sw_sweep31_sp_*.md

echo '== 2b. span diffs =='
git diff d0ed902 8169e36 -- "$D" > scratch/sw_sweep31_draft_diff.txt
wc -l scratch/sw_sweep31_draft_diff.txt
echo '-- added non-blank lines; removed non-blank lines'
git diff d0ed902 8169e36 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff d0ed902 8169e36 -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
echo '-- per-mover added non-blank lines'
git diff 6f19eee^ 6f19eee -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff 8169e36^ 8169e36 -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
git diff 4ded913 HEAD -- "$T" > scratch/sw_sweep31_tracker_diff.txt
wc -l scratch/sw_sweep31_tracker_diff.txt

echo '== 3. token tools: draft (three revs) =='
python3 $SK/scripts/draft-token-diff.py . "$D" d0ed902 6f19eee 8169e36 | tee scratch/sw_sweep31_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" d0ed902 6f19eee 8169e36 | tee scratch/sw_sweep31_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" d0ed902 6f19eee 8169e36 | tee scratch/sw_sweep31_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 4ded913 6f19eee 8169e36 | tee scratch/sw_sweep31_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" 4ded913 6f19eee 8169e36 | tee scratch/sw_sweep31_attrib_tracker.txt

echo '== 4. STE gates and offenders =='
for f in sw_sweep31_draft_v047 sw_sweep31_draft_v049 sw_sweep31_tracker_base sw_sweep31_tracker_tip sw_sweep31_candidates_base sw_sweep31_candidates_tip sw_sweep31_sp_base sw_sweep31_sp_tip; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md | head -3
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l < scratch/${f}_off.txt
done
echo '-- offdiffs (draft, tracker, candidates, sp)'
diff scratch/sw_sweep31_draft_v047_off.txt scratch/sw_sweep31_draft_v049_off.txt > scratch/sw_sweep31_offdiffs.txt
diff scratch/sw_sweep31_tracker_base_off.txt scratch/sw_sweep31_tracker_tip_off.txt >> scratch/sw_sweep31_offdiffs.txt
diff scratch/sw_sweep31_candidates_base_off.txt scratch/sw_sweep31_candidates_tip_off.txt >> scratch/sw_sweep31_offdiffs.txt
diff scratch/sw_sweep31_sp_base_off.txt scratch/sw_sweep31_sp_tip_off.txt >> scratch/sw_sweep31_offdiffs.txt
wc -l scratch/sw_sweep31_offdiffs.txt

echo '== 5. greps (v049) =='
echo '-- retired word hub (expect zero)'
grep -c -i 'hub' scratch/sw_sweep31_draft_v049.md || echo 'hub: zero'
echo '-- hero census (expect the slug only)'
grep -n -i 'hero' scratch/sw_sweep31_draft_v049.md || echo 'hero: zero'
echo '-- winner-form census'
grep -n 'Machine winner' scratch/sw_sweep31_draft_v049.md
grep -n -i 'machine winner' scratch/sw_sweep31_draft_v049.md | wc -l
echo '-- lifting-bridles census'
grep -n 'lifting bridles\|lifting-bridle' scratch/sw_sweep31_draft_v049.md
echo '-- bridle hold senses (expect 46, 190, 848)'
grep -n 'bridle' scratch/sw_sweep31_draft_v049.md
echo '-- topmost census (lines)'
grep -n -i 'topmost' scratch/sw_sweep31_draft_v049.md
echo '-- the count sentence, winner pair, title'
grep -n '508 feasible candidates' scratch/sw_sweep31_draft_v049.md
grep -n 'mean power of 5.309' scratch/sw_sweep31_draft_v049.md
grep -n '25.698 kilograms' scratch/sw_sweep31_draft_v049.md
grep -n 'The levers of Performance' scratch/sw_sweep31_draft_v049.md
echo '-- display guard forms and superseded reads'
grep -n '14\.97[^0-9]\|3\.816\|27\.363' scratch/sw_sweep31_draft_v049.md || echo 'guards: no loose hit'
echo '-- brackets and seated markers'
grep -n 'holds a register row\|Daisy values need register rows' scratch/sw_sweep31_draft_v049.md
grep -c 'Figure seated:' scratch/sw_sweep31_draft_v049.md
echo '-- held tokens'
grep -n '1\.94\|5\.18' scratch/sw_sweep31_draft_v049.md
grep -n '3\.55' scratch/sw_sweep31_tracker_tip.md || echo 'tracker 3.55: no hit'
echo '-- head status and stubs'
sed -n '1,10p' scratch/sw_sweep31_draft_v049.md
grep -n 'PENDING' scratch/sw_sweep31_draft_v049.md || echo 'no hit'
echo '-- naming-trap near-hits (expect zero live)'
grep -n 'hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model' scratch/sw_sweep31_draft_v049.md || echo 'near-hits: none'
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 671ab96 e23f226 c438398 1af63fc d243b37 9241b23; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v049'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep31_draft_v049.md | sort -u -t: -k2 > scratch/sw_sweep31_hexrefs.txt
wc -l < scratch/sw_sweep31_hexrefs.txt

echo '== 5b. phrase census (flat) =='
python3 $SK/scripts/phrase-census.py scratch/sw_sweep31_draft_v049.md \
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
  "the warm path rejects healthy winners" "It never allows breaks" "Torsional capacity"

echo '== 6. register anchors =='
for r in 002 008 018 021 046 048 051; do echo "-- NR-$r"; grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-260; done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx
head -18 scratch/report-pdf-build/build-record-docx.txt
echo '-- copy inputs diff, 8169e36..HEAD (draft + register; expect empty)'
git diff --name-only 8169e36..HEAD -- "$D" "$R" | cat
echo '-- figures diffs since stamp (records and the unseated corner kit)'
git diff --name-only 8169e36..HEAD -- docs/reporting/figures | wc -l

echo '== 8. plate pins (seated kits, sha256) =='
for k in ring-utilisation twist-limit eval-timeline machine-evolution-strip machine-winner-hero; do
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
draft = (repo / 'scratch/sw_sweep31_draft_v049.md').read_text()
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
