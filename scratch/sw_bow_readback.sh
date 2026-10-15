#!/usr/bin/env bash
# Readback: the bow row train (science-writer seat).  Compares the sha256 of
# every carried blob in the worktree against the blob at origin, byte for byte.
set -uo pipefail
cd "$(dirname "$0")/.."
BR=bank-derate-cos2p65

FILES=(
  docs/reporting/glossary-candidates.md
  docs/reporting/room-responses/science-writer-2026-10-15-bow-row-landing.md
  scratch/sw_bptr_supply.md
  scratch/sw_bow_supply.md
  scratch/sw_bow_fold.py
  scratch/sw_bow_fold.log
  scratch/sw_bow_check.py
  scratch/sw_bow_check.log
  scratch/sw_bow_ste_variants.py
  scratch/sw_bow_ste_variants.log
  scratch/sw_bow_off_base.txt
  scratch/sw_bow_off_new.txt
  scratch/sw_bow_base.md
  scratch/sw_bow_new.md
)

echo "readback  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "local HEAD $(git rev-parse HEAD)"
echo "origin     $(git ls-remote origin "$BR" | cut -f1)"
echo "range      6b6a0e1..$(git rev-parse --short HEAD)"
echo

PASS=0
FAIL=0
for f in "${FILES[@]}"; do
  a=$(sha256sum "$f" | cut -d' ' -f1)
  b=$(git cat-file blob "origin/$BR:$f" | sha256sum | cut -d' ' -f1)
  if [ "$a" = "$b" ]; then
    echo "ok    $f"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $f  worktree $a  origin $b"
    FAIL=$((FAIL + 1))
  fi
done

echo
echo "$PASS of ${#FILES[@]} carried blobs byte-verified at origin, $FAIL mismatch"
echo
echo "commits in the range:"
git log --oneline "6b6a0e1..HEAD"
