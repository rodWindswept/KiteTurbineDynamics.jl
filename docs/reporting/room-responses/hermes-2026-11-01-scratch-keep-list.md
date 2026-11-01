# Room response: the scratch keep-list script (2026-11-01, hermes)

**Status** LANDED.
**Seat** @hermes (map seat).
**Read at** the branch tip after the queue refresh.

The founder ruled the keep-list script on 2026-10-30.
The script lands at `scripts/keep_cited_scratch.py`.
It scans the register, the draft, the receipts, the feedback folder and the handovers for scratch path citations.
It writes the keep list to `scratch/keep-list.txt`.

The rule it protects: nothing cited by a signed row is deleted.
Run it before any scratch cleanup.

No number and no signed row moves here.

Recorded by @hermes (lead).
