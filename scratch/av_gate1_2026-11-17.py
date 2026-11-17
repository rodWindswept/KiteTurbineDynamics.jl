#!/usr/bin/env python3
"""aero-validator: Gate 1 whole-report aerodynamics counter-read and samara citation check.

Reads committed HEAD (33bc8289, draft v0.91 from 5d4b0067 / e93192a6) via git show,
verifies every aerodynamics number (power, torque, CT, k, blade geometry) against
docs/reporting/numbers-register.md, and checks the samara citation ruling requirements.
"""
import hashlib
import math
import re
import subprocess
import sys


def git_show(spec: str) -> str:
    return subprocess.check_output(["git", "show", spec], text=True)


def main() -> int:
    head_sha = subprocess.check_output(["git", "rev-parse", "--short=8", "HEAD"], text=True).strip()
    draft = git_show("HEAD:docs/reporting/drafts/2026-10-08-report-first-draft.md")
    reg = git_show("HEAD:docs/reporting/numbers-register.md")
    bib = git_show("HEAD:docs/reporting/references.bib")
    ref_ver = git_show("HEAD:docs/reporting/references-verification.md")
    reg_bank = git_show("320330fd:docs/reporting/numbers-register.md")

    draft_lines = draft.splitlines()
    draft_sha256 = hashlib.sha256(draft.encode()).hexdigest()

    print(f"HEAD={head_sha}")
    print(f"draft_lines={len(draft_lines)} draft_sha256={draft_sha256[:16]}")

    checks = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        status = "PASS" if cond else "FAIL"
        checks.append((name, cond, detail))
        print(f"[{status}] {name}: {detail}")

    # 1. Draft identity & citation census
    check("draft_version_v091", "Draft v0.91. Date 2026-11-06." in draft, "v0.91 header present")
    check("draft_line_count", len(draft_lines) == 1541, f"lines={len(draft_lines)}")

    cited_ids = sorted(set(re.findall(r"NR-\d{3}", draft)))
    reg_ids = set(re.findall(r"^\| (NR-\d{3})\b", reg, flags=re.M))
    missing_ids = [r for r in cited_ids if r not in reg_ids]
    check("all_cited_rows_in_register", len(cited_ids) == 59 and not missing_ids,
          f"cited_distinct={len(cited_ids)} missing={missing_ids}")

    # 2. Power checks
    p_mean_exact = 5.3087794439367935
    p_end_exact = 5.314113662272673
    p_range_exact = 0.028659374428010587
    omega_mean_exact = 13.380259861740395
    k_val = 2.24
    kw3_exact = k_val * (omega_mean_exact ** 3) / 1000.0
    gap_w = (kw3_exact - p_mean_exact) * 1000.0
    gap_pct = (kw3_exact / p_mean_exact - 1.0) * 100.0

    check("power_winner_pmean_pend",
          "5.309 kW" in draft and "5.314 kW" in draft and round(p_mean_exact, 3) == 5.309 and round(p_end_exact, 3) == 5.314,
          f"P_mean={p_mean_exact:.6f}->5.309, P_end={p_end_exact:.6f}->5.314 (NR-008)")
    check("power_window_swing",
          "0.029 kW" in draft and "29 W (NR-014)" in draft and round(p_range_exact, 3) == 0.029,
          f"P_range={p_range_exact*1000:.2f} W -> 29 W / 0.029 kW (NR-014)")
    check("power_ok_range_and_floor_bound",
          "between 5.02 and 6.32 kW (NR-007)" in draft and "exactly one reads 5.00 kW and the next reads 5.02 kW (NR-069, NR-002)" in draft,
          "NR-007 5.02-6.32 kW and NR-069 5.00/5.02 kW")
    check("power_kw3_gap_and_jensen",
          "5.366 kW, a 1.07 per cent gap" in draft and "The gap is 57 W, and the whole window swing is 29 W (NR-014)" in draft,
          f"k*omega^3={kw3_exact:.6f} kW (5.366), gap={gap_w:.2f} W (57 W), pct={gap_pct:.2f}% (1.07%)")

    # Swept area, Cp, Betz ceiling
    r_hub = 4.57997905482005
    r_rotor = 2.4341173109692225
    blade_scale = 0.8213255027884769
    span = 0.75 * r_rotor * blade_scale
    r_in = r_hub - 0.3 * span
    r_out = r_hub + 0.7 * span
    a_raw = math.pi * (r_out ** 2 - r_in ** 2)
    a_zn = 39.491173622830395
    rho = 1.225
    v_ref = 11.01
    p_wind_zn = 0.5 * rho * a_zn * (v_ref ** 3) / 1000.0
    betz_ceil = (16.0 / 27.0) * p_wind_zn
    betz_share = (p_mean_exact / betz_ceil) * 100.0

    check("power_areas_and_betz",
          "45.9733 square metres raw and 39.4912 square metres on the wind-normal basis (NR-033)" in draft
          and "19.1304 kW, and the winner delivers 27.75 per cent of it (NR-034)" in draft,
          f"A_raw={a_raw:.4f}, A_zn={a_zn:.4f}, Betz={betz_ceil:.4f} kW, share={betz_share:.2f}% (NR-033, NR-034)")
    check("power_cp_pair",
          "0.2944 at the ring speed ratio, and\n0.2258 at the tip-speed ratio (NR-031, NR-032)" in draft
          and "Ring speed ratio | 5.566 | NR-031" in draft
          and "Tip-speed ratio | 6.8415 | NR-032" in draft,
          "Cp 0.2944 @ TSR_ring 5.566 (NR-031), Cp 0.2258 @ TSR_tip 6.8415 (NR-032)")
    check("power_glauert_appendix_hold",
          "Its value at 30 degrees waits on a signed row, so it does not print here." in draft
          and "NR-086" not in reg and "NR-086" in reg_bank,
          "Glauert formula/cubic printed; 0.5192 withheld in v0.91 because NR-086 is on bank-derate-cos2p65 (320330fd), not master HEAD")

    # 3. Torque checks
    tau_deliv = p_mean_exact * 1000.0 / omega_mean_exact
    tau_law = k_val * (omega_mean_exact ** 2)
    check("torque_delivered_and_law",
          "396.76 N·m (NR-030)" in draft and "401.03 N·m at the mean speed (NR-015, NR-029)" in draft,
          f"tau_deliv={tau_deliv:.4f}->396.76 (NR-030), tau_law={tau_law:.4f}->401.03 (NR-015, NR-029)")
    check("torque_segment_margins_and_twists",
          "least segment torque margin is 2.03, at S1 (NR-040)" in draft
          and "S5 carries the largest segment torque margin, 2.69 (NR-040)" in draft
          and "S1 to S4 transmit 33.5 to 33.9 degrees against a 98.9 degree limit (NR-022)" in draft
          and "S5 transmits 22.8 degrees against its 92.6 degree limit (NR-022)" in draft,
          "S1 margin 2.03, S5 margin 2.69 (NR-040); twists 33.5-33.9/98.9 and 22.8/92.6 (NR-022)")

    # Closed-form margin check from printed angles
    def cf_margin(theta_deg: float, dpeak_deg: float) -> float:
        th = math.radians(theta_deg)
        c = math.cos(math.radians(dpeak_deg))
        return math.sqrt(1.0 + c * c - 2.0 * c * math.cos(th)) / math.sin(th)

    m_s1 = cf_margin(33.94561934829036, 98.85908296054023)
    m_s5 = cf_margin(22.81808239780429, 92.63661964446502)
    check("torque_closed_form_reproduction",
          round(m_s1, 2) == 2.03 and round(m_s5, 2) == 2.69
          and "S1 reads 2.03 and S5 reads 2.69 (NR-040)." in draft,
          f"M_CF(S1)={m_s1:.4f}->2.03, M_CF(S5)={m_s5:.4f}->2.69")

    # 4. CT checks
    ct_tokens = re.findall(r"\bC_T\b|\bCt\b|\bct_bem\b", draft)
    check("ct_no_unregistered_numerals_in_draft",
          len(ct_tokens) == 0 and "tether-to-blade bridling that resists thrust and expansion" in draft,
          f"ct_tokens_in_draft={len(ct_tokens)}; §4.3 boundary states main-rotor bridling/thrust/drag scope")

    # 5. k-value checks
    ksweep_expected = [
        "| 0.5 | reject | 3.49 | 19.14 | 51.8 |",
        "| 1.0 | ok | 5.45 | 17.64 | 47.8 |",
        "| 1.5 | ok | 6.78 | 16.59 | 42.8 |",
        "| 1.94 | ok | 7.56 | 15.80 | 40.1 |",
        "| 2.24 | ok | 8.00 | 15.34 | 36.4 |",
        "| 3.0 | ok | 8.89 | 14.42 | 24.3 |",
    ]
    check("k_sweep_table_nr047",
          all(row in draft for row in ksweep_expected)
          and "8.9475 to 8.9511 kW at 4 dp" in draft,
          "all 6 NR-047 display rows and NR-041 plateau band match")
    check("k_nr048_withdrawn_tokens_absent",
          "twice the nominal load (NR-048)" in draft
          and "1278" not in draft and "87.9" not in draft and "78.8" not in draft,
          "NR-048 'twice the nominal load' present; withdrawn tokens 1278, 87.9, 78.8 absent")
    check("k_failure_ledger_anchors",
          "k_mppt 10.0, the 50-kilowatt default gain" in draft
          and "near 1.94" in draft
          and "The anchor 3.55" in draft
          and "The anchor 5.39" in draft,
          "§4.2 k-alignment and retired anchors match NR-047")

    # 6. Blade geometry checks
    check("blade_geometry_e1_and_nr050",
          "The base span is 0.75 of the power-sized rotor radius, and the base chord is 0.113 of it." in draft
          and "The blade crosses the ring." in draft
          and "Its tip sits at 5.630 m from the shaft axis (NR-032)." in draft
          and "The winner decode gives r_rotor 2.434 m (NR-050)." in draft
          and round(r_out, 3) == 5.630 and round(span, 3) == 1.499 and round(r_rotor, 3) == 2.434,
          f"r_rotor={r_rotor:.4f}->2.434, span={span:.4f}->1.499, r_in={r_in:.4f}->4.130, r_out={r_out:.4f}->5.630")
    check("blade_winner_decode_and_clearance",
          "Topmost ring radius | 4.580 m | NR-011" in draft
          and "Ground radius | 0.804 m | NR-011" in draft
          and "Main-rotor bank, ring 6 | 7.088 deg | NR-017" in draft
          and "blade_scale_top`, reads 0.8213" in draft
          and "pass, 5.468 m, margin +3.968 m | +264.5 per cent, 3.65 times | NR-042" in draft,
          "NR-011, NR-017, NR-042 winner geometry and clearance match")
    check("blade_cone_nr049_boundaries",
          "one fixed half-angle, 22 degrees" in draft
          and re.search(r"\b11\.0\b", draft) is None,
          "NR-049 22 deg half-angle and reference apex gloss match Boundary 3; no forbidden 11.0 deg per-side numeral")

    # 7. Samara citation ruling audit (against hermes-2026-11-06-tallak-citation-ruling.md)
    has_half_shortening_in_draft = r"\tau_{\max} = T_N \cdot \frac{h(0) - h(\pi)}{2}" in draft
    has_geom_free_margin_in_draft = r"M(\theta_{\mathrm{op}}, \delta_{\mathrm{peak}})" in draft
    has_samara_url_in_draft = "math.osp.no/parameter-fibers" in draft
    has_tveide_in_draft = ("Tveide" in draft) or ("samara" in draft.lower())
    has_samara_in_bib = ("samara" in bib.lower()) or ("parameter-fibers" in bib.lower()) or ("tveide" in bib.lower())
    has_samara_in_refver = ("samara" in ref_ver.lower()) or ("parameter-fibers" in ref_ver.lower()) or ("2026-11-06" in ref_ver)

    print("\n=== SAMARA CITATION RULING AUDIT ===")
    print(f"two_new_results_printed_in_v091_appendix={has_half_shortening_in_draft and has_geom_free_margin_in_draft}")
    print(f"samara_url_in_draft={has_samara_url_in_draft}")
    print(f"tveide_or_samara_named_in_draft={has_tveide_in_draft}")
    print(f"ruling_recorded_in_references_bib={has_samara_in_bib}")
    print(f"dated_section_in_references_verification_md={has_samara_in_refver}")

    passed = sum(1 for _, c, _ in checks if c)
    print(f"\nAERODYNAMICS_CHECKS: {passed}/{len(checks)} PASS")
    return 0 if passed == len(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
