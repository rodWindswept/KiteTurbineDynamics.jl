# B-20 confirmation and the NR-059 cited-form amend (2026-10-18, science-validator)

Two desk items close in one pass. The B-20 final confirmation checks the
candidate wording in `scratch/au_b20b21_draft_candidate.md` against the
carrier map. The NR-059 amend records the two forms the candidate cites
that the row did not print.

## B-20 confirmation

All five items read true against the candidate and the register.

1. The r_rotor sizing form. The candidate prints `r_rotor = sqrt(P / (f Cp 0.5 rho pi v^3))` with each term named.
   The form matches `src/bem.jl:162-164`, and NR-050 carries the chain.
   The factor f reads the bank and elevation projection, which matches the NR-050 basis block.
   The winner decode 2.434 m matches the row. The sizing TSR stays unprinted, correctly, because no row carries it.

2. The ring-count decode. NR-011 carries rings 6 and n_lines 3. The
   spacing-pass mechanism reads true in source (`ring_spacing_v4` and
   `ring_spacing_v5`, the density-profile power law).

3. The twist-ratio definition. The candidate form matches NR-046 (absolute
   segment twist over the crossing limit, worst segment over the window).
   The δα* form matches NR-053.

4. The P_score definition. NR-046 carries the tail-5 power. See the second
   flag below on the five-second gloss.

5. The hard-gate list. The five gates in the §2.4 table all map to signed
   rows. The tip-ceiling cite on NR-047 is the correct carrier. The row
   block prints the 100.0 gate, so the named deviation stands.

Two flags for the pen at the author seat:

- The x4 sentence cites NR-044, whose note carries only the rotor-count rounding.
  The polygon-count rounding site sits at `design_from_vector_v4`, `src/ring_spacing.jl:475`.
  A dated note now lands on NR-011 carrying that site, so the sentence re-cites NR-011 with one token move.

- The P_score sentence glosses "the mean of the last five seconds of the window".
  The five-second span reads in NR-041 (tail-5 at 35 to 40 s). The source names the tail as the last 5 samples (sustained power).
  NR-046 carries the tail-5 power term. Trim the gloss to the NR-046 form, or add NR-041 beside the span.

## NR-059 cited-form amend

The register now carries the two forms that the §3.3 candidate quotes.

- The extension speed spread. The run spans t = 50 s to 200 s with samples every 5 s, 29 logged.
  The omega spread reads 0.00120 rad/s on the 13.3852 rad/s first sample.
  That reads 0.0090 per cent. The draft quotes 0.009 per cent.

- The extension steps. The hub (ring 6, the max station) bow increments per 5 s fall strictly.
  The first reads 0.02539 m and the last reads 0.00053 m.
  The draft quotes 0.0254 m to 0.00053 m. The block names the station, per the note from the aero seat.
  The unsigned geometric tail stays outside the row.

## Gates

- Register STE unchanged versus HEAD: 190 flags, 16 em dashes, zero added by either block.
- Citation checker exit 0 on the committed draft: 55 cited, every one signed, the uncited set unchanged.
- The commit touches the register and this receipt only. No draft or figure byte moves.
