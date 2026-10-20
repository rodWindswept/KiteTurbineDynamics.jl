# Founder return 3: the comment register (2026-10-20)

**Status:** recorded, not acted. Rod returned the 22:45 build with 103 comments. The copy carries no tracked changes. The extract below is complete. The returned copy joins the repo with its bytes unchanged.

## Disposition update (2026-10-20, evening)

The room ran the six items while this register sat at `7e73e60`. This section records what moved. The register table below keeps its original routing.

- **#100.** The cut exists and it is measured. The apply chain runs `5108e6d1` to `b9d01717` to `265f90d5` to `bfef2c95` to `d54d6ae4`. The final state reads 1222 lines and 10,117 words. STE reads 22 at 0.22, em dash 0. Section 6.1 reads 170 body words in two paragraphs. That is a 79 per cent cut from 799. All five lock strings read one hit each. The builder desk reproduced every state byte for byte. The cut waits on the bless call.

- **#98.** Dropped by #100. The receipt at origin names the drop. It returns only as a `references.bib` entry plus one sentence. The #14 bibliography rebuild is the vehicle.

- **#99.** Landed in cut paragraph 1, from the aero pin. The sentence reads "Tension above the rotor reduces that steer, though it cannot change the phase relation."

- **#95.** Landed. The section 6 intro reads "Many more remain open." and "None of these carries a scored result."

- **#97.** Landed in the cut. The heading reads "Cyclic pitch on the ring rotor". The lifter-stack paragraphs are gone. One note: "expansion rotor" reads 0 in section 6.1, so the expansion half of Rod's "main rotor or the expansion rotors" stays as future text.

- **#83.** Reclassified from AUTHOR to @fig. The strip re-cut needs seven P_end labels. All seven sit in the extract. Mass needs a decode-only pass and a register row first.

- **#93 and #92.** Still open. They are Rod's calls. The ladder plate and the chain analogy stay in place until he rules.

- **The disk draft.** It moved from `daab5102` to `5108e6d1` after this register committed. The G6 write is uncommitted in the working tree. The "still daab5102" line below was true when written. This section supersedes it.

Source: `docs/reporting/feedback/2026-10-20-founder-docx-return-3.docx`, md5 `dcbf3bc7a56e15d2bed969155443bc53d`, 3,266,563 bytes. Extract: `scratch/rodrev/triage.json` at the builder desk.

## What Rod marked

The marked copy carries the G5 text. It does not carry G6. Two probes settle it. The marked body returns 0 hits for `the tether-to-blade rule`. It returns 0 hits for `The machine plates show the blade leaning`. All four do-not-trim strings return exactly 1 hit each.

The tracked draft on disk still reads `daab5102`, 1291 lines, 10,570 words. The G6 patch sits at `03242b1` and nobody has applied it. That fixes the order. Apply G6 first, then fold these comments. A rebuild from the disk state today loses both G6 rulings.

## Six items that are not wording fixes

**1. Comment 100 collides with the do-not-trim list.** Section 6.1 reads 799 words in 18 paragraphs. "One paragraph maybe two max" cuts about 80 per cent. Three lock strings sit in paragraph 581. The fourth sits in paragraph 590. The cut can keep them only if it runs around them. This needs one ruling. The cut wins and the strings move into the surviving paragraph, or the strings hold and the cut stops at two paragraphs.

**2. Comment 93 removes a plate.** The scaling ladder is one of nine embedded plates. Remove it and the census reads 8 plates, 8 provenance rows and 8 roster blocks. It also touches the section 5 caption block, the section 5 sentence at 569, and the figure-generation notes. @fig must re-verify the nine-to-nine match after this edit. Do not assume the match survives.

**3. Comment 97 changes the section 6.1 heading and drops two paragraphs.** The heading reads "Cyclic pitch and the lift kite". Paragraph 576 holds the lifter-stack swashplate. Paragraph 586 holds the teetering-hub existence proof. Rod scopes 6.1 to the main rotor and the expansion rotors. The heading changes. Both paragraphs go.

