#!/usr/bin/env python3
"""v0.91 author pass: the TRPT closed-forms appendix and the three review errors.

Folds the Tallak derivation blocks with the science-writer's three verified
adjustments (block 4 units, block 8 domain, block 9 name), corrects E1, E2
and E4, and ticks the version. Two-state and fail-closed.
"""
import collections
import hashlib
import re
import subprocess
import sys

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics-author-wt"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"

EDITS = [
    (
        "Internal engineering report. Draft v0.90. Date 2026-11-01.",
        "Internal engineering report. Draft v0.91. Date 2026-11-06.",
    ),
    # E1: the blade's radii.
    (
        "The blade radius `r_rotor` is the aerodynamic size the blade spans from.\n"
        "The blade runs from the ring radius `r_hub` to the tip radius `r_rotor`.\n"
        "The part outside the ring is its overhang.",
        "The blade radius `r_rotor` is the power-sizing radius, not the tip.\n"
        "The blade crosses the ring.\n"
        "Its tip sits at 5.630 m from the shaft axis (NR-032).\n"
        "The part outside the ring is its overhang.",
    ),
    # E2: the per-rotor Betz basis.
    (
        "The per-rotor screen reads the annulus with no elevation factor.",
        "The per-rotor screen reads the annulus normal to the rotor axis.\n"
        "It carries no elevation factor, so its ceiling is the untilted Betz limit.\n"
        "That ceiling sits above the momentum ceiling of the tilted disc.\n"
        "The screen is a loose tripwire (NR-034).",
    ),
    # E4: the twist charge cap against the reject cost.
    (
        "The code floors the denominator at 1e-6.\n"
        "The ratio reads one million at the limit and stays finite.",
        "The code floors the denominator at 1e-6.\n"
        "The ratio reads one million at the limit and stays finite.\n"
        "The floor caps the ratio.\n"
        "The charge at that cap sits above the 1e9 reject cost.\n"
        "An ok design within a whisker of the limit scores below every reject.",
    ),
    (
        "No reject ranks above an ok design.",
        "No reject ranks above an ok design at the campaign margins.\n"
        "One edge case exists near the twist limit, and section 2.4.7 states it.",
    ),
]

