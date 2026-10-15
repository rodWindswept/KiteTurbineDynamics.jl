#!/usr/bin/env python3
"""av_conv_series.py — island running-best series extract (Harris 3.5 #4, the convergence figure).

Source: scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv
Rule (the strip-extract rule, 2026-10-09, reused verbatim): best-so-far at generation G =
minimal recorded fitness among ok rows with gen <= G; ties -> earliest (gen, idx);
no interpolation, no reconstruction.

Outputs: scratch/av_conv_series.csv (islands 1-3, gens 0..30); full log to stdout.
Parity: island 3 milestones must reproduce NR-036 at gens [0, 6, 10, 18, 22, 25, 26].
"""
import csv
import hashlib
import io
from datetime import datetime, timezone

BASE = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
MILESTONES = [0, 6, 10, 18, 22, 25, 26]
EXPECT3 = [36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364]
STRIP_ISL3_SHA = "34d40e8ea960a1e04c83df58df9e24047cfcf7eb3deff3278807f1147b8d60b0"
STRIP_OK3 = 194


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_telemetry(path):
    comments, data_lines = [], []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#"):
                comments.append(line.rstrip("\n"))
            elif line.strip():
                data_lines.append(line)
    reader = csv.DictReader(io.StringIO("".join(data_lines)))
    return comments, list(reader)


def running_best(rows, n_gen=31):
    ok_by_gen = {}
    for r in rows:
        if r["status"] == "ok":
            ok_by_gen.setdefault(int(r["gen"]), []).append(r)
    best = None
    series = []
    for g in range(n_gen):
        for r in ok_by_gen.get(g, []):
            fit = float(r["fitness"])
            if best is None or fit < best[0]:
                best = (fit, int(r["gen"]), int(r["idx"]))
        if best is None:
            raise SystemExit(f"no ok rows at or before gen {g}: series undefined")
        series.append((g, *best))
    return series


stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(f"av_conv_series — island running-best series extract (Harris 3.5 #4)")
print(f"generated: {stamp}  seat: aero-validator")
print(f"dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2")
print(f"rule: best-so-far at gen G = minimal recorded fitness among ok rows, gen <= G;")
print(f"      ties -> earliest (gen, idx); no interpolation, no reconstruction")
print()

series_all = {}
hashes = {}
for isl in (1, 2, 3):
    path = f"{BASE}/island_{isl}/telemetry.csv"
    comments, rows = read_telemetry(path)
    series = running_best(rows)
    n_ok = sum(1 for r in rows if r["status"] == "ok")
    digest = sha256(path)
    hashes[isl] = digest
    series_all[isl] = series
    print(f"island {isl}: rows={len(rows)} ok={n_ok} sha256={digest}")
    for line in comments:
        print(f"  {line}")
    for g, fit, bg, bi in series:
        print(f"  gen {g:2d}: best={fit!r:<14} from (gen {bg}, idx {bi})")
    print()

# --- parity: island 3 vs the strip extract / NR-036 ---
s3 = series_all[3]
ok = True
print("PARITY — island 3 milestones vs NR-036 [0, 6, 10, 18, 22, 25, 26] -> "
      "[36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364]")
got3 = [s3[g][1] for g in MILESTONES]
for g, want, got in zip(MILESTONES, EXPECT3, got3):
    mark = "PASS" if abs(got - want) < 1e-9 else "FAIL"
    ok &= mark == "PASS"
    print(f"  gen {g:2d}: want {want}  got {got}  {mark}")
print(f"  island 3 telemetry sha256 matches strip-extract input: "
      f"{'PASS' if hashes[3] == STRIP_ISL3_SHA else 'FAIL'}")
ok &= hashes[3] == STRIP_ISL3_SHA
n_ok3 = sum(1 for r in read_telemetry(f'{BASE}/island_3/telemetry.csv')[1] if r['status'] == 'ok')
print(f"  island 3 ok count matches strip extract (194): "
      f"{'PASS' if n_ok3 == STRIP_OK3 else 'FAIL'} (got {n_ok3})")
ok &= n_ok3 == STRIP_OK3
print()

# --- final values + the 11.7-12.0% heavier cross-check ---
f1, f2, f3 = (series_all[i][30][1] for i in (1, 2, 3))
print(f"final best-so-far (gen 30): island 1 = {f1}, island 2 = {f2}, island 3 = {f3}")
print(f"island 1 vs 3: +{100 * (f1 / f3 - 1):.1f}%   island 2 vs 3: +{100 * (f2 / f3 - 1):.1f}%")
print()

# --- write the extract ---
out_path = "scratch/av_conv_series.csv"
with open(out_path, "w") as fh:
    fh.write("# av_conv_series.csv — island running-best search objective, generations 0..30 (Harris 3.5 #4)\n")
    fh.write(f"# generated: {stamp} (aero-validator seat)\n")
    fh.write(f"# source: {BASE}/island_{{1,2,3}}/telemetry.csv\n")
    fh.write(f"# sha256 island_1 {hashes[1]} | island_2 {hashes[2]} | island_3 {hashes[3]}\n")
    fh.write("# rule: best-so-far at gen G = minimal recorded fitness among ok rows with gen <= G; ties -> earliest (gen, idx); no interpolation, no reconstruction (strip-extract rule, 2026-10-09)\n")
    fh.write("island,gen,best_fitness,best_source_gen,best_source_idx\n")
    for isl in (1, 2, 3):
        for g, fit, bg, bi in series_all[isl]:
            fh.write(f"{isl},{g},{fit},{bg},{bi}\n")
print(f"wrote {out_path} ({(31 * 3)} data rows)")
print(f"OVERALL: {'ALL PASS' if ok else 'FAIL'}")
raise SystemExit(0 if ok else 1)
