# Room response: the 18.8 m case in the 10-05 screen (2026-10-10, science-validator)

Scope: the sub-question the lead escrowed to this seat (Signal,
2026-10-10). The reviewer asked why the 18.8 m case failed the 10-05
length screen while the winner passes at 18.8 m. Two things separate
the two rows: the machine and the physics era. This record states both
sides with receipts.

## 1. The screen ran the pre-fold island-3 winner

Runner `scripts/run_length_variants.jl`. The `--genome island3` setting
loads the bankderate-v1 island-3 winner. Both variant dirs hold a
`genome_used.csv` file. Both files are byte-equal to
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate/best_vector.csv`
(r_hub 3.8347, blade_scale_top 0.6994).

The two rounds:

| Round | Tree | Stamp | 18.8 m | 21.2 m | 25.0 m | Verdict |
|---|---|---|---|---|---|---|
| before the cp fix | `f225e95` | 2026-10-05T10:10Z | 3.7955 | 3.8645 | 3.9747 | FAIL (P<5.0) x3 |
| after the cp fix | `a82cafd` | 2026-10-05T11:25Z | 4.2332 | 4.3055 | 4.4122 | FAIL (P<5.0) x3 |

Readings are P_mean in kW. All six rows sit below the 5.0 floor.

## 2. Era side: the D1 re-baseline shrank the decode

The D1 site-wind landing (`6f4cdbe`, 2026-10-03) replaced the 50 m
decoder anchor. For this genome the decoded blade span fell from
1.3485 to 0.9484. The landing record has the change
(`docs/validation/2026-10-03-landing-tip-red.md:37`).

The lead packet records the pre-D1 reading of the same design as
5.10 kW (2026-10-01) against 3.7955 kW at round 1. The packet flags
the exact split as inferred. The span shrink is the only documented
large mechanism, and its size fits the drop.

Launch-only physics was absent from both screen trees: `793137a`,
`b488262`, `b835ebc` and `95c385d` (lead packet, section 1.5).

## 3. Machine side: the fold lifted the class

The fold lands at `bd5114e` (2026-10-05 16:09), hours after both
rounds. It pins two genes of the same vector to the then-live box
ceilings: r_hub 3.8347 to 4.32, blade_scale_top 0.6994 to 1.0. That
is `S2_FOLD_SEED` (`scripts/compute_seeds.jl:46-71`).

The folded class at 18.8 m:

- Cold flight at the fold tip `93a3844`: `ok`, P_mean 5.36 kW,
  P_end 5.37 kW, FoS 5.41 (`docs/validation/2026-10-05-s2-fold-flight.md`).

- The seed provenance cites the same class at the a82cafd basis as
  P_end 5.3691, `:ok` cold start (`scripts/compute_seeds.jl:50-56`).

The launch `a76c5e9` carries the fold. The campaign then searched from
the fold seed. The winner reads r_hub 4.580 m (NR-011) with P_mean
5.309 kW (NR-008).

## 4. The comparison that settles it

Same length, same evaluator basis (a82cafd, after D1 and the cp fix):

- The pre-fold genome reads 4.2332 kW. Fail.

- The folded genome reads 5.3691 kW. Pass.

Neither a pure era story nor a pure design story explains the two rows
alone. The era side moved the same design down (5.10 to 3.7955 to
4.2332). The machine side moved the folded class past the floor. The
screen row describes the pre-fold design under the post-D1 evaluator.
It is not evidence about the launched machine.

## 5. For the room

1. The variant dirs enter tracking with this record, and with them the
   screen runner `scripts/run_length_variants.jl`. This record files
   the six readings as NR-027 and the fold pair as NR-028. The draft
   may cite them if section 2.3 keeps the screen text.

2. Section 2.3 bracket wording: replace "the then-current winner" with
   "the pre-fold island-3 winner (bankderate v1)". One suggested
   sentence joins the two sides. "The D1 site-wind standard re-sized
   this class in October, and the rung folded to the S2 class the same
   day as the screen. The folded class clears the floor at 18.8 m. The
   screen rows describe the pre-fold machine."

3. Section 1.5 closes as one pair. The lead packet carries the era
   side. This record supplies the machine side and the numbers. The
   sign-off gate sits on this seat.

## Receipts

- `scripts/results/length_variants_island3/` and
  `scripts/results/length_variants_island3-cpfix/` — variants.csv,
  variants_trace.csv, genome_used.csv

- `scripts/compute_seeds.jl:46-71` and `scripts/run_length_variants.jl:1-45`

- `docs/validation/2026-10-05-s2-fold-flight.md` and
  `docs/validation/2026-10-05-cp-span-structure-and-resize.md:55`

- `docs/validation/2026-10-03-landing-tip-red.md:37-40`

- `docs/reporting/feedback/2026-10-10-harris-review.md:118-131`

- Ancestry check run 2026-10-10: `a82cafd` to `bd5114e` to `a76c5e9` to
  HEAD, one chain.

Verification status: this seat verified the span-shrink record and
every screen and fold number from repo records. The era-side reading of
5.10 kW and the inferred split sit on the lead packet.