APPENDIX = r"""
## Appendix: TRPT shaft section: closed forms

The forms below state the segment model the code implements.
The Tulloch thesis holds Eq 4.30 to 4.34, and `src/trpt_twist_limit.jl` carries the peak form.
A segment is a pair of rings of radii $r_0$ and $r_1$, joined by lines of length $l$.
Axial tension $T_N$ holds the segment.
A twist $\theta$ turns the top ring and shortens the segment.
The segment height follows from the line geometry.

$$h(\theta) = \sqrt{A + B \cos \theta},
\qquad
A = l^2 - r_0^2 - r_1^2,
\qquad
B = 2 \, r_0 r_1$$

The torque follows from virtual work.
Twisting the ring does work against the tension, so the torque is the slope of the height curve.

$$\tau = -T_N \, \frac{dh}{d\theta},
\qquad
\Lambda = \frac{\tau}{T_N \, r_1} = \frac{r_0 \sin \theta}{h(\theta)}$$

The peak twist solves $d\Lambda/d\theta = 0$.
The discriminant factors into the two reach terms.
A root exists for every shaft longer than $r_0 + r_1$.

$$\cos \delta_{\mathrm{peak}} =
\frac{\sqrt{A^2 - B^2} - A}{B}
\qquad (l > r_0 + r_1)$$

The cosine is negative, so the peak sits past 90 degrees.
For a long shaft the peak approaches 90 degrees from above.
The series below reads in radians.

$$\delta_{\mathrm{peak}} > 90^{\circ}
\qquad\text{and}\qquad
\delta_{\mathrm{peak}} = \frac{\pi}{2} + \frac{r_0 r_1}{l^2} + O(l^{-4})$$

The peak torque is half the drop in segment height from no twist to half a turn.

$$\tau_{\max} = T_N \cdot \frac{h(0) - h(\pi)}{2}$$

The geometry cancels out of the torque margin.
A segment has one shape parameter, its peak angle.
The margin at an operating twist is a function of two angles.

$$M(\theta_{\mathrm{op}}, \delta_{\mathrm{peak}}) =
\frac{\sqrt{1 + c^2 - 2 c \cos \theta_{\mathrm{op}}}}{\sin \theta_{\mathrm{op}}},
\qquad
c = \cos \delta_{\mathrm{peak}}$$

The inverse gives the twist allowed for a target margin.

$$\cos \theta_M =
\frac{c + \sqrt{c^2 - M^2 (1 + c^2 - M^2)}}{M^2}$$

The formula reproduces the winner margins.
It reads the twist and peak angles (NR-022) and the torque pair (NR-023).
S1 reads 2.03 and S5 reads 2.69 (NR-040).
The extra digits wait on the display ruling of the numbers seat.

For a fixed twist, the segment torque falls with the line length.

$$\tau = \frac{T \, r_0 r_1 \sin \delta}{L}
\qquad\Rightarrow\qquad
\tau = 0 \text{ at } \delta = 180^{\circ}
\qquad (l \geq r_0 + r_1)$$

Below that length the rings meet first, and the torque does not cross zero.

The zero crossing is a separate geometric bound.
The report's $\delta_{\mathrm{crit}}$ is the peak (NR-022), so this block names the zero crossing.

$$\delta_{\mathrm{zero}} =
\begin{cases}
\pi, & l \geq r_0 + r_1 \\
\arccos \frac{r_0^2 + r_1^2 - l^2}{2 r_0 r_1}, & l < r_0 + r_1
\end{cases}$$

The normalised response curve follows from the same two angles.

$$y(x) = \frac{\sin(x \, \delta_{\mathrm{peak}})}
{\sqrt{1 + c^2 - 2 c \cos(x \, \delta_{\mathrm{peak}})}},
\qquad
x = \delta / \delta_{\mathrm{peak}}$$

The Glauert ceiling for a tilted rotor follows from a momentum model.
Its value at 30 degrees waits on a signed row, so it does not print here.

$$C_{p,\mathrm{Glauert}}(a, \gamma) =
4a \, (\cos \gamma - a) \sqrt{1 - 2a \cos \gamma + a^2}$$

The optimum satisfies a cubic condition.

$$-3 a^3 + 7 a^2 c - 3 a c^2 - 2 a + c = 0,
\qquad
c = \cos \gamma$$

The averaging argument uses Jensen's inequality.
The mean of the cube is at least the cube of the mean.
A trend or an averaging choice can only raise the measured power above k times the mean cube.

$$\overline{\omega^3} \geq \overline{\omega}^{\,3}$$
"""

HEADING = "## Appendix: TRPT shaft section: closed forms"


def git(*args):
    return subprocess.run(
        ["git", "-C", REPO, *args], check=True, capture_output=True, text=True
    ).stdout


def tokens(text):
    return collections.Counter(re.findall(r"\d[\d.,]*\d|\d", text))


base = git("show", f"HEAD:{DRAFT}")
with open(f"{REPO}/{DRAFT}", encoding="utf-8") as f:
    work = f.read()

if HEADING in work:
    print("state: already applied, verifying")
else:
    if work != base:
        sys.exit("REFUSED: working tree differs from HEAD and the appendix is absent")
    print("state: clean at HEAD, applying")
    cand = base
    for old, new in EDITS:
        n = cand.count(old)
        assert n == 1, f"anchor count {n} for {old!r}"
        cand = cand.replace(old, new)
    assert cand.count(HEADING) == 0
    cand = cand.rstrip() + "\n\n" + APPENDIX.strip("\n") + "\n"
    with open(f"{REPO}/{DRAFT}", "w", encoding="utf-8") as f:
        f.write(cand)
    print("draft written")

with open(f"{REPO}/{DRAFT}", encoding="utf-8") as f:
    cand = f.read()

for banned in ("0.5192", "2.0252", "2.6883"):
    if banned in cand:
        sys.exit(f"REFUSED: {banned} must not print")

for _, new in EDITS:
    if cand.count(new) != 1:
        sys.exit(f"REFUSED: replacement not present exactly once: {new[:60]!r}")
if cand.count(HEADING) != 1:
    sys.exit(f"REFUSED: heading count {cand.count(HEADING)}")

with open(f"{REPO}/scratch/au_v091_candidate.md", "w", encoding="utf-8") as f:
    f.write(cand)

tb, tc = tokens(base), tokens(cand)
print("token add   :", dict(sorted((tc - tb).items())))
print("token remove:", dict(sorted((tb - tc).items())))
print("lines:", len(cand.splitlines()))
print("base md5   :", hashlib.md5(base.encode()).hexdigest())
print("candidate  :", hashlib.md5(cand.encode()).hexdigest())
