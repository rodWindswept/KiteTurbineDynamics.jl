**Status** Open routing: derivations fold + review triage.

**Seat** hermes (map).

**Read at** `07ac041`.

## Item 1: the founder ask

Rod wants the Tallak Tveide / samara derivations in the report, in
mathematical notation, for Hong Yue and Amjad in Strathclyde to read.

He ruled all five R61 adoptions on 2026-11-06. The blocks below are
the exact content. @author folds them as a new section.

Placement is the author call: a new appendix named "TRPT shaft
section: closed forms" or an extension of the torsional analysis
section. Run the section-insert measurements before the fold.

@science-writer verifies each block against the sources: Tulloch Eq
4.31 to 4.34 (the repo implements 4.34 in `src/trpt_twist_limit.jl`,
whose docstring already states the peak is the operating ceiling) and
the ontology R61 language in the Windswept Ontology Core.

The review and addendum that ground these blocks sit in `feedback/` as
verbatim relays.

## Item 2: the derivation blocks (exact)

```math
h(\theta) = \sqrt{A + B \cos \theta},
\qquad
A = l^2 - r_0^2 - r_1^2,
\qquad
B = 2 \, r_0 r_1
```

```math
\tau = -T_N \, \frac{dh}{d\theta},
\qquad
\Lambda = \frac{\tau}{T_N \, r_1} = \frac{r_0 \sin \theta}{h(\theta)}
```

```math
\cos \delta_{\mathrm{peak}} =
\frac{\sqrt{A^2 - B^2} - A}{B}
\qquad (l > r_0 + r_1)
```

```math
\delta_{\mathrm{peak}} > 90^{\circ}
\qquad\text{and}\qquad
\delta_{\mathrm{peak}} = 90^{\circ} + \frac{r_0 r_1}{l^2} + O(l^{-4})
```

```math
\tau_{\max} = T_N \cdot \frac{h(0) - h(\pi)}{2}
```

```math
M(\theta_{\mathrm{op}}, \delta_{\mathrm{peak}}) =
\frac{\sqrt{1 + c^2 - 2 c \cos \theta_{\mathrm{op}}}}{\sin \theta_{\mathrm{op}}},
\qquad
c = \cos \delta_{\mathrm{peak}}
```

```math
\cos \theta_M =
\frac{c + \sqrt{c^2 - M^2 (1 + c^2 - M^2)}}{M^2}
```

```math
\tau = \frac{T \, r_0 r_1 \sin \delta}{L}
\qquad\Rightarrow\qquad
\tau = 0 \text{ at } \delta = 180^{\circ}
```

```math
\delta_{\mathrm{crit}} =
\begin{cases}
\pi, & l \geq r_0 + r_1 \\
\arccos \frac{r_0^2 + r_1^2 - l^2}{2 r_0 r_1}, & l < r_0 + r_1
\end{cases}
```

```math
y(x) = \frac{\sin(x \, \delta_{\mathrm{peak}})}
{\sqrt{1 + c^2 - 2 c \cos(x \, \delta_{\mathrm{peak}})}},
\qquad
x = \delta / \delta_{\mathrm{peak}}
```

```math
C_{p,\mathrm{Glauert}}(a, \gamma) =
4a \, (\cos \gamma - a) \sqrt{1 - 2a \cos \gamma + a^2}
```

```math
-3 a^3 + 7 a^2 c - 3 a c^2 - 2 a + c = 0,
\qquad
c = \cos \gamma
```

```math
\overline{\omega^3} \geq \overline{\omega}^{\,3}
```

## Item 3: number discipline before any fold prints

The margin formula reproduces the signed rows: the 2.03 of NR-022 (S1) and
the 2.69 of NR-023 (S5) from the printed twists and peaks alone.

The prose may say so and cite those rows. The closed forms also give
2.0252 and 2.6883 at one more digit. @science-validator rules whether
the extra digit prints or the prose quotes the row value.

The Glauert ceiling 0.5192 at 30 degrees has no row. It must not print
until @aero-validator signs one.

The delta crit values the report prints are the peaks (NR-022), which R61
renamed on the ontology side.

## Item 4: the four report errors (triage of the review)

@author: E1, the blade sentence in section 2.1 (tip radius 5.630 m.
the blade crosses the ring).

E2, name the basis of the per-rotor Betz screen or give it the elevation
factor.

E4, the twist charge cap against the 1e9 reject cost.

@science-writer: E3, the power gap. the Jensen inequality (last block)
rules out the trend and averaging causes. The gap is systematic.

The map seat probes the gate traces in parallel and hands the findings
over.

## Item 5: the full review triage

The review and the addendum carry ten questions plus the ontology
items. The map seat runs the external-review triage recipe against
both files as the next train.

The five R61 decisions the founder ruled already closed the ontology half (the
O1 to O5 items of the addendum). The report half (Q1 to Q10) stays open and
routes per the triage.

## Item 6: founder call (open)

The samara credit. The derivations carry two new results: the
half-shortening peak-torque identity and the geometry-free margin.

Tulloch Eq 4.34 holds the peak-twist formula already. The other two
are not in the literature the room checked.

Options for the citation: cite the public samara page
(`math.osp.no/parameter-fibers`) and name the private communication as
such. Cite as unpublished. Or write a joint short note first and cite
that. @map seat presents to Rod.

No number and no signed row moves here.

- hermes (map seat)
