import csv
rows = [r for r in csv.DictReader(open("scratch/aw_k_perturb_2026-11-01.csv"))]
for k in ("2.24", "8.40", "8.90"):
    sub = [r for r in rows if r["k"] == k]
    if not sub:
        continue
    late = [r for r in sub if float(r["t_s"]) >= 90.0]
    def rng(key, data):
        vals = [float(r[key]) for r in data]
        return min(vals), max(vals)
    print("k", k, "samples", len(sub), "last t", sub[-1]["t_s"])
    print("  all: P %.3f-%.3f  wh %.3f-%.3f  tw %.3f-%.3f  fos %.3f-%.3f" % (
        *rng("P_kw", sub), *rng("omega_hub", sub), *rng("twist_ratio", sub), *rng("fos_min_ring", sub)))
    if late:
        print("  t>=90: P %.3f-%.3f  wh %.3f-%.3f  tw %.3f-%.3f  fos %.3f-%.3f" % (
            *rng("P_kw", late), *rng("omega_hub", late), *rng("twist_ratio", late), *rng("fos_min_ring", late)))
