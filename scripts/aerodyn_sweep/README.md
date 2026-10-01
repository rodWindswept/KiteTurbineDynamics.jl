# AeroDyn sweeps

Reproduce the two AeroDyn v5.0.0 reference sweeps that back
`docs/validation/trpt-reference/10-precone-sweep.md` and `11-blade-count-sweep.md`.

Moved here 2026-10-01 from `.scratch/bem_regression/precone_sweep/`, which `.gitignore`
excludes. Before the move no fresh clone could reproduce either sweep, and the CSV
provenance headers pointed at a path that did not exist.

## The scripts

| Script | What it does |
|---|---|
| `gen_precone_drivers.py` | writes the 84 precone and yaw AeroDyn driver files |
| `run_sweep.py` | runs them through the driver |
| `parse_sweep.py` | builds the table and writes `results/sweep.csv` |
| `plot_sweep.py` | renders the precone figure |
| `gen_bladecount_drivers.py` | writes the blade-count driver files |
| `run_bladecount.py` | runs them |
| `parse_bladecount.py` | builds the table and writes `results/bladecount.csv` |
| `plot_bladecount.py` | renders the blade-count figure |
| `stamp_reference_csvs.py` | writes the provenance header onto the reference CSVs |

## Where the data lives

The working directory is not in git. It holds `deck/` (the generated drivers, about
94 MB) and `results/` (raw outputs and figures). It defaults to the historical
location and is overridable:

```
AERODYN_SWEEP_WORK=/tmp/sweep python3 scripts/aerodyn_sweep/run_sweep.py
```

The AeroDyn input templates come from the NAS knowledge directory and are overridable
with `AERODYN_DECK`. The driver binary is `~/bin/aerodyn_driver`.

## Two traps

**The two sweeps share one deck directory.** Blade-count driver files are named
`ad_b6c*_pc*.out` and contain the substring `_pc`. A parser that selects by substring
reads one sweep as the other. Both parsers now anchor on the driver prefix: `ad_pc*`
and `ad_yw*` for precone and yaw, `ad_b6c*` for blade count. Re-parsing a deck
directory that holds only one sweep now reports no outputs for the other, which is the
truth rather than a fault.

**A re-parse does not prove reproduction unless the raw outputs are present.**
`11-blade-count-sweep.csv` reproduces byte-identically from the outputs on disk.
`10-precone-sweep.csv` does not, because the precone and yaw raw outputs are no longer
there. Run `run_sweep.py` to restore them.

## Column lookup

AeroDyn output columns must be looked up by name, never by index. The positions differ
between decks, and hard-coded indices have already produced a wrong reading in this
repo.
