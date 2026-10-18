#!/usr/bin/env python3
"""sv_nr046_repin_check.py — science-validator seat.

Asserts the NR-046 re-pin amend: the old pin blob equals the launch blob for
objective_evaluator.jl only, the HEAD blob and the corrected line pins read as
the amend states, the other NR-046 pinned files did not move since the sign,
and the landed register block carries the corrected reading.
"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REG = REPO / "docs" / "reporting" / "numbers-register.md"
SIGN_TIP = "7b8c101"   # the tip the row was read at (register source cell)

PINS = [
    (90, "const STATIONARITY_LAMBDA = 10.0"),
    (91, "const STATIONARITY_SWING = 0.20   # matches the gate's P_range/P_mean < 0.20"),
    (1153, "    P_score = cfg.power_stat === :tail5 ? P_end : P_mean"),
    (1166, "    fitness = fitness_fn(P_score, FoS_min, cfg, m_airborne)"),
    (1197, "    swing = P_mean > 0.1 ? P_range / P_mean : 0.0"),
    (1198, "    excess = max(0.0, swing - STATIONARITY_SWING)"),
    (1199, "    fitness = fitness + STATIONARITY_LAMBDA * excess"),
    (1205, "    if twist_ratio_max[] > 0.0"),
    (1206, "        tr = min(twist_ratio_max[], 1.0)"),
    (1207, "        fitness = fitness + W_TWIST_KG * (tr / max(1.0 - tr, 1e-6))^2"),
    (1208, "    end"),
]

OTHER_PINNED = [
    "src/objective_v12.jl",
    "scripts/run_v13_5kw_masslift.jl",
]

checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        print(f"FAIL: {label}")
        sys.exit(1)
    print(f"ok: {label}")


def git(*args):
    return subprocess.run(["git", "-C", str(REPO), *args],
                          capture_output=True, text=True).stdout.strip()


def main():
    f = "src/objective_evaluator.jl"
    head_blob = git("rev-parse", f"HEAD:{f}")
    launch_blob = git("rev-parse", f"a76c5e9:{f}")
    sign_blob = git("rev-parse", f"{SIGN_TIP}:{f}")
    check(head_blob == "5c626ff56dfd026cf0e3040c68f246bf55e4c885",
          "HEAD blob reads 5c626ff5")
    check(launch_blob == "52669d40342c46df4d575eb092acaf1d0f0e177f",
          "launch blob reads 52669d40 (the old pin)")
    check(sign_blob == launch_blob, "the sign-time blob equaled the launch blob")

    lines = (REPO / f).read_text().splitlines()
    for ln, sub in PINS:
        check(lines[ln - 1] == sub, f"line pin {f}:{ln} exact substring")

    for p in OTHER_PINNED:
        b_sign = git("rev-parse", f"{SIGN_TIP}:{p}")
        b_head = git("rev-parse", f"HEAD:{p}")
        check(b_sign == b_head, f"unmoved since sign: {p}")

    reg = REG.read_text()
    check("## NR-046 amend: evaluator line pins re-pin past 2bf76a3 "
          "(2026-10-18, science-validator)" in reg, "register amend heading")
    check("This block appends only, under the amend pattern. No signed row changed."
          in reg, "register amend lead")
    check("`src/objective_evaluator.jl:90-91, 1148, 1161, 1192-1194, 1200-1203`"
          in reg, "register quotes the old pin")
    check("`src/objective_evaluator.jl:90-91, 1153, 1166, 1197-1199, 1205-1208`"
          in reg, "register corrected pin")
    check("at blob `5c626ff5`" in reg, "register corrected blob")
    check("No draft change" in reg, "register draft-holds line")
    check("The signed values stand byte-identical" in reg,
          "register values-stand line")

    print(f"SV_NR046_REPIN_CHECK_DONE ({checks} checks, 0 fail)")


if __name__ == "__main__":
    main()
