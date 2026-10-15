#!/usr/bin/env python3
# sv_rb_postfix_check.py — the post-fix warm register read (science-validator, 2026-10-15).
# Recomputes the census, the settle rate, the window-mean reconstruction bounds
# and the blob binds from the extract trace bytes; cross-checks the header lines,
# the extract log and the stock-probe log forms; checks the register rows landed.
# stdlib only. Run from the repo root: python3 scratch/sv_rb_postfix_check.py
import bisect, hashlib, re, sys

EXTRACT = "scratch/av_rb_warm_extract"
EXTRACT_LOG = "scratch/av_rb_warm_extract.log"
PROBE_LOG = "scratch/av_rb_stock_probe.log"
REGISTER = "docs/reporting/numbers-register.md"

ISLANDS = {
    1: dict(file=f"{EXTRACT}/island_1_warm_10ms.csv", rows=4999,
            blob="770d937743948763e56715e5baade154fe179941"),
    2: dict(file=f"{EXTRACT}/island_2_warm_10ms.csv", rows=4992,
            blob="05fb874b0aa0c756570935e1e50039305ebaac39"),
    3: dict(file=f"{EXTRACT}/island_3_warm_10ms.csv", rows=5000,
            blob="3b39f063c286a58d865bc3c7234cf625ee31244d"),
}

checks = []
def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))

def git_blob_sha(path):
    data = open(path, "rb").read()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()

def interp(t, p, x):
    i = bisect.bisect_left(t, x)
    if i == 0: return p[0]
    if i >= len(t): return p[-1]
    t0, t1, p0, p1 = t[i-1], t[i], p[i-1], p[i]
    w = 0.0 if t1 == t0 else (x - t0) / (t1 - t0)
    return p0 + w * (p1 - p0)

def bracket_bound(t, p, x):
    i = bisect.bisect_left(t, x)
    if i == 0 or i >= len(t): return 0.0
    return abs(p[i] - p[i-1]) / 2.0

# --- the extract log forms ---
log_txt = open(EXTRACT_LOG).read()
probe_txt = open(PROBE_LOG).read()