**4. Comment 14 is the largest gap, and the references chapter holds no citations.** The chapter reads "Seeded in references.bib. Seventeen sources. Sixteen carry verified sources." The body returns 0 hits for `DOI` and 0 for `doi`. Loyd, Diehl, Trevisi, Cherubini and Van der Burg each appear once, in one paragraph, with no year, no title and no link. This needs a new bibliography section. A wording edit cannot close it.

**5. Comment 88 names a real omission.** The body returns 0 hits for `dashboard`, 0 for `notebook` and 0 for `simulator`. The repo holds all three. One paragraph in section 9 closes it.

**6. The 168 direction fact has an answer, and the ruled sentence is one step off.** Rod states the blade tip aims at a point on the TRPT section line. The tip does not run to the next ring, because that run costs bridle line drag. The ruled G6 sentence reads "The machine plates show the blade leaning downward, toward the ring below." The lean is true. "Toward the ring below" overstates the target. Four words fix it. The fix lands on G6, which is not on disk yet.

## Routing

| Class | Count | Owner | What it needs |
|---|---|---|---|
| RULING | 11 | Rod | A scope, deletion or structure call. Each one moves pages or the plate census. |
| SOURCE | 26 | @aero-validator | One pinned number or code path before any prose is written. |
| AUTHOR | 41 | @author | Prose only. No new number. |
| FIG | 9 | @fig | A plate, a reorder, or a deletion. |
| BUILDER | 16 | @hermes | Build-level. Headings, ordering, hyperlinks, notation. No prose change. |

## The register

Anchored text is quoted as it sits in the marked copy. A section name comes from the nearest heading above the anchor.

One build item carries the most work. Comment 0 covers 173 parenthetical `NR-` references and 403 `NR` tokens in the body. Each one takes a subscript format and a link to its register row. That is a builder change. It repeats on every rebuild.

