#!/usr/bin/env python3
# sv_sv7_audit_check.py — science-validator seat, 2026-10-13.
# SV7 audit gate: the failure-ledger dates and the era-map anchors.
# Reads committed bytes and the git record only. Checks:
#   A. six ledger dates against the commit record (named commits + dates);
#   B. the record strings (trust log rows, DECISIONS headings, draft §4.2);
#   C. the era anchors (NR-019/020/027/028, the register header, the stamps);
#   D. the system-anatomy note read at ee708d7 (NR-043 citations, no plate bytes).
# Exit 0 = every check passes. Log travels beside as sv_sv7_audit_check.log.
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
FAILS = []


def chk(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail else ""))
    if not ok:
        FAILS.append(name)


def norm(text):
    return re.sub(r"\s+", " ", text)


def read(rel):
    return (REPO / rel).read_text()


def git(*args):
    r = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True)
    return r.stdout.strip()


def commit_date(sha):
    return git("show", "-s", "--format=%cs", sha)


trust = norm(read("docs/agents/instrument-trust-log.md"))
decisions = norm(read("DECISIONS.md"))
draft = norm(read("docs/reporting/drafts/2026-10-08-report-first-draft.md"))
register = norm(read("docs/reporting/numbers-register.md"))
glossary = norm(read("docs/reporting/glossary-candidates.md"))
note = norm(read("docs/reporting/figures/system-anatomy/register-status.md"))
fmap = norm(read("docs/reporting/figures/figure-map.md"))
captions = read("docs/reporting/figures/system-anatomy/captions.md")

# A. dates against the commit record
dates = {
    "7183f96": "2026-08-14",  # entry 1: hub-sanity reject
    "542e148": "2026-08-15",  # entry 1: tip-speed sanity + r_hub lo 0.7, "Rod 2026-08-14"
    "828668d": "2026-08-26",  # entry 2: off-by-one fix
    "fe8ec77": "2026-08-26",  # entry 2: visual geometry check
    "bdc9ae7": "2026-08-22",  # entry 3: unified blade-mass law
    "807efa6": "2026-08-23",  # entry 3: decoded-span pricing, winners VOID
    "f9f31ec": "2026-08-14",  # entry 4: evaluator v13 landing (no 08-13 commits)
    "026c734": "2026-08-24",  # entry 5: re-gate at k=2.24
    "402697b": "2026-08-22",  # entry 6: FoS guard in all fitness functions
    "94223eb": "2026-10-01",  # era 2: bank-derate ruling
    "b835ebc": "2026-10-07",  # era 2: projection threading
    "95c385d": "2026-10-07",  # era 4: one wind authority
}
for sha, want in dates.items():
    got = commit_date(sha)
    chk(f"commit {sha} = {want}", got == want, f"got {got}")

empty = git("log", "--all", "--format=%cs",
            "--since=2026-08-13T00:00", "--until=2026-08-14T00:00")
chk("no commits dated 2026-08-13", empty == "", f"[{empty}]")

# B. the record strings
chk("trust log row 08-14", "| 2026-08-14 | **Hub-ring numerical divergence" in trust)
chk("trust log row 08-26", "| 2026-08-26 | **Rotor→system-ring" in trust)
chk("trust log row 08-13", "| 2026-08-13 | **Evaluator tested 5 kW designs" in trust)
chk("trust log row 08-24", "| 2026-08-24 | **Winner re-gate ran at a stale k_mppt" in trust)
chk("trust log row 08-22", "| 2026-08-22 | **Non-finite FoS passes the mass-min floor" in trust)
chk("trust log 1.94", "(p.k_mppt ≈ 1.94)" in trust)
chk("trust log 5.18", "P_gen 5.18 kW flat" in trust)
chk("DECISIONS unified law heading",
    "## [2026-08-22] Unified blade-mass law: m = m_ref · λ³ + knuckle floor" in decisions)
chk("DECISIONS corrected heading",
    "## [2026-08-22] Blade-mass law CORRECTED to price the decoded span (winners exploit; campaign VOID)"
    in decisions)
chk("DECISIONS evaluator v13 heading",
    "## [2026-08-13] Evaluator v13 — the test that identifies realistic KTD designs" in decisions)
chk("DECISIONS wind standard heading",
    "## [2026-10-03] The site wind standard — one measured profile, one exponent (D1)" in decisions)
for s in (
    "The blade-mass-law correction landed on 2026-08-22.",
    "On 2026-08-13 the evaluator ran 5-kilowatt designs at the 50-kilowatt default gain.",
    "The scaled system gain sat near 1.94.",
    "The re-gate at the campaign gain returned 5.18 kilowatts.",
    "Telemetry shows no surviving design carried the infinite value.",
    "a gate must pin a measured number, so drift fails the suite.",
    "An off-by-one in the rotor-to-ring map put the middle rotor on the hub (2026-08-26).",
    "An inverted-taper genome diverged within seconds",
    "void the data, keep the record",
    "The pre-derate campaign stands as era record",
    "span shrink",
):
    chk(f"draft carries: {s[:48]}", s in draft)

# C. the era anchors
chk("NR-019 exponent in use", "Bank-derate exponent in use (main-rotor disc power)" in register)
chk("NR-019 exponent value", "2.65" in register)
chk("NR-020 measured retention", "0.854 at 20°" in register)
chk("NR-020 fit form", "cos^2.65" in register)
chk("NR-027 six rows fail", "All six rows FAIL (P<5.0)" in register)
chk("NR-028 folded class", "folded class P_end 5.3691 (ok)" in register)
chk("register header era", "`post-95c385d_wind-authority`" in register)
chk("glossary cp fix row", "| cp fix |" in glossary)
chk("glossary folded class row", "| folded class |" in glossary)
chk("glossary wind authority row", "| wind authority |" in glossary)
stamp = read("docs/reporting/figures/pair-extract/extract-winner-operating-point.csv")
chk("extract era stamp", "physics era: post-95c385d_wind-authority" in stamp)
chk("archive dir present",
    (REPO / "scripts/results/archive_void_20260822_lambda3_exploit").is_dir())

# D. the system-anatomy note read at ee708d7
for s in ("NR-043", "`88277f6`", "1.4994019682084492", "`1.499 m`",
          "it is not a ring radius and not the tip offset alone",
          "No render moves until then", "joins at the next build"):
    chk(f"note carries: {s[:44]}", s in note)
chk("map v22 records NR-043", "NR-043 is signed (science-validator, `88277f6`)" in fmap)
chk("map v22 display form", "display `1.499 m` at three decimals" in fmap)
chk("captions plain form", "lifting autogyro kite stack" in captions)
chk("captions tech form", "Six triangular rings" in captions)
changed = git("diff", "--name-only", "ee708d7^", "ee708d7",
              "--", "docs/reporting/figures/").splitlines()
want = ["docs/reporting/figures/figure-map.md",
        "docs/reporting/figures/system-anatomy/captions.md",
        "docs/reporting/figures/system-anatomy/register-status.md"]
chk("ee708d7 figures tree = map + note + captions (no plate bytes)",
    sorted(changed) == sorted(want), ";".join(changed))
# the caption checker's rerun equals the kit's committed log
a = (REPO / "scratch/fig_sa_caption_forms_check.log").read_text()
b = (REPO / "scratch/sv_sa_caption_check_rerun.log").read_text()
chk("caption checker rerun = committed log", a == b)

print(f"\n{len(FAILS)} failures" if FAILS else "\nall checks pass")
print("SV_SV7_DONE")
sys.exit(1 if FAILS else 0)
