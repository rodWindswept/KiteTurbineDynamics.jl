#!/usr/bin/env python3
# scratch/sv_fb5_source_reads_check.py — science-validator, 2026-10-14.
# Feedback round 5 source reads: the blade-scale base and the cone-angle basis.
# Verifies the code sites, the arithmetic, the cone census, the naming set,
# the cold-path glance and the draft anchors. Read-only.
# Run: python3 scratch/sv_fb5_source_reads_check.py | tee scratch/sv_fb5_source_reads_check.log
import os
import re
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ok = 0
fail = 0


def check(name, cond, detail=""):
    global ok, fail
    if cond:
        ok += 1
        print(f"PASS  {name}")
    else:
        fail += 1
        print(f"FAIL  {name}  {detail}")


def read(rel):
    with open(os.path.join(REPO, rel)) as f:
        return f.read()


# ── A. The blade-scale chain: code sites ────────────────────────────────
ov10 = read("src/objective_v10.jl")
check("A1  span base = 0.75 * r_rotor_i * blade_scale_i",
      "span = 0.75 * r_rotor_i * blade_scale_i" in ov10)
check("A2  chord base = 0.113 * r_rotor_i * blade_scale_i",
      "blade_chord = 0.113 * r_rotor_i * blade_scale_i" in ov10)
check("A3  r_rotor_i from the power sizing",
      "r_rotor_i = BEM.rotor_radius_for_power(P_i, v_i, design.n_lines; f=f_i)" in ov10)
check("A4  power share line",
      "P_i = (i == 1) ? power_split * power_W" in ov10)
bem = read("src/bem.jl")
check("A5  bem sizing formula doc line", "P = f · Cp · ½ρ · πr² · v³" in bem)
check("A6  rotor_radius_for_power def", "function rotor_radius_for_power(" in bem)
check("A7  projection factor def",
      "projection_factor(bank_deg::Float64, elev_rad::Float64)" in bem)
check("A8  mass law ref = 0.420 kg at span_ref 1.0",
      "const M_BLADE_REF_KG = 0.420" in read("src/parameters.jl"))

# ── B. Arithmetic on the signed decode values ───────────────────────────
r = 2.4341173109692225
s = 0.8213255027884769
base_span = 0.75 * r
span = base_span * s
base_chord = 0.113 * r
chord = base_chord * s
mass_blade = 0.420 * span ** 3
check("B1  span reproduces NR-043", abs(span - 1.4994019682084492) < 1e-12, f"span={span!r}")
check("B2  span quote 1.499", f"{span:.3f}" == "1.499")
check("B3  base span 0.75 x r", abs(base_span - 1.8255879832269168) < 1e-15, f"{base_span!r}")
check("B4  chord quote 0.226", f"{chord:.3f}" == "0.226", f"chord={chord!r}")
print(f"      base_span={base_span!r}  span={span!r}")
print(f"      base_chord={base_chord!r}  chord={chord!r}")
print(f"      mass/blade={mass_blade!r}  assembly(3)={3 * mass_blade!r}")
reg = read("docs/reporting/numbers-register.md")
check("B5  NR-043 span in register", "1.4994019682084492" in reg)
check("B6  NR-043 r_rotor in register", "2.4341173109692225" in reg)
check("B7  NR-043 blade_scale in register", "0.8213255027884769" in reg)

# ── C. The cone census: one fixed value, never searched ─────────────────
lines_cone = []
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in (".git", "scratch")]
    for fn in files:
        if not fn.endswith(".jl"):
            continue
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, REPO)
        try:
            with open(p) as f:
                for i, line in enumerate(f, 1):
                    if "cone_slope_deg" in line:
                        lines_cone.append((rel, i, line.rstrip()))
        except UnicodeDecodeError:
            pass
print(f"      cone_slope_deg sites (src/scripts/test/figures): {len(lines_cone)}")
bad = [t for t in lines_cone
       if not re.search(
           r"22|cfg\.cone_slope_deg|o\.cone_slope_deg|=\s*cone_slope_deg|deg2rad\(cone_slope_deg\)|^\s*cone_slope_deg,\s*$",
           t[2])]
check("C1  every site reads 22 or the cfg plumb", not bad, bad[:4])
forb = [t for t in lines_cone
        if re.search(r"LinRange|range\(|collect\(|sample\(|rand\(|bounds", t[2])]
check("C2  no site varies the value", not forb, forb[:4])
check("C3  runner cfg constant", any(
    "cone_slope_deg = 22.0" in t[2] and "run_v13_5kw_masslift.jl" in t[0] for t in lines_cone))
check("C4  cone length from the value", "tan(deg2rad(cone_slope_deg))" in ov10)
check("C5  no cone gene in the seed file", "cone" not in read("scripts/compute_seeds.jl"))
layout_i = ov10.find("Canonical layout:")
check("C6  no cone gene in the canonical layout",
      "cone" not in ov10[layout_i:layout_i + 260])
lit = sum(1 for t in lines_cone if re.search(r"=\s*22(\.0)?\b", t[2]))
check("C7  literal 22.0 sites hold across the tree", lit >= 15, f"literal sites={lit}")

# ── D. The F5 reading record and the naming set ─────────────────────────
f5 = read("docs/validation/trpt-reference/03-repo-findings.md")
check("D1  F5 headline", "The transition cone angle is the APEX angle" in f5)
check("D2  F5 per-side reading", "the per-side slope is **11.0 degrees**" in f5)
check("D3  F5 status line",
      "Resolved** for the angle. Open for the code change" in f5)
check("D4  bridle cone 31 in physics-topology",
      "bridle cone half-angle (from the shaft axis) | 31°" in read("docs/agents/physics-topology.md"))
check("D5  NR-011 bank slot 22", "bank_bot 22°" in reg)
draft = read("docs/reporting/drafts/2026-10-08-report-first-draft.md")
check("D6  draft bank-slot sentence", "A second bank slot reads 22 degrees." in draft)

# ── E. The cold-path glance and the decode convention ───────────────────
runner = read("scripts/run_v13_5kw_masslift.jl")
check("E1  runner cold pin", "start_mode = :cold" in runner)
check("E2  draft cold line", "The ODE path is `:cold`." in draft)
ev = read("src/objective_evaluator.jl")
check("E3  evaluator passes cfg.v_rated", "v_rated=cfg.v_rated" in ev)
i0 = runner.find("dec = design_from_vector_v10")
seg = runner[i0:i0 + 400]
check("E4  runner clearance call omits v_rated", "v_rated" not in seg, seg[:160])

# ── F. Draft fold anchors ───────────────────────────────────────────────
check("F1  blade-scale sentence",
      "Blade scale sets the blade size. The scale multiplies the blade span" in draft)
check("F2  gene sentence anchor", "The search treats each of these as a gene." in draft)

# ── G. The probe log reproduces the signed convention ───────────────────
log = read("scratch/sv_fb5_source_reads_probe.log")
check("G1  probe r_rotor (v_rated=11.0)", "r_rotor=2.434117310969" in log)
check("G2  probe span", "span=tip-hub=1.499401968208" in log)
check("G3  probe span check true", "check span == 0.75*r*scale:     true" in log)
check("G4  probe chord check true", "check chord == 0.113*r*scale:   true" in log)
check("G5  probe stamp", "HEAD: cd779dd" in log)

print(f"\nSV_FB5_READS_CHECK: {ok + fail} checks, {fail} fail")
sys.exit(1 if fail else 0)
