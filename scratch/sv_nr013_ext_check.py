#!/usr/bin/env python3
"""NR-013 extension evidence checker (science-validator, 2026-10-12).

Re-derives the two lane-3 strain annotations (F3 plate, row 4) from the
committed extract files. Read-only. Exit 0 on pass.
"""
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
EX = ROOT / "docs/reporting/figures/eval-timeline-extract"
WARM = EX / "extract-eval-timeline-warm.csv"
RUL = EX / "extract-eval-timeline-warm-rulingmode.csv"

fails = []


def check(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")
    if not ok:
        fails.append(name)


def rows(path):
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            out.append(line.split(","))
    return out[0], out[1:]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# ---------- warm leg (as coded) ----------
head, warm = rows(WARM)
check("warm cols", head == ["t", "omega_gnd", "omega_hub", "P_gen_kw",
                            "tau_gen_Nm", "strain_max_over_break", "any_broken"],
      str(head))
check("warm rows == 98", len(warm) == 98, f"n={len(warm)}")

last = warm[-1]
t_last = float(last[0])
s_last = float(last[5])
check("warm last t == 0.002841", abs(t_last - 0.002841) < 1e-9, f"t={t_last!r}")
check("warm last strain quote 1.00081", f"{s_last:.5f}" == "1.00081",
      f"{s_last:.9f}")

broken = [i + 1 for i, r in enumerate(warm) if r[6].strip() == "1"]
check("warm latch reads only at the last step", broken == [98], str(broken))

s97 = float(warm[96][5])
t97 = float(warm[96][0])
check("warm step-97 crossing 1.00028", f"{s97:.5f}" == "1.00028"
      and abs(t97 - 0.002812) < 1e-9, f"s97={s97:.9f} t={t97!r}")

# ---------- ruling mode (condition run) ----------
head, rul = rows(RUL)
check("ruling cols", head == ["t", "omega_gnd", "omega_hub", "P_gen_kw",
                              "strain_max_over_break", "any_broken"], str(head))
check("ruling rows == 1823", len(rul) == 1823, f"n={len(rul)}")

t_r = [float(r[0]) for r in rul]
s_r = [float(r[4]) for r in rul]
imax = s_r.index(max(s_r))
check("ruling grid max 1.44798 at t = 0.005798",
      f"{s_r[imax]:.5f}" == "1.44798" and abs(t_r[imax] - 0.005798) < 1e-9,
      f"max={s_r[imax]:.9f} t={t_r[imax]!r}")
check("ruling max quote 1.448", f"{s_r[imax]:.3f}" == "1.448",
      f"{s_r[imax]:.9f}")

check("ruling run completes 50 s", abs(t_r[-1] - 49.999995) < 1e-6,
      f"t_last={t_r[-1]!r}")
check("ruling no latch in window", all(r[5].strip() == "0" for r in rul),
      "any_broken all 0")

late = [s for t, s in zip(t_r, s_r) if t >= 0.06]
check("ruling nothing past 60 ms exceeds 0.677081",
      abs(max(late) - 0.677080915) < 1e-9, f"max={max(late):.9f} n={len(late)}")

win = [(float(r[1]), float(r[3]), float(r[4])) for r in rul if float(r[0]) >= 10.0]
wg = [w[0] for w in win]
P = [w[1] for w in win]
ws = [w[2] for w in win]
check("ruling window mean omega_gnd 12.639282",
      f"{sum(wg)/len(wg):.6f}" == "12.639282", f"{sum(wg)/len(wg):.9f}")
check("ruling window mean P 4.958894",
      f"{sum(P)/len(P):.6f}" == "4.958894", f"{sum(P)/len(P):.9f}")
check("ruling window strain max 0.449417",
      f"{max(ws):.6f}" == "0.449417", f"{max(ws):.9f}")
check("ruling window n == 1381", len(win) == 1381, f"n={len(win)}")

# ---------- integrity pins ----------
sw = sha(WARM)
sr = sha(RUL)
check("warm sha256 pin", sw == "7eb2f44cb476d1dbadd69684826f287ff446a3973590488bb6fe844b97b68e7d", sw)
check("ruling sha256 pin", sr == "3abcaeba0d1a01e772a7c525c4bc4ba65ef03bf01538c9bf0e442f9aebfaa4ee", sr)

print()
if fails:
    print(f"RESULT: FAIL ({len(fails)} of the checks failed): {fails}")
    raise SystemExit(1)
print("RESULT: PASS (all checks)")
