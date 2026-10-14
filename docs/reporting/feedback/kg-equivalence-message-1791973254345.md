Short answer: **partially**. The document has a *pointer* to the kg-equivalent scoring and one useful worked number, but it does **not yet fully explain how the score is constructed from the evaluated gene performance**.

For an internal draft where readers can read the code, it may be enough. For a polished report, it is not enough yet.

---

## What the document currently explains well

The report does define the basic idea:

> “The campaign minimizes a kg-equivalent objective score: the airborne mass plus the gate penalties. A lower score is better. The objective score is not the physical airborne mass.”  
> — §2.4

It also gives one concrete decomposition in the register:

> **NR-039**  
> `fitness 27.3635... = mass 25.698... + over-power 0.493... + utilisation 0.557... + twist 0.614...`  
> Penalty total: `1.665 kg-equivalent`

That is useful because it shows that the winner’s objective score is not just its mass. It is:

```text
27.364 kg-equivalent
= 25.698 kg physical airborne mass
+ 1.665 kg-equivalent penalties
```

So the report does establish three important things:

1. The objective is **kg-equivalent**, not kilograms of physical mass.
2. The objective includes **airborne mass plus penalties**.
3. The campaign winner’s score can be decomposed into mass and penalty terms.

That is a good start.

---

## What is still missing

The explanation is not yet complete because the reader cannot reconstruct the scoring from the report alone.

### 1. The penalty terms are named but not defined

NR-039 gives:

```text
mass + over-power + utilisation + twist
```

But the report does not explain:

- What “over-power” means exactly.
- What “utilisation” refers to.
- What “twist” refers to.
- How each term is calculated.
- What threshold or target each penalty uses.
- Whether the penalties are continuous or step-like.
- Whether they apply only to failing designs or to all evaluated designs.
- How the units are converted into kg-equivalent.

A reader can see that the winner has penalties, but cannot tell how a new genome would be scored.

---

### 2. The relationship between hard gates and objective penalties is unclear

The report says:

> “Four statuses result: ok, reject, clearance_reject and reject_twist.”  
> — §2.4

It also says:

> “The campaign minimizes a kg-equivalent objective score: the airborne mass plus the gate penalties.”

But it does not clearly explain how these two systems interact.

A reader needs to know, for example:

- Are `reject`, `clearance_reject`, and `reject_twist` hard failures?
- Do failed designs still receive an objective score?
- Does differential evolution use the objective score to rank failed designs?
- Are penalties applied only to designs that pass all hard gates?
- If a design fails a gate, is it discarded immediately or ranked by its kg-equivalent score?

The current text says DE “scores each design and culls the failures,” but does not fully explain whether the kg-equivalent score still matters for rejected designs.

---

### 3. The report does not show the scoring pipeline after evaluation

A polished explanation should make this sequence explicit:

```text
genome
→ decoder
→ builder
→ evaluator run
→ measured metrics
→ hard gate status
→ objective penalty terms
→ kg-equivalent score
→ DE ranking / island best
```

The report implies this, but it does not state it clearly.

For example, after the evaluator runs the 10 s relax and 40 s window, the campaign probably has metrics such as:

- `P_mean`
- minimum FoS
- clearance result
- twist result
- torque margin
- airborne mass
- ring utilisation
- penalty terms

Then it produces:

```text
status = ok / reject / clearance_reject / reject_twist
objective = mass + penalties
```

That mapping is currently only partially visible.

---

### 4. “kg-equivalent” is used before being fully defined

The report uses the phrase several times:

- seed genome scores `36.109 kg-equivalent`
- island 3 reaches `27.364 kg-equivalent`
- objective adds `1.665 kg-equivalent` penalties
- machine-evolution-strip labels use “search objective”

But the term is never fully unpacked. The reader is told it is not physical mass, but not exactly what one unit of kg-equivalent represents.

A good definition would say something like:

> “kg-equivalent is an objective unit. One kilogram of physical airborne mass contributes 1.0 to the score. Constraint penalties are also expressed in the same objective unit, so that different failure pressures can be compared on one scalar scale.”

That would make the term meaningful.

---

### 5. The machine-evolution-strip caption is slightly inconsistent

The figure caption says:

> “The number under each machine is its search objective, in kilograms.”

But the register and body text call this a **kg-equivalent** score, not physical kilograms.

This should be changed to:

> “The number under each machine is its search objective, in kg-equivalent.”

Also, since the strip prints no mass value, saying “in kilograms” is misleading. The value includes penalties, so it is not a direct mass reading.

---

## A better way to explain it in the report

