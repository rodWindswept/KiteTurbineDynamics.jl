#!/usr/bin/env bash
# scratch/av_bow_readback.sh — the winner-bow landing readback (aero seat).
# Verifies local == origin for bank-derate-cos2p65 and byte-verifies every
# carried blob at origin (worktree sha256 against the origin blob).
set -euo pipefail
cd "$(dirname "$0")/.."
BRANCH=bank-derate-cos2p65

HEAD_LOCAL=$(git rev-parse HEAD)
HEAD_ORIGIN=$(git rev-parse "origin/$BRANCH")
echo "local  HEAD = $HEAD_LOCAL"
echo "origin HEAD = $HEAD_ORIGIN"
if [ "$HEAD_LOCAL" = "$HEAD_ORIGIN" ]; then
    echo "LOCAL == ORIGIN"
else
    echo "MISMATCH: local != origin"
    exit 1
fi

FILES=(
    docs/reporting/room-responses/aero-validator-2026-10-16-winner-bow-probe.md
    scratch/av_bow_read_supply.md
    scratch/av_bow_probe.jl
    scratch/av_bow_probe.log
    scratch/av_bow_probe_run1_buggy.log
    scratch/av_bow_probe_dbg.log
    scratch/av_bow_probe_interrupted_2026-10-15-sig15.log
    scratch/av_bow_ste_lint.log
)

fail=0
n=0
for f in "${FILES[@]}"; do
    a=$(sha256sum "$f" | awk '{print $1}')
    b=$(git show "origin/$BRANCH:$f" | sha256sum | awk '{print $1}')
    n=$((n + 1))
    if [ "$a" = "$b" ]; then
        echo "OK   $f  $a"
    else
        echo "FAIL $f  worktree=$a  origin=$b"
        fail=1
    fi
done

if [ "$fail" = "0" ]; then
    echo "ALL $n CARRIED BLOBS BYTE-VERIFIED AT ORIGIN"
else
    exit 1
fi