results = {}
for isl, meta in sorted(ISLANDS.items()):
    h, t, wg, wh, p, brk = {}, [], [], [], [], []
    for line in open(meta["file"]):
        if line.startswith("#"):
            if "P_mean=" in line:
                for tok in line.strip().split():
                    if "=" in tok:
                        k, v = tok.split("=", 1)
                        h[k] = v
            continue
        if line.startswith("t,"): continue
        parts = line.strip().split(",")
        t.append(float(parts[0])); wg.append(float(parts[1])); wh.append(float(parts[2]))
        p.append(float(parts[3])); brk.append(float(parts[4]))

    hm, hp, hw = float(h["P_mean"]), float(h["P_end"]), float(h["omega_eq"])
    check(f"i{isl}: header status reads reject", h.get("status") == "reject", h.get("status",""))
    check(f"i{isl}: header line_broken reads false", h.get("line_broken") == "false", h.get("line_broken",""))
    check(f"i{isl}: row count {len(t)} == log count {meta['rows']}", len(t) == meta["rows"])
    check(f"i{isl}: run reaches about 50 s (t_last={t[-1]:.6f})", t[-1] >= 49.98)
    check(f"i{isl}: trace starts at t<0.001", t[0] < 0.001, f"{t[0]:.6f}")
    check(f"i{isl}: latch census zero", sum(brk) == 0, f"sum={sum(brk):.0f}")
    check(f"i{isl}: omega_eq at trace start (gnd {wg[0]:.4f} / hub {wh[0]:.4f} / hdr {hw:.4f})",
          abs(wg[0]-hw) <= 0.01 and abs(wh[0]-hw) <= 0.01)

    grid40 = [11.0 + k for k in range(40)]
    mean_grid = sum(interp(t, p, x) for x in grid40) / 40.0
    bound40 = sum(bracket_bound(t, p, x) for x in grid40) / 40.0
    d_mean = mean_grid - hm
    check(f"i{isl}: P_mean recon within bound ({d_mean:+.4f} vs bound {bound40:.4f})",
          abs(d_mean) <= bound40)

    tail_x = [46.0, 47.0, 48.0, 49.0, 50.0]
    tail_rec = sum(interp(t, p, x) for x in tail_x) / 5.0
    bound_tail = sum(bracket_bound(t, p, x) for x in tail_x)
    d_end = tail_rec - hp
    check(f"i{isl}: P_end recon within bound ({d_end:+.4f} vs bound {bound_tail:.4f})",
          abs(d_end) <= bound_tail)

    m = re.search(rf"island {isl} \| reject \| false \| +([\d.]+) \| +([\d.]+) \| +([\d.]+) \| +\S+ \| +([\d.]+) \| ([\d.]+)", log_txt)
    check(f"i{isl}: extract log line parses", m is not None)
    if m:
        lp, le, lf, lw, lt = (float(g) for g in m.groups())
        check(f"i{isl}: log P_mean {lp} == header 3dp {round(hm,3)}", abs(lp - round(hm,3)) <= 0.0005)
        check(f"i{isl}: log P_end {le} == header 3dp {round(hp,3)}", abs(le - round(hp,3)) <= 0.0005)
        check(f"i{isl}: log omega_eq {lw} == header 3dp {round(hw,3)}", abs(lw - round(hw,3)) <= 0.0005)
        check(f"i{isl}: log FoS/twist forms {lf}/{lt}", abs(lf) > 0.0 and abs(lt) > 0.0)

    pm = re.search(rf"warm +\| +{isl} +\| +([\d.]+) \| +([\d.]+) \| +([\d.]+) \| +\S+ \| +\S+ \| +([\d.]+) .* broken=false \| reject", probe_txt)
    check(f"i{isl}: stock probe warm row parses (reject/broken=false)", pm is not None)
    if pm:
        pp, pe, pf, pw = (float(g) for g in pm.groups())
        check(f"i{isl}: probe P_mean {pp} == header 3dp {round(hm,3)}", abs(pp - round(hm,3)) <= 0.0005)
        check(f"i{isl}: probe P_end {pe} == header 3dp {round(hp,3)}", abs(pe - round(hp,3)) <= 0.0005)

    bsha = git_blob_sha(meta["file"])
    check(f"i{isl}: blob bind {bsha[:8]} == pinned {meta['blob'][:8]}", bsha == meta["blob"])
    results[isl] = dict(d_mean=d_mean, d_end=d_end, bound40=bound40, bound_tail=bound_tail,
                        wg0=wg[0], wh0=wh[0], hm=hm, hp=hp, hw=hw, rec_mean=mean_grid, rec_end=tail_rec)

# --- the register rows landed ---
reg = " ".join(open(REGISTER).read().split())
check("register carries the NR-013 ext2 row", "NR-013 ext2" in reg)
check("register carries the post-fix warm block title", "post-fix warm runs, the three winners (2026-10-15, science-validator)" in reg)
check("register carries the NR-025 post-fix quote form", '"the rope-break check armed at the window"' in reg)
check("register carries the arm-time form", "breaks_arm_s = cfg.relax_s" in reg)

fails = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
print()
print("SUMMARY")
for isl, r in results.items():
    print(f"  island {isl}: P_mean recon {r['rec_mean']:.6f} vs header {r['hm']:.6f} (delta {r['d_mean']:+.4f}, bound {r['bound40']:.4f})")
    print(f"           P_end  recon {r['rec_end']:.6f} vs header {r['hp']:.6f} (delta {r['d_end']:+.4f}, bound {r['bound_tail']:.4f})")
    print(f"           omega_eq first-row gnd {r['wg0']:.4f} hub {r['wh0']:.4f} vs header {r['hw']:.4f}")
print(f"checks: {len(checks)} | failures: {len(fails)}")
sys.exit(1 if fails else 0)
