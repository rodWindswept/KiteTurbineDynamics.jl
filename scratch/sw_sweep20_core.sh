#!/usr/bin/env bash
# Sweep 20 core run — science-writer, 2026-10-14 (branch bank-derate-cos2p65).
# Commands below were run from the repo root; outputs collected in
# scratch/sw_sweep20_core.log. Record only: not meant to be re-run.
SK=/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting
D=docs/reporting/drafts/2026-10-08-report-first-draft.md
T=docs/reporting/draft-tracker.md
R=docs/reporting/numbers-register.md

# 1. Span enumeration and zero-diff statements
git log --oneline 4ce4b91..HEAD -- $D
git log --oneline 4ce4b91..HEAD -- $T
git log --oneline 4ce4b91..HEAD -- $R
git diff --numstat 4ce4b91..HEAD -- $R $T $D
git diff 76655cb..HEAD -- $D $T
git diff 6255268..HEAD -- $R

# 2. Extracts at both revisions
git show a90122b:$D > scratch/sw_sweep20_draft_v030.md
git show 76655cb:$D > scratch/sw_sweep20_draft_v031.md
git show a90122b:$T > scratch/sw_sweep20_tracker_v030.md
git show 76655cb:$T > scratch/sw_sweep20_tracker_v031.md

# 3. Token tools (skill scripts)
python3 $SK/scripts/draft-token-diff.py . $D a90122b 76655cb | tee scratch/sw_sweep20_tokdiff_draft.txt
python3 $SK/scripts/token-attrib.py . $D a90122b 76655cb | tee scratch/sw_sweep20_attrib_draft.txt
python3 $SK/scripts/draft-token-diff.py . $T a90122b 76655cb | tee scratch/sw_sweep20_tokdiff_tracker.txt
python3 $SK/scripts/token-attrib.py . $T a90122b 76655cb | tee scratch/sw_sweep20_attrib_tracker.txt

# 4. STE gates and offender sets
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_draft_v030.md
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_draft_v031.md
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_tracker_v030.md
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_tracker_v031.md
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_draft_v030.md > scratch/sw_sweep20_off_draft_v030.txt
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_draft_v031.md > scratch/sw_sweep20_off_draft_v031.txt
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_tracker_v030.md > scratch/sw_sweep20_off_tracker_v030.txt
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_tracker_v031.md > scratch/sw_sweep20_off_tracker_v031.txt

# 5. Retired phrasing, cited commits, near-hits
grep -n -i "adaptive\|DifferentialEquations" scratch/sw_sweep20_draft_v031.md
for c in dd3cc6a a76c5e9 31ca00d eacf073 74cfef9 9cecee3 95c385d; do git merge-base --is-ancestor $c HEAD && echo "$c OK"; done
grep -n "driveshaft\|bridle\|cyan" scratch/sw_sweep20_draft_v031.md

# 6. Record section sim (the Register block flag found here was fixed before landing)
git show HEAD:docs/reporting/draft-consistency-sweep.md > scratch/sw_sweep20_record_base.md
cp scratch/sw_sweep20_record_base.md scratch/sw_sweep20_record_new.md
printf '\n' >> scratch/sw_sweep20_record_new.md
cat scratch/sw_sweep20_section.md >> scratch/sw_sweep20_record_new.md
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_record_base.md
python3 ste-lint.py --fail-above 2.0 scratch/sw_sweep20_record_new.md
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_record_base.md > scratch/sw_sweep20_off_record_base.txt
python3 $SK/scripts/lint-offenders.py ste-lint.py scratch/sw_sweep20_record_new.md > scratch/sw_sweep20_off_record_new.txt
python3 $SK/scripts/ste-chunks.py ste-lint.py scratch/sw_sweep20_record_base.md > scratch/sw_sweep20_chunks_record_base.txt
python3 $SK/scripts/ste-chunks.py ste-lint.py scratch/sw_sweep20_record_new.md > scratch/sw_sweep20_chunks_record_new.txt
