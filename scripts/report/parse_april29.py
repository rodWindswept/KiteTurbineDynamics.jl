#!/usr/bin/env python3
# parse_april29.py — stdlib-only parser for the 2021 merged workbook:
# extracts anemometer wind, SRM power, cadence, controller rpm, tip speed
# into scripts/results/april29_anchor.csv + wind-binned stats.
import csv, re, sys, zipfile

XLSX = "/home/rod/Documents/kites/Test Data/2020 April 29 Mast Mount 6 rotor test/29 April 2020 all data and analysis.xlsx"
OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/april29_anchor.csv"

z = zipfile.ZipFile(XLSX)
# shared strings — concatenate rich-text runs within each <si> entry
try:
    ss = z.read("xl/sharedStrings.xml").decode("utf-8", "replace")
    shared = []
    for si in re.findall(r"<si>(.*?)</si>", ss, re.S):
        runs = re.findall(r"<t[^>]*>([^<]*)</t>", si)
        shared.append("".join(runs))
except KeyError:
    shared = []
print("shared strings:", len(shared), "| anem present:", "anem" in " ".join(shared))
# use the largest data sheet
sheets = [n for n in z.namelist() if re.match(r"xl/worksheets/sheet\d+\.xml", n)]
sizes = {s: z.getinfo(s).file_size for s in sheets}
target = max(sizes, key=sizes.get)
print("data sheet:", target)
body = z.read(target).decode("utf-8", "replace")

# decode: cells are <c r="A1" t="s"><v>idx</v></c> or <c r="A1"><v>num</v></c>
# — attribute order varies, so parse attrs separately
rows = {}
for m in re.finditer(r"<c([^>]*)>(?:<v>([^<]*)</v>)?</c>", body):
    attrs, v = m.group(1), m.group(2)
    r = re.search(r'r="([A-Z]+)(\d+)"', attrs)
    t = re.search(r't="(\w+)"', attrs)
    if not r or v is None:
        continue
    col, rn = r.group(1), int(r.group(2))
    val = shared[int(v)] if (t and t.group(1) == "s" and v.isdigit() and int(v) < len(shared)) else v
    rows.setdefault(rn, {})[col] = val

def colnum(c):
    n = 0
    for ch in c:
        n = n * 26 + ord(ch) - 64
    return n

maxcol = max((colnum(c) for row in rows.values() for c in row), default=0)
def rowvals(r):
    return [rows[r].get(chr(64 + i), "") for i in range(1, maxcol + 1)]

hdr = rowvals(min(rows))
print("header:", hdr)
idx = {h.strip().lower(): i for i, h in enumerate(hdr)}
def find(*keys):
    for k in keys:
        for h, i in idx.items():
            if k in h:
                return i
    return None
i_wind = find("anem")
i_pow = find("power")
i_cad = find("cadence")
i_rpm = find("rpm")
i_tip = find("tip")
print("col idx:", i_wind, i_pow, i_cad, i_rpm, i_tip)

out = []
for r in sorted(rows):
    if r == min(rows):
        continue
    vals = rowvals(r)
    try:
        wind = float(vals[i_wind]) if i_wind is not None else float("nan")
        p = float(vals[i_pow]) if i_pow is not None else float("nan")
        cad = float(vals[i_cad]) if i_cad is not None else float("nan")
        rpm = float(vals[i_rpm]) if i_rpm is not None else float("nan")
        tip = float(vals[i_tip]) if i_tip is not None else float("nan")
    except (ValueError, IndexError):
        continue
    if wind > 0 and p > 0:
        out.append((wind, p, cad, rpm, tip))

with open(OUT, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["wind_ms", "power_w", "cadence", "con_rpm", "tip_ms"])
    w.writerows(out)
print("rows written:", len(out))

# wind-binned stats
bins = {}
for wind, p, cad, rpm, tip in out:
    b = int(wind // 0.5) * 0.5 + 0.25
    bins.setdefault(b, []).append(p)
print("wind_bin | n | P_mean | P_std")
for b in sorted(bins):
    ps = bins[b]
    print(f"{b:7.2f} | {len(ps):4d} | {sum(ps)/len(ps):7.1f} | "
          f"{(sum((x - sum(ps)/len(ps))**2 for x in ps)/len(ps))**0.5:6.1f}")