I would add a short subsection under Methods, probably near §2.4 or as a new §2.3 if you are renumbering.

Something like this:

```text
2.x Objective score: kg-equivalent

After the evaluator measures a candidate design, the campaign assigns it two
related quantities:

1. A gate status: ok, reject, clearance_reject, or reject_twist.
2. A search objective, quoted in kg-equivalent.

The gate status is a pass/fail classification. The search objective is a scalar
score used by differential evolution to rank designs.

The objective has the form:

    f = m_airborne + p_power + p_utilisation + p_twist

where:

- m_airborne is the physical airborne mass of the built machine, in kg;
- p_power is a soft penalty associated with power performance;
- p_utilisation is a soft penalty associated with structural utilisation;
- p_twist is a soft penalty associated with twist margin.

The score is quoted in kg-equivalent because all terms are expressed on one
common objective scale. One kilogram of physical airborne mass contributes 1.0
kg-equivalent to the score. The penalty terms also contribute to the same scale,
but they are not additional physical mass.

A lower f is better. The campaign winner is the feasible design with the lowest
recorded objective among the ok designs under the campaign gates.

For the campaign winner, NR-039 gives:

    f = 27.364 kg-equivalent
      = 25.698 kg physical airborne mass
      + 0.493 kg-equivalent power penalty
      + 0.558 kg-equivalent utilisation penalty
      + 0.614 kg-equivalent twist penalty

The penalty total is 1.665 kg-equivalent.
```

Then add a table:

| Term | Meaning in this report | Current status |
|---|---|---|
| `m_airborne` | Physical airborne mass of the built machine | Defined; NR-018 for winner |
| `p_power` | Penalty term reported as “over-power” in NR-039 | Needs formula or register row |
| `p_utilisation` | Penalty term associated with structural utilisation | Needs formula or register row |
| `p_twist` | Penalty term associated with twist margin | Needs formula or register row |
| Hard gates | Power floor, FoS floor, clearance, twist, rope break | Defined in §2.4 and §3.3 |
| Objective score | `mass + penalties`, quoted in kg-equivalent | Partially defined; needs penalty formulas |

That would make the scoring much clearer.

---

## A more complete worked example

You could also add a small worked paragraph:

```text
For the campaign winner, the evaluator measured an airborne mass of 25.698 kg
(NR-018). The objective score recorded for island 3 is 27.364 kg-equivalent
(NR-005). The difference, 1.665 kg-equivalent, is the sum of the soft penalties
recorded in NR-039. Thus the winner is not simply the lightest machine found;
it is the lowest-scoring feasible machine under the combined mass-and-penalty
objective.
```

That helps readers understand why the objective score and physical mass differ.

---

## What I would change immediately

If you want a quick fix, make these edits:

### 1. Rename “gate penalties” to something less ambiguous

Current phrase:

> “airborne mass plus the gate penalties”

Better:

> “airborne mass plus soft constraint penalties”

or:

> “airborne mass plus objective penalties”

“Gate penalties” can sound like the gates themselves produce a score, while the report also treats gates as pass/fail.

---

### 2. Add one sentence distinguishing hard gates from objective penalties

For example:

```text
The hard gates determine whether a design is ok or rejected. The kg-equivalent
objective ranks evaluated designs by combining physical mass with soft constraint
penalties.
```

---

### 3. Fix the evolution-strip caption

Change:

> “The number under each machine is its search objective, in kilograms.”

to:

> “The number under each machine is its search objective, in kg-equivalent.”

---

### 4. Add a register row or data request for the penalty formulas

If the exact penalty functions are not already signed rows, add an open request:

```text
Open data request: signed register rows or source extract defining the
kg-equivalent penalty terms p_power, p_utilisation, and p_twist, including
thresholds, scaling constants, units, and applicability to ok versus rejected
designs.
```

Until that exists, the report should avoid implying that the reader can reproduce the score from the body text alone.

---

## Bottom line

The document **does have an explanation**, but it is more of a **label plus one example** than a full working description.

It tells the reader:

- what the score is called,
- that it is lower-is-better,
- that it is not physical mass,
- and how the winner’s score decomposes into mass and penalties.

But it does not yet explain:

- how each penalty is calculated,
- what thresholds are used,
- how hard gates interact with the objective,
- or how DE uses the kg-equivalent score after evaluating a genome.

So my assessment would be: **adequate as an internal pointer, but not polished enough for the final report yet.** The cleanest fix is to add a short “Objective score: kg-equivalent” subsection in Methods and attach either signed register rows or a temporary open-data request for the penalty definitions.