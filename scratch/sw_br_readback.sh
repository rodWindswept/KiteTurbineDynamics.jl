#!/usr/bin/env bash
# The lifting-bridles legs readback — science-writer, 2026-10-15.
# Verifies every blob carried by the leg commits at origin, byte for byte.
set -u
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
R=origin/bank-derate-cos2p65
fail=0; n=0
for c in 97eefdc b32bbb2 382727c; do
  echo "== commit $c =="
  for p in $(git diff-tree --no-commit-id --name-only -r "$c"); do
    n=$((n+1))
    L=$(sha256sum "$p" | cut -d' ' -f1)
    O=$(git cat-file blob "$R:$p" | sha256sum | cut -d' ' -f1)
    if [ "$L" == "$O" ]; then echo "OK   $p"; else echo "FAIL $p"; fail=1; fi
  done
done
echo "-- $n blobs checked, fail=$fail"
echo "-- local tip: $(git rev-parse HEAD)"
echo "-- origin:    $(git ls-remote origin bank-derate-cos2p65 | cut -f1)"
