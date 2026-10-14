#!/usr/bin/env bash
# Sweep 22 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Span: dcf8213 (v0.33) -> e0919ff, three draft movers from dcf8213:
#   a3c2def (v0.34, polish pair two), ef36c6c (v0.35, appendix re-pin),
#   57c77cf (v0.36, objective block and rename).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep22_core.log. Record only: not meant to be re-run.
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
git log --oneline -1
git rev-list --left-right --count HEAD...origin/bank-derate-cos2p65

echo '== 1. span enumeration =='
echo '-- all commits, dcf8213..HEAD'
git log --oneline dcf8213..HEAD
echo '-- draft movers'
git log --oneline dcf8213..HEAD -- "$D"
echo '-- tracker movers'
git log --oneline dcf8213..HEAD -- "$T"
echo '-- glossary movers'
git log --oneline dcf8213..HEAD -- "$G"
echo '-- register movers, 6255268..HEAD'
git log --oneline 6255268..HEAD -- "$R"
echo '-- numstat, register 6255268..HEAD (append-only check)'
git diff --numstat 6255268..HEAD -- "$R"
echo '-- numstat, gated files, dcf8213..HEAD'
git diff --numstat dcf8213..HEAD -- "$D" "$T" "$G" "$R"
echo '-- zero-diff readback: draft/tracker/glossary 57c77cf vs HEAD'
git diff --stat 57c77cf..HEAD -- "$D" "$T" "$G"
echo '-- zero-diff readback: register 4a86e6f vs HEAD'
git diff --stat 4a86e6f..HEAD -- "$R"
echo '-- ancestry of movers'
for c in a3c2def ef36c6c 57c77cf 4a86e6f; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done

echo '== 2. extracts =='
git show dcf8213:$D > scratch/sw_sweep22_draft_v033.md
git show a3c2def:$D > scratch/sw_sweep22_draft_v034.md
git show ef36c6c:$D > scratch/sw_sweep22_draft_v035.md
git show 57c77cf:$D > scratch/sw_sweep22_draft_v036.md
git show dcf8213:$T > scratch/sw_sweep22_tracker_v033.md
git show a3c2def:$T > scratch/sw_sweep22_tracker_v034.md
git show ef36c6c:$T > scratch/sw_sweep22_tracker_v035.md
git show 57c77cf:$T > scratch/sw_sweep22_tracker_v036.md
git show ef36c6c:$G > scratch/sw_sweep22_gloss_v035.md
git show 57c77cf:$G > scratch/sw_sweep22_gloss_v036.md
wc -l scratch/sw_sweep22_draft_v0*.md scratch/sw_sweep22_tracker_v0*.md scratch/sw_sweep22_gloss_v0*.md

echo '== 3. token tools: draft =='
python3 $SK/scripts/draft-token-diff.py . "$D" dcf8213 a3c2def ef36c6c 57c77cf | tee scratch/sw_sweep22_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . "$D" dcf8213 a3c2def ef36c6c 57c77cf | tee scratch/sw_sweep22_attrib_draft.txt
python3 $SK/scripts/token-netpairs.py . "$D" dcf8213 a3c2def ef36c6c 57c77cf | tee scratch/sw_sweep22_netpairs_draft.txt

echo '== 3b. token tools: tracker =='
python3 $SK/scripts/draft-token-diff.py . "$T" dcf8213 a3c2def ef36c6c 57c77cf | tee scratch/sw_sweep22_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . "$T" dcf8213 a3c2def ef36c6c 57c77cf | tee scratch/sw_sweep22_attrib_tracker.txt

echo '== 3c. token tools: glossary =='
python3 $SK/scripts/draft-token-diff.py . "$G" ef36c6c 57c77cf | tee scratch/sw_sweep22_tokdiff_gloss.txt
python3 $SK/scripts/token-attrib.py . "$G" ef36c6c 57c77cf | tee scratch/sw_sweep22_attrib_gloss.txt

echo '== 4. STE gates =='
for f in sw_sweep22_draft_v033 sw_sweep22_draft_v034 sw_sweep22_draft_v035 sw_sweep22_draft_v036 sw_sweep22_tracker_v033 sw_sweep22_tracker_v034 sw_sweep22_tracker_v035 sw_sweep22_tracker_v036 sw_sweep22_gloss_v035 sw_sweep22_gloss_v036; do
  echo "-- $f"
  python3 ste-lint.py --fail-above 2.0 scratch/$f.md
  python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/$f.md > scratch/${f}_off.txt
  wc -l scratch/${f}_off.txt
done

echo '== 5. greps (v036) =='
echo '-- retired phrasing'
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep22_draft_v036.md || echo 'no hit'
echo '-- superseded values'
grep -n "3\.816\|14\.972\|14\.97" scratch/sw_sweep22_draft_v036.md || echo 'no hit'
echo '-- near-hits'
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep22_draft_v036.md || echo 'no hit'
echo '-- rename census: old form (expect none), draft + gloss + tracker'
grep -n -i "gate penalt" scratch/sw_sweep22_draft_v036.md scratch/sw_sweep22_gloss_v036.md scratch/sw_sweep22_tracker_v036.md || echo 'no hit'
echo '-- rename census: new form'
grep -n "soft constraint penalt" scratch/sw_sweep22_draft_v036.md scratch/sw_sweep22_gloss_v036.md || echo 'no hit'
echo '-- kg-equivalent census'
grep -n -c "kg-equivalent" scratch/sw_sweep22_draft_v036.md
echo '-- pending markers'
grep -n "PENDING\|pending" scratch/sw_sweep22_draft_v036.md || echo 'no hit'
echo '-- head block'
sed -n '1,32p' scratch/sw_sweep22_draft_v036.md
echo '-- held tokens'
grep -n "1\.94\|5\.18\|3\.55" scratch/sw_sweep22_draft_v036.md scratch/sw_sweep22_tracker_v036.md || echo 'no hit'
echo '-- Daisy sites, section 5'
grep -n "Daisy" scratch/sw_sweep22_draft_v036.md
echo '-- cited commits resolve'
for c in dd3cc6a a76c5e9 31ca00d 74cfef9 9cecee3 95c385d 671ab96 e23f226; do git merge-base --is-ancestor $c HEAD && echo "$c OK" || echo "$c FAIL"; done
echo '-- hex refs in draft v036'
grep -noE '[0-9a-f]{7,40}' scratch/sw_sweep22_draft_v036.md | sort -u -t: -k2 > scratch/sw_sweep22_hexrefs.txt
wc -l scratch/sw_sweep22_hexrefs.txt
echo '-- naming-trap near-hits'
grep -n "hub rotor\|supplementary\|identical geometry\|shaft tilt\|expansion model" scratch/sw_sweep22_draft_v036.md || echo 'no hit'
echo '-- repo census: old rename form (records may quote it; the gate is draft + glossary)'
grep -rn -i "gate penalt" docs/reporting/ || echo 'no hit'

echo '== 6. register anchors =='
for r in 001 002 005 006 018 039 044 045 046; do echo "-- NR-$r"; grep -n "NR-$r" docs/reporting/numbers-register.md; done

echo '== done =='
