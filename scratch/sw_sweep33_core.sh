#!/usr/bin/env bash
# Sweep 33 core run — science-writer, 2026-10-18 (branch bank-derate-cos2p65).
# Span: 1b01453 (sweep 32 span end) -> HEAD (de18442, v0.64).
# Draft movers: 89ed222 v0.53, d453530 v0.54, 2e930a8 v0.55, c9f0560 v0.56,
#   c825a01 v0.57, the round-1 fix set (c97a7fd..f7de920), 3321c9a v0.58/v0.59,
#   the ring-beam pair (d360d47, 646cddf), ef07533 v0.60, ff60775 v0.61,
#   the display set (5916357, e7f68a9) v0.62, 3290876 v0.63, de18442 v0.64.
# Register movers from cb862df. Review copy stale at b6cd166; rebuild queued.
# Record only: not meant to be re-run.
set -u
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
G=docs/reporting/glossary-candidates.md
S=docs/agents/stale-phrases.md
R=docs/reporting/numbers-register.md
BASE=1b01453
REVS="1b01453 89ed222 d453530 2e930a8 c9f0560 c825a01 f7de920 3321c9a 646cddf ef07533 ff60775 e7f68a9 3290876 de18442"
PREV=""

echo '== 0. preflight =='
git rev-parse --short HEAD
git status --short -- "$D" "$T" "$G" "$S" "$R" | cat
git log --oneline -1 | cat
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
git rev-list --count $BASE..HEAD
echo '-- draft movers (all)'
git log --oneline $BASE..HEAD -- "$D" | cat
echo '-- draft movers before v0.53 (expect none)'
git log --oneline $BASE..89ed222 -- "$D" | cat
echo '-- tracker movers'
git log --oneline $BASE..HEAD -- "$T" | cat
echo '-- candidates movers'
git log --oneline $BASE..HEAD -- "$G" | cat
echo '-- stale-phrases movers'
git log --oneline $BASE..HEAD -- "$S" | cat
echo '-- register movers'
git log --oneline cb862df..HEAD -- "$R" | cat
echo '-- register numstat cb862df..HEAD (append-only check)'
git diff --numstat cb862df..HEAD -- "$R" | cat
echo '-- register removed lines (display-amend read)'
git diff cb862df..HEAD -- "$R" | grep '^-' | grep -v '^---' | head -60 | cat

echo '== 1b. version tick verification =='
for c in 5916357 e7f68a9 3290876 de18442; do
  echo "-- head at $c"; git show $c:"$D" | sed -n '3p'
done

echo '== 2. extracts =='
for c in $REVS; do
  git show $c:"$D" > scratch/sw_sweep33_draft_$c.md
done
git show $BASE:"$T" > scratch/sw_sweep33_tracker_base.md
git show HEAD:"$T" > scratch/sw_sweep33_tracker_tip.md
git show $BASE:"$G" > scratch/sw_sweep33_candidates_base.md
git show HEAD:"$G" > scratch/sw_sweep33_candidates_tip.md
git show $BASE:"$S" > scratch/sw_sweep33_sp_base.md
git show HEAD:"$S" > scratch/sw_sweep33_sp_tip.md
wc -l scratch/sw_sweep33_draft_*.md scratch/sw_sweep33_tracker_*.md scratch/sw_sweep33_candidates_*.md scratch/sw_sweep33_sp_*.md | tail -1

echo '== 2b. per-pair numstats and changed lines (draft) =='
for c in $REVS; do
  if [ -n "$PREV" ]; then
    echo "-- pair $PREV..$c"
    git diff --numstat $PREV $c -- "$D" | cat
    git diff $PREV $c -- "$D" | grep '^+' | grep -v '^+++' | grep -v '^+$' | wc -l
    git diff $PREV $c -- "$D" | grep '^-' | grep -v '^---' | grep -v '^-$' | wc -l
    git diff -U0 $PREV $c -- "$D" | grep '^@@' | cat
  fi
  PREV=$c
done
echo '-- tracker numstat span'
git diff --numstat $BASE..HEAD -- "$T" | cat

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" 1b01453 89ed222 d453530 2e930a8 c9f0560 c825a01 f7de920 3321c9a 646cddf ef07533 ff60775 e7f68a9 3290876 de18442 | tee scratch/sw_sweep33_tokdiff_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" 1b01453 89ed222 d453530 2e930a8 c9f0560 c825a01 f7de920 3321c9a 646cddf ef07533 ff60775 e7f68a9 3290876 de18442 | tee scratch/sw_sweep33_tokdiff_tracker.txt

echo '== 4. STE gates and offenders =='
for c in $REVS; do
  f=sw_sweep33_draft_$c
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md | head -3
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
done
for f in sw_sweep33_tracker_base sw_sweep33_tracker_tip sw_sweep33_candidates_base sw_sweep33_candidates_tip sw_sweep33_sp_base sw_sweep33_sp_tip; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md | head -3
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
done
echo '-- offdiffs'
> scratch/sw_sweep33_offdiffs.txt
PREV=""
for c in $REVS; do
  if [ -n "$PREV" ]; then
    echo "-- pair $PREV..$c" >> scratch/sw_sweep33_offdiffs.txt
    diff scratch/sw_sweep33_draft_${PREV}_off.txt scratch/sw_sweep33_draft_${c}_off.txt >> scratch/sw_sweep33_offdiffs.txt
  fi
  PREV=$c
