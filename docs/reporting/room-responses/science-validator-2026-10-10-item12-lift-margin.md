# Room response: item 1.2, lift margin hand check (2026-10-10, science-validator)

Scope: division item 1.2. Owner: this seat. Deliverable: one paragraph
and row amends. Gate: aero-validator counter.

Input: the read-only pass by aero-worker (same directory, section 1.2).
This seat re-derived the check from named rows.

**Result: the identity closes bit-exact. The 1.5 margin multiplies the
sizing mass. It does not multiply NR-018.**

## The hand check

From named rows only:

- NR-018 airborne mass, lifter included: 25.69846825623688 kg.

- Sizing mass = NR-018 minus the 5.0 kg lifter: 20.69846825623688 kg.

- Vertical load = 1.5 x 20.69846825623688 x 9.81 = 304.578 N.

- Line tension = 304.578 / sin(70 deg) = 324.125 N = NR-010
  (324.1250954336462). Exact.

- The same tension over the full airborne mass: 304.578 /
  (25.69846825623688 x 9.81) = 1.208.

NR-026 carries the identity now. The code path: `sized_lifter_for`
holds `F_vert = 1.5 x m_airborne x g` with `include_lifter=false`
(`src/lift_kite.jl:214`, `src/expansion_analysis.jl:45,77`). The lifter
carries its own weight (Rod ruling, 2026-08-21). The margin holds at
all wind speeds (NR-026).

## The paragraph (suggested reader text, section 3.3)

> The lifter sizing holds a 1.5 margin on the vertical load at the
> lift bearing. The sizing mass is the airborne mass without the lifter
> itself, 20.70 kg. The kite carries its own weight. The vertical load
> is 1.5 x 20.70 x 9.81 = 304.6 N.

> The line tension is that load over sin 70 degrees: 324.1 N (NR-010).
> The same tension over the full airborne mass of 25.70 kg (NR-018)
> gives a margin of 1.21. The margin holds at all wind speeds (NR-026).

## Row amends

- No row value changes. NR-010, NR-018 and NR-026 carry the basis.

- The draft text amends: name the sizing mass (20.698 kg) and the load
  point (the lift bearing). Quote the full-airborne ratio 1.21 beside
  the sizing ratio 1.5.

- Open for Rod: the requirement document behind the 1.5 factor, and
  the check point it names (sky hook or lift bearing). The implemented
  rule uses the lift bearing.

## Counter request

aero-validator: verify the two arithmetic lines from the named rows and
the cited code. Then sign or fault this response.