| ID | Section | Anchored text | Rod's note | Class | Owner |
|---|---|---|---|---|---|
| 0 | The kite turbine: a search over its design space | (NR-001) | Make all of the (NR-...) references a smaller subscript font hyperlinked to the relevant place | BUILDER | @hermes |
| 1 | The kite turbine: a search over its design space | At the winner operating point, the least segment torque margin is 2.03... | Jumbles order paragraph needs sorted | BUILDER | @hermes |
| 2 | The kite turbine: a search over its design space | the least segment torque margin | Segment torque margin is not yet explained | SOURCE | @aero-validator |
| 3 | The kite turbine: a search over its design space | All numbers carry the physics era post-95c385d_wind-authority, with th... | These concepts need introduced | AUTHOR | @author |
| 4 | The kite turbine: a search over its design space | outer stiffening bridles sit outside the model | Used in real field trial kite turbines are not included in this model | AUTHOR | @author |
| 5 | The kite turbine: a search over its design space | Lifter kite | The ability for a lifter kite to modulate and maintain constant tension across wind speeds. | AUTHOR | @author |
| 6 | The kite turbine: a search over its design space | Summary for decision. The project completed a 930-design simulation sc... | Within gated performance bounds | AUTHOR | @author |
| 7 | The kite turbine: a search over its design space | The rapid path | Rapid path not yet introduced… Is there even any point introducing it yet as it was mostly unused | RULING | Rod |
| 8 | The kite turbine: a search over its design space | feasible 5 kW-class candidate | hyperLink to winner section | BUILDER | @hermes |
| 9 | The kite turbine: a search over its design space | The report shows that a feasible 5 kW-class candidate exists in the se... | Extension hyperlink to section | BUILDER | @hermes |
| 10 | 1 Introduction | The field splits a second way, on the wing. Soft wings use fabric. The... | , but brittle and more costly | AUTHOR | @author |
| 11 | 1 Introduction | A third split matters for this report. It is the force transmission of... | mechanical | AUTHOR | @author |
| 12 | 1 Introduction | The machine in this report is a kite turbine. Kite turbines exploit mu... | Kite blades | AUTHOR | @author |
| 13 | 1 Introduction | The machine in this report is a kite turbine. Kite turbines exploit mu... | The rotating shaft is held by a wheel on the ground station. When the shaft turns this wheel the ground station generator converts the rotational power to electrical power. | AUTHOR | @author |
| 14 | 1 Introduction | Loyd showed that both crosswind modes share one theoretical power ceil... | Where are the classic literature citation references? Need better documentation standard here… To be valid we must share these doi links | RULING | Rod |
| 15 | 2.1 The kite turbine and its terms | A line is a tension member, like a tether or a bridle. It carries a lo... | Insert a labelled parts diagram between the header and 1st paragraph with all of the introduced parts terms for this section | FIG | @fig |
| 16 | 2.1 The kite turbine and its terms | Inactive genome slots may hold bank or blade-scale values. They do not... | We haven't introduced the genome yet.  We need an introduction on the genome before this sentence. Otherwise This should be later. | AUTHOR | @author |
| 17 | 2.1 The kite turbine and its terms | That radius is not the ring radius. The ring radius r_hub is a separat... | I think there's a simpler way to say this. . . The size of the blade is worked out From the ring annulus area it's going to sweep. And the genome enables us to experiment with that scale. | AUTHOR | @author |
| 18 | 2.1 The kite turbine and its terms | reads | Does reads mean “is set at” ? | AUTHOR | @author |
| 19 | 2.1 The kite turbine and its terms | P reads the rotor power share and v the local wind speed at the ring. ... | Is that the full span of the rotor? How much of the rotor is inboard of the ring? Outboard of the ring? | AUTHOR | @author |
| 20 | 2.1 The kite turbine and its terms | The search treats each of these as a gene. The ring geometry sets the ... | This sentence could be much higher up in this section. | BUILDER | @hermes |
| 21 | 2.1 The kite turbine and its terms | The shaft transition cone holds one fixed angle, 22 degrees, by constr... | Why do we have a fixed 22 degrees? Add a sentence on that here. | SOURCE | @aero-validator |
| 22 | 2.1 The kite turbine and its terms | load the machine | And line drag. | AUTHOR | @author |
| 23 | 2.1 The kite turbine and its terms |  | Keep this image here but we do need the other similar image at the start of this section. | FIG | @fig |
| 24 | 2.1 The kite turbine and its terms | The plate shows the campaign winner in a side view. Six triangular rin... | There's a lot of duplication here.  A Figure doesn't need a title, and a subtitle. If the figure shows it, we don't need to restate what the figure shows. | BUILDER | @hermes |
| 25 | 2.2.1 The gene | The ring count builds separately. A spacing pass lays the intermediate... | It would be helpful to have a figure which shows the effect of each gene, what it's working on, how it affects the design. | FIG | @fig |
| 26 | 2.2.2 The evaluator | takes 10 seconds | Is this simulates 10 seconds of startup from stopped? | SOURCE | @aero-validator |
| 27 | 2.2.2 The evaluator | takes 40 seconds | Is this Then we analyze the next 40 seconds of Rotation after the transient has died down..? | SOURCE | @aero-validator |
| 28 | 2.2.2 The evaluator | short | Shorter could | AUTHOR | @author |
| 29 | 2.2.2 The evaluator | absolute segment twist divided by the crossing limit | Terms Need intro... more explanation. | AUTHOR | @author |
| 30 | 2.3 The operating point and load selection | load, | Load profile | AUTHOR | @author |
| 31 | 2.3 The operating point and load selection | load | Load profile… Why only 1? | SOURCE | @aero-validator |
| 32 | 2.3 The operating point and load selection | ratio. | What effect does this have on optimal design for a blade's ideal tip speed ratio? | AUTHOR | @author |
| 33 | 2.3 The operating point and load selection | The sweep ran the seed at a range of loads, each over the same measure... | There's something here we can say in the later section about work to come… Extension work | AUTHOR | @author |
| 34 | 2.3 The operating point and load selection | light end | Light end of what? Explain yourself more clearly here. | AUTHOR | @author |
| 35 | 2.3 The operating point and load selection | At the light end the seed spins up. | Seed turbine.spins up to what? | SOURCE | @aero-validator |
| 36 | 2.3 The operating point and load selection | (TIP_SPEED_CEILING_MPS). | Which is limited to how many meters per second? | SOURCE | @aero-validator |
| 37 | 2.3 The operating point and load selection | At the heavy end the load raises the torque and the line tension, so F... | We ran a sweep of KMPPT responses here and I thought we had some figures, charts, graphs which showed the applicability helped to explain and the two sides we could operate on.  It would be ... | FIG | @fig |
| 38 | 2.3 The operating point and load selection | At the heavy end the load raises the torque and the line tension, so F... | Should this sentence be after where we've introduced the objective? | BUILDER | @hermes |
| 39 | 2.3 The operating point and load selection | bounded generator load step: twice the nominal load (NR-048). | Explain the reasoning for why we do that. | SOURCE | @aero-validator |
| 40 | 2.3 The operating point and load selection | The team refuses to ease k as the high-wind substitute. | Explain the consequence of easing K in high wind before stating that we refuse to do it. This gives us the reason for why we refuse to do it. | AUTHOR | @author |
| 41 | 2.3 The operating point and load selection | The rotor spins up to 87.9° of twist against the 78.8° collapse limit | Is this the reason why we refuse to ease K in high wind? Make that clear. | SOURCE | @aero-validator |
| 42 | 2.3 The operating point and load selection | Daisy anchor | Daisy device whose design parameters and performance anchor the instrument and measurements for this campaign | AUTHOR | @author |
| 43 | 2.3 The operating point and load selection | It | The length of the turbine which flies at 30 degrees elevation | AUTHOR | @author |
| 44 | 2.3 The operating point and load selection | line | Or beam | AUTHOR | @author |
| 45 | 2.3 The operating point and load selection | ring | Ring beam? | AUTHOR | @author |
| 46 | 2.3 The operating point and load selection | The evaluator derives the step per machine from the shortest shaft sub... | Say why we do that. | SOURCE | @aero-validator |
| 47 | 2.3 The operating point and load selection | line ends | Or beam FoS breach? Or overtwist condition? | AUTHOR | @author |
| 48 | 2.4 The campaign | The over-power charge reads P_score, the end power, against the 5.0 kW... | and penalizes it by how much | SOURCE | @aero-validator |
| 49 | 2.4 The campaign | The utilisation charge reads the window-minimum factor of safety again... | and calculates the penalization score by how much? What calculation? | SOURCE | @aero-validator |
| 50 | 2.4 The campaign | The over-power charge reads P_score, the end power, against the 5.0 kW... | Then adds the penalty How? | SOURCE | @aero-validator |
| 51 | 2.4 The campaign | The over-power charge reads P_score, the end power, against the 5.0 kW... | Is this penalized? How is it penalized? | SOURCE | @aero-validator |
| 52 | 2.4 The campaign | The code floors the denominator at 1e-6. The ratio reads one million a... | What is this relating to? | SOURCE | @aero-validator |
| 53 | 2.4 The campaign | The code floors the denominator at 1e-6. The ratio reads one million a... | So the scoring is based on that? | SOURCE | @aero-validator |
| 54 | 2.4 The campaign | clearance gate. | This makes multi rotor setups slightly less likely to be viable at this scale. | SOURCE | @aero-validator |
| 55 | 2.4 The campaign | These reject the design outright, and a rejected design carries no sco... | To me it feels like this whole section needs broken into subsections of each one of the penalties and a good description of their formulation, & how they are applied. | RULING | Rod |
| 56 | 2.4 The campaign | NR-015 | Sounds like this table should be at the top of this section. | BUILDER | @hermes |
| 57 | 2.5 Fidelity paths | Two paths score a design. The ODE path builds the machine, settles it,... | I think we need to be much more clear about what the two different paths contribute and how they were used. | RULING | Rod |
| 58 | 2.5 Fidelity paths | The register header pins their commits. | If we observed that the warm path was becoming less reliable, we should flag the point in the report where we discussed that. | RULING | Rod |
| 59 | 3.1 The search at scale | 36 refuse on rotor spacing. | Is this the first time we've mentioned this gate? | AUTHOR | @author |
| 60 | 3.1 The search at scale | Betz ceiling. | It's the first time we've mentioned the Betz gate. | AUTHOR | @author |
| 61 | 3.3 The winner | The island-3 winner at its final operating step. The machine reads six... | It's best that we just have one section paragraph to explain the figure. We don't need a title, subtitle.  we don't need repetition. | BUILDER | @hermes |
| 62 | 3.3 The winner | The bow | Introduce what bow isProbably best to have a simple figure diagram of what bow represents.  This could also include what you mean by extension steps in the next semtence. | FIG | @fig |
| 63 | 3.3 The winner | the extension steps | You'll have to explain what you mean by extension steps. Is this how much the machine stretches? | AUTHOR | @author |
| 64 | 3.3 The winner | The shaft axis bows off its design line, sagging straight down. At the... | This paragraph should come before the last one. | BUILDER | @hermes |
| 65 | 3.3 The winner | An extension run past the window ends at 0.422 m | Disturbing that even I don't know what you mean here. | AUTHOR | @author |
| 66 | 3.3 The winner | The swept area reads 45.9733 square metres raw and 39.4912 square metr... | A diagram of the coned annulus and its sweep on the wind normal plane would really help this. | FIG | @fig |
| 67 | 3.3 The winner | degrees | Is that total per full TRPT shaft? | SOURCE | @aero-validator |
| 68 | 3.3 The winner | aloft. | via lifting thrust bearing. | AUTHOR | @author |
| 69 | 3.3 The winner | knot. | With the backline, which restricts the  height of the sky anchor | AUTHOR | @author |
| 70 | 3.3 The winner | report. The | A separate analysis into stacking auto gyro lifters is being performed. | AUTHOR | @author |
| 71 | 3.3 The winner | The three movers carry their records. | The reasoning for these three changes is... | AUTHOR | @author |
| 72 | 3.3 The winner | depowering of the main-rotor disc | With respect to how the cone shape of rotor bank reduces the power available from the rotor. | AUTHOR | @author |
| 73 | 3.3 The winner | recorded. | Explain the cause or link to the sentence that does. | AUTHOR | @author |
| 74 | 3.4 The levers of performance | √(M_ip²+M_oop²)/M_el. | It should be in mathematical notation. | BUILDER | @hermes |
| 75 | 3.4 The levers of performance | All five TRPT segments remain inside their over-twist limits at the wi... | Again, we don't need a title heading, subheading. We just need title and paragraph. | BUILDER | @hermes |
| 76 | 3.4 The levers of performance | The winner is not close to ring buckling, over-twist or segment torque... | Pretty sure some of the reports we had previously had time series twist margins and spectral frequency power response charts … This is the full report, the big one. I want to see that kind o... | FIG | @fig |
| 77 | 3.4 The levers of performance |  | We probably need a section here to introduce PCA analysis. What it is and how the PCA divides. | FIG | @fig |
| 78 | 3.4 The levers of performance | One seed, three islands: this figure maps the search journeys in gene ... | Again, just a title and a paragraph is all we need. | BUILDER | @hermes |
| 79 | 3.4 The levers of performance | The figure repeats one PC1-PC2 projection of the 930-design screen ten... | Again, just a title and a paragraph is what we need. | BUILDER | @hermes |
| 80 | 3.4 The levers of performance | Four panels show the nearest feasible design to each corner of the [1,... | And just a title and a paragraph is all these figures need. This particular figure probably belongs above the result ones As it explains The variation of the PCA chart | BUILDER | @hermes |
| 81 | 3.5 The evolution story | Island 3's best-so-far objective falls from 36.109 to 27.364 kg-equiva... | Title and paragraph only. | BUILDER | @hermes |
| 82 | 3.5 The evolution story | A later campaign can vary it. | Did we discuss why yet? | SOURCE | @aero-validator |
| 83 | 3.5 The evolution story | The strip shows built geometry and the search objective only. The stri... | That's a good point, it would be really good if it did. | AUTHOR | @author |
| 84 | 3.5 The evolution story | A longer or broader run would extend the search. | Longer, more than 930, broader, a wider set of search parameters and a longer genome. | SOURCE | @aero-validator |
| 85 | 3.6 Design implications | shaped penalty. | or by flying systems  longer than 18.8 meters | SOURCE | @aero-validator |
| 86 | 3.6 Design implications | Use the rapid path for screening under its fixed rope-break gate (NR-0... | Is this a recommended next step? What is the advantage? | AUTHOR | @author |
| 87 | 3.6 Design implications | Add blade root factor-of-safety checks to the structural gate set. | or add in the bridle lines to the blades which mostly negate that structural safety check need as they take out the shear stress. | SOURCE | @aero-validator |
| 88 | 3.6 Design implications | Extend the model to the launch and recovery sequence. | We have not even mentioned yet that the repo has simulators, the dashboard and the notebook available. These should be mentioned. | AUTHOR | @author |
| 89 | 3.6 Design implications | Extract the lever statistics from the campaign telemetry. | This does not sound like a heavy job. Can we do that? Soon. | AUTHOR | @author |
| 90 | 4.1 Evaluation fidelity | The lesson stands. The rapid path is the evaluator default. Any consum... | I feel like a flowchart or systems chart  would help clearly depict this situation | FIG | @fig |
| 91 | 5 Conclusion | The expansion rotor model | We introduced the concept of an expansion rotor yet? Basically a rotor with banked blades tends more towards expansion as the lift forces vector outwards from the center of the rotor | SOURCE | @aero-validator |
| 92 | 5 Conclusion |  | This is totally extraneous. Yes, we want to build larger systems. We can say it without this analogy. | RULING | Rod |
| 93 | 5 Conclusion | The ladder draws the seven rungs of the scale-up programme at equal sp... | probably just ditch this there's so little data in this ladder concept | RULING | Rod |
| 94 | 5 Conclusion | win | They win or maybe more likely viable or optimal. | SOURCE | @aero-validator |
| 95 | 6 Potential extension work | This section sets out three of them. | There are many more than three potential extensions of this work. There are colossal number of parameters we haven't looked at yet. And complexities we might want to consider. | RULING | Rod |
| 96 | 6 Potential extension work | and the test that would | Do we mention at any point the fact that we used to have a diameter, beam diameter, in the genome, and that maybe we should look at this again? | SOURCE | @aero-validator |
| 97 | 6.1 Cyclic pitch and the lift kite | That BEM belongs to the lifter stack. The lifter stack carries a swash... | We are not considering analysis of the lift kite. We only want to consider cyclic pitch analysis for the main rotor or the expansion rotors. | RULING | Rod |
| 98 | 6.1 Cyclic pitch and the lift kite | Cyclic pitch is a control mechanism, | Cyclic Pitch on Rotary AWES is being investigated by someawe.org | AUTHOR | @author |
| 99 | 6.1 Cyclic pitch and the lift kite | The tilt azimuth turns whenever the rotor phase lag is not zero. The t... | These effects are probably much less noticeable in a continuously stacked system where there's lift above the rotor from another rotor. | SOURCE | @aero-validator |
| 100 | 6.1 Cyclic pitch and the lift kite | The test has two legs. First, can one-per-rev cyclic pitch on a TRPT r... | We've gone far too deep into the weeds of this potential extension work 6.1 cyclic pitch. One paragraph maybe two max would do for the whole section. | RULING | Rod |
| 101 | 6.2 Cost of energy with scale | e study | The proposal here is to study. | AUTHOR | @author |
| 102 | 6.2 Cost of energy with scale | The test: one curve and one method. Each printed point needs a signed ... | And we can shorten this to just the basics. A simple sentence on what it takes to do LCOE and how we need prototypes tested in the field to gather the data on build costs. | RULING | Rod |

## What happens next, in order

1. Rod takes the six items above. Item 1 is the only one that blocks a section.
2. @hermes applies G6. Then it folds the 16 builder items and the corrected 168 sentence.
3. @aero-validator pins the 26 SOURCE numbers.
4. @author writes the 41 prose items against those pins.
5. @fig takes the 9 figure items, counting the census change from item 2.
6. Rebuild. Then text probe. Then the STE read.

Nothing in this register is committed to the draft. The draft is still `daab5102`.