done
echo "-- tracker" >> scratch/sw_sweep33_offdiffs.txt
diff scratch/sw_sweep33_tracker_base_off.txt scratch/sw_sweep33_tracker_tip_off.txt >> scratch/sw_sweep33_offdiffs.txt
echo "-- candidates" >> scratch/sw_sweep33_offdiffs.txt
diff scratch/sw_sweep33_candidates_base_off.txt scratch/sw_sweep33_candidates_tip_off.txt >> scratch/sw_sweep33_offdiffs.txt
echo "-- stale-phrases" >> scratch/sw_sweep33_offdiffs.txt
diff scratch/sw_sweep33_sp_base_off.txt scratch/sw_sweep33_sp_tip_off.txt >> scratch/sw_sweep33_offdiffs.txt
wc -l scratch/sw_sweep33_offdiffs.txt

echo '== 5. greps (tip, de18442) =='
TIP=scratch/sw_sweep33_draft_de18442.md
echo '-- retired phrasing stems'
grep -n -i 'adaptive' $TIP || echo 'adaptive: zero'
grep -n 'DifferentialEquations' $TIP || echo 'DifferentialEquations: zero'
echo '-- naming traps'
grep -n 'hub rotor\|expansion model\|rigid driveshaft' $TIP || echo 'traps: none'
echo '-- house vocabulary'
grep -n -i 'the room\|seat check\|science-writer\|science-validator\|aero-validator' $TIP || echo 'house vocab: zero'
echo '-- winner calibration'
grep -n 'campaign winner' $TIP | wc -l
grep -n -i 'the winner is\|optimum' $TIP || echo 'optimum: zero'
echo '-- viable census'
grep -n -i 'viable' $TIP || echo 'viable: zero'
echo '-- bridle census'
grep -n -i 'bridle' $TIP
echo '-- topmost census'
grep -n -i 'topmost' $TIP
echo '-- founder forms'
grep -n 'lifting bridles\|Machine winner\|machine winner' $TIP
echo '-- display guards'
grep -n '14\\.97[^0-9]\|3\\.816\|27\\.363' $TIP || echo 'guards: no loose hit'
echo '-- held tokens'
grep -n '1\\.94\|5\\.18' $TIP || echo '1.94/5.18: zero'
grep -n '3\\.55' scratch/sw_sweep33_tracker_tip.md || echo 'tracker 3.55: no hit'
echo '-- head status and stubs'
sed -n '1,6p' $TIP
grep -n 'PENDING' $TIP || echo 'PENDING: no hit'
echo '-- brackets and seated markers'
grep -n 'holds a register row\|Daisy values need register rows' $TIP || echo 'brackets: none'
grep -c 'Figure seated:' $TIP
echo '-- the v0.52 block sentences (ten, expect once each)'
python3 $SK/scripts/phrase-census.py $TIP \
  "At the top of the shaft the rotor turns in the wind." \
  "The blades sweep a ring in the air." \
  "The shaft carries that torque down to the ground." \
  "The tension holds the shaft true." \
  "The lowest ring turns the generator at the ground station." \
  "The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048)." \
  "A low-wind lull is harmless under the load law." \
  "The team refuses to ease k as the high-wind substitute."
echo '-- span new forms (A-10 to A-19 declared set)'
python3 $SK/scripts/phrase-census.py $TIP \
  "campaign winner" \
  "The abstract reads as a narrative" \
  "decision scorecard" \
  "The screen covered" \
  "thirty evolution steps" \
  "the cube of the window-mean ground-ring speed" \
  "a factor of safety of 15.033" \
  "during the relax run" \
  "80 per cent" \
  "the close re-censused"
echo '-- scorecard tokens'
grep -n '508\|930' $TIP | head -12
echo '-- NR-045 generation counts'
grep -n '30 rope breaks\|31 generations\|0 to 30\|indices 0' $TIP | head -8
echo '-- hex refs in tip draft'
grep -noE '[0-9a-f]{7,40}' $TIP | sort -u -t: -k2 > scratch/sw_sweep33_hexrefs.txt
wc -l < scratch/sw_sweep33_hexrefs.txt
cat scratch/sw_sweep33_hexrefs.txt

echo '== 6. register anchors =='
for r in 002 008 009 011 015 018 021 022 023 040 042 044 045 046 047 048 050 052 053 056 059 060 061 062 063; do
  echo "-- NR-$r"
  grep -n "| NR-$r " docs/reporting/numbers-register.md | head -1 | cut -c1-200
done

echo '== 7. review copy readback =='
md5sum scratch/report-pdf-build/draft-live.docx 2>/dev/null || echo 'no live docx'
head -12 scratch/report-pdf-build/build-record-docx.txt 2>/dev/null
echo '-- copy inputs diff, b6cd166..HEAD (draft + register)'
git diff --name-only b6cd166..HEAD -- "$D" "$R" | cat

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
draft = (repo / 'scratch/sw_sweep33_draft_de18442.md').read_text()
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

echo '== 11. cited-commit ancestry =='
for c in $(grep -oE '[0-9a-f]{7,40}' $TIP | sort -u); do
  git merge-base --is-ancestor $c HEAD 2>/dev/null && echo "$c OK" || echo "$c FAIL"
done | sort | uniq -c | sort -rn | head -40

echo '== done =='
