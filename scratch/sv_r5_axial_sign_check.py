#!/usr/bin/env python3
"""sv_r5_axial_sign_check.py — science-validator seat.

Asserts the full basis for signing register row NR-060 (R5 signed axial force
at the winner capture): source blob identity, line pins at the code sites,
the probe log (parity, per-beam values, closure), the aero receipt's proposed
row transcription, and the landed register block. Prints SV_R5_AXIAL_CHECK_DONE
on full success and exits non-zero on any FAIL.
"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REG = REPO / "docs" / "reporting" / "numbers-register.md"
LOG = REPO / "scratch" / "sv_r5_axial_sign" / "sv_r5_axial_sign.log"
RECEIPT = ("docs/reporting/room-responses/"
           "aero-validator-2026-10-18-t3-physics-counterread.md")
LAUNCH = "a76c5e9"
BRANCH = "bank-derate-cos2p65"

# (path, line number, exact substring)
LINE_PINS = [
    ("src/ring_element_analysis.jl", 20,
     "    N::Float64   # axial compression (+ve = compressive, N)"),
    ("src/ring_element_analysis.jl", 239,
     "  N > 0 = compressive (positive compression)"),
    ("src/ring_element_analysis.jl", 272,
     "        N_ax = f_local[1]           # compression positive (f_local[1] > 0 when beam compressed)"),
    ("src/ring_element_analysis.jl", 636,
     "function ring_element_analysis("),
    ("src/sim_frame.jl", 391,
     "    ring_util_axial = Float64[]  # N/N_crit from worst-utilisation beam, per ring"),
    ("src/sim_frame.jl", 406,
     "            wA = max(worst.N, 0.0) / max(worst.N_crit, 1e-9)"),
    ("scripts/compute_seeds.jl", 36,
     "const K_MPPT_5KW_HONEST = 2.24"),
    ("scripts/extract_pair_capture.jl", 52,
     "    :fitness => 27.3635412663488,"),
]

PARITY_VALUES = {
    "fitness": "27.3635412663488",
    "P_mean": "5.3087794439367935",
    "P_end": "5.314113662272673",
    "FoS_min": "14.971791422208508",
    "util_a": "0.06679174086635262",
    "util_b": "5.334714158942919e-7",
    "T_lift": "324.1250954336462",
    "twist_ratio": "0.4393474253185575",
    "ω_eq": "10.169820334285198",
}

# Full-precision R5 values recorded at both seats (display forms in parentheses)
R5_NMIN = -157.62246416260894      # (-157.622 N)
R5_NMAX = -142.7923499969138       # (-142.792 N)
R5_SHMIN = -0.09240481892804314    # (-0.0924)
R5_SHMAX = -0.08371079157957116    # (-0.0837)
R5_NCRIT = 1705.7818627982122

PARITY_FIELDS = ["fitness", "P_mean", "P_end", "FoS_min", "util_a", "util_b",
                 "T_lift", "twist_ratio", "ω_eq"]

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


def blob(rev, path):
    return git("rev-parse", f"{rev}:{path}")


def main():
    # A. blob identity: launch == HEAD == origin for every pinned source file
    pinned = [p[0] for p in LINE_PINS]
    pinned += ["scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/"
               "island_3/best_vector.csv"]
    POST_LAUNCH = {
        "scripts/extract_pair_capture.jl",  # capture instrument, created 2026-10-08
        "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/best_vector.csv",
    }
    for p in pinned:
        b_h, b_o = blob("HEAD", p), blob(f"origin/{BRANCH}", p)
        check(b_h == b_o, f"blob HEAD==origin/{BRANCH} {p}")
        if p not in POST_LAUNCH:
            b_l = blob(LAUNCH, p)
            check(b_l == b_h, f"blob launch==HEAD {p}")

    # B. line pins at exact line numbers
    for p, ln, sub in LINE_PINS:
        lines = (REPO / p).read_text().splitlines()
        check(len(lines) >= ln and lines[ln - 1] == sub,
              f"line pin {p}:{ln} exact substring")

    # C. probe log: parity (per-field full line), ring census, R5 values, closure
    log = LOG.read_text()
    check("parity: BIT-EXACT ON ALL NINE FIELDS" in log, "log parity bit-exact")
    for f in PARITY_FIELDS:
        v = PARITY_VALUES[f]
        check(f"  {f:<12} got=" in log, f"log parity field {f}")
        line = f"  {f:<12} got={v} expected={v} |diff|=0.0 EXACT"
        check(line in log, f"log parity line exact for {f}")
    ring_lines = [l for l in log.splitlines() if l.startswith("R") and " N_min=" in l]
    check(len(ring_lines) == 5, f"log rings census == 5 ({len(ring_lines)})")
    r5 = [l for l in ring_lines if l.startswith("R5 |")][0]
    check(f"N_min={R5_NMIN!r}" in r5, "log R5 N_min full precision")
    check(f"N_max={R5_NMAX!r}" in r5, "log R5 N_max full precision")
    check(f"beams=3" in r5, "log R5 beams == 3")
    check(f"N/Ncrit_min={R5_SHMIN!r}" in r5, "log R5 share min full precision")
    check(f"N/Ncrit_max={R5_SHMAX!r}" in r5, "log R5 share max full precision")

    beams = [l for l in log.splitlines() if l.startswith("R5 beam ")]
    check(len(beams) == 3, f"log per-beam census == 3 ({len(beams)})")
    check(all(" N=" in b and b.split("|")[1].strip().startswith("N=-") for b in beams),
          "log all three R5 beams negative (tension)")
    for b in beams:
        n = float(b.split("N=")[1].split(" ")[0])
        nc = float(b.split("N_crit=")[1].split(" ")[0])
        sh = float(b.split("N/Ncrit=")[1].split(" ")[0])
        check(nc == R5_NCRIT, f"log N_crit shared across beams ({b.strip()[:40]})")
        check(sh - (n / nc) == 0.0, f"log closure N/Ncrit == N/N_crit bit-exact ({b.strip()[:40]})")
    check("SV_R5_AXIAL_DONE" in log, "log done token")

    # D. receipt transcription cross-check (the proposed row as seeded)
    rcpt = git("show", f"b0972c0:{RECEIPT}")
    check("-157.622 to -142.792" in rcpt, "receipt proposed range present")
    check("-0.0924 to -0.0837" in rcpt, "receipt proposed share range present")
    check("proposed (aero-validator, 2026-10-18)" in rcpt, "receipt proposed status present")

    # E. register block (worktree): heading, values, status, counter-read line
    reg = REG.read_text()
    check("## Source row: NR-060, R5 signed axial force at the winner capture "
          "(2026-10-18, science-validator)" in reg, "register NR-060 heading")
    check("This block appends only, under the amend pattern. No signed row changed."
          in reg, "register amend lead")
    check("-157.62246416260894" in reg and "-142.7923499969138" in reg,
          "register full-precision N values")
    check("-157.622 to -142.792 (tension)" in reg, "register display form N")
    check("-0.09240481892804314" in reg and "-0.08371079157957116" in reg,
          "register full-precision shares")
    check("-0.0924 to -0.0837" in reg, "register display form shares")
    check("three beams" in reg and "-148.87563768789266" in reg,
          "register three beams incl. middle beam")
    check("signed (science-validator, 2026-10-18)" in reg, "register signed status")
    check("Counter-read requested from the aero seat" in reg, "register counter-read line")
    check("parity bit-exact on nine recorded cold re-eval fields" in reg,
          "register parity basis")
    check("Compression positive" in reg, "register sign convention")
    check("## NR-060 amend: identity bullet names the wrong launch basis "
          "(2026-10-18, science-validator)" in reg, "register NR-060 amend heading")
    check("The winner CSV reads HEAD equals origin, and it first lands at the "
          "data commit `dd3cc6a`." in reg, "register NR-060 amend corrected line")
    check("## NR-020 note: the Cp pair names its banks (2026-10-18, science-validator)"
          in reg, "register NR-020 note heading")
    check("0.22540 reads the 20-degree bank and 0.26386 reads the 0-degree bank"
          in reg, "register NR-020 bank mapping")

    print(f"SV_R5_AXIAL_CHECK_DONE ({checks} checks, 0 fail)")


if __name__ == "__main__":
    main()
