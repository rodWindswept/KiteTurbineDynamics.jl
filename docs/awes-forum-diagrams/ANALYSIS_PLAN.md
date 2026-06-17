# V6.2 Campaign Results Analysis Plan

## Goal
Systematically extract, verify, and document every pattern in the V6.2 corrected-physics
campaign results so that all 5 AWES forum diagrams are populated from real data, not
hand-waved formulas or schematic guesses.

## Phase 0: Inventory what we have

### 0.1 Campaign scripts
Locate and read every script that was used to run V6.2 campaigns:
- The main campaign runner (likely `scripts/v6_campaign_runner.jl` or similar)
- Any sensitivity sweep scripts
- The DE optimizer configuration (bounds, island count, migration strategy)

### 0.2 Campaign outputs
- `scripts/results/v6_2_campaign_50kw/best_design.json` — single best design
- `scripts/results/v6_2_campaign_50kw/convergence_history.csv` — 600K rows, columns: island, iteration, mass_kg
- Any other result files in that directory
- `v6_campaign*.log` files in repo root — full campaign stdout

### 0.3 What's missing (must generate)
- Per-n_lines sensitivity: separate campaign runs at n=3,6,8,10,12 with all other params free
- Per-β sensitivity: sweep β while holding other params at optimum
- Per-n_exp sensitivity: sweep n_exp while holding other params at optimum
- Per-iteration parameter traces: what values did the best island try along its path

## Phase 1: Extract patterns from convergence history

### 1.1 Best-island trajectory
- Identify island 35 (best island) from best_design.json
- Extract its full mass-vs-iteration trace
- Plot convergence: does it show plateau-jump-plateau pattern? Smooth descent?
- Record: initial mass, final mass, number of iterations to within 5% of final

### 1.2 Island diversity
- For each of the 60 islands, extract its final (best) mass
- Histogram of final masses: are they clustered? How many islands found <100 kg? <80 kg?
- This tells us whether n=12 at 74.17 kg is a robust global minimum or a lucky find

### 1.3 Mass distribution explored
- Sample random iterations across all islands
- Histogram of all masses evaluated — what was the range?
- This shows whether the optimizer explored a wide design space

## Phase 2: Targeted sensitivity sweeps (MUST RUN)

### 2.1 n_lines sweep
- Fix all params at optimum values from best_design.json
- Vary n_lines = 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
- For each n, run a SHORT settle+sim (not full campaign) to get mass
- Record: mass, Do, knuckle_mass, beam_mass breakdown
- This gives us the CURVE for d3's right panel
- This also gives us per-component mass for understanding the coupled effect

### 2.2 β (density_profile) sweep
- Fix n=12, other params at optimum
- Sweep β = -0.8, -0.6, -0.4, -0.2, -0.13, 0.0, 0.2, 0.4, 0.6, 0.8
- For each β, run short settle+sim
- Record mass
- This gives us the CURVE for d4 panel 3
- We need to verify: is β=-0.13 actually the minimum? Or is the curve flat?

### 2.3 n_expansion sweep
- Fix n=12, β=-0.13, other params at optimum
- Vary n_exp = 0, 1, 2, 3, 4, 5, 6
- For each, also vary blade_tip_radius and blade parameters appropriately
- Record mass
- This gives us the CURVE for d4 panel 4

### 2.4 Beam-mass-only formula verification
- For a single ring at fixed radius, vary n = 3..12
- Compute beam mass using the ACTUAL code's beam_spec_at_ring + trpt_optimization mass calculation
- Plot beam mass vs n — this is the TRUE beam-only model
- Record the EXACT formula that emerges (is it n·sin(π/n)? n·sin^(3/2)? something else?)
- This replaces the unverified n·√sin(π/n) in d3

## Phase 3: Document patterns

### 3.1 Pattern catalogue
For each sweep, record:
- The exact script and commit that produced the data
- The parameter values used
- The raw output data (CSV)
- A plot of the result
- A 1-paragraph description of the pattern observed
- Any surprises or counterintuitive findings

### 3.2 Cross-validation
- Do the sensitivity sweep results agree with the campaign optimum?
- If β sweep says minimum at β=-0.1 but campaign found β=-0.13 — that's close enough
- If n_exp sweep says n_exp=2 is better than n_exp=1 — that contradicts the campaign and needs investigation

### 3.3 Uncertainty quantification
- How flat is each curve near the minimum?
- If n=10 and n=12 give nearly the same mass, say so — don't oversell n=12
- If β sweep is very flat from -0.5 to +0.2, the "sign flip" narrative is weaker than we've been claiming

## Phase 4: Populate diagrams from real data

### 4.1 d1 (polygon comparison)
- Data: confirmed from best_design.json (n=12, 74.17 kg) + old V6 baseline (n=8, 259 kg)
- These are the two anchor points — both from actual campaign runs
- No unverified formulas needed for this diagram

### 4.2 d2 (density profile)
- β value confirmed from best_design.json: -0.1286...
- Old β=+0.76 from pre-correction campaign (document it as historical, not current)
- The ring radius distribution formula comes from ring_spacing.jl code

### 4.3 d3 (mass scaling)
- Left panel: actual beam-mass-only formula from Phase 2.4
- Right panel: actual n_lines sweep from Phase 2.1
- No more n·√sin(π/n) unless verified

### 4.4 d4 (optimization landscape)
- Panel 1: convergence history from Phase 1
- Panel 2: n_lines from Phase 2.1
- Panel 3: β sweep from Phase 2.2
- Panel 4: n_exp sweep from Phase 2.3
- All panels populated from real data, not schematics

### 4.5 d5 (bank angle)
- Pending Rod's dashboard verification
- Once geometry is confirmed, generate from first principles

## Phase 5: Report writing

Only after ALL phases complete:
- Write the conference report sections backed by real data
- Every number traceable to a specific sweep or campaign run
- Honest about uncertainty — flag any flat curves or weak patterns

## Execution order
1. Phase 0 (inventory) — 30 minutes
2. Phase 2.4 (beam formula verification) — 30 minutes
3. Phase 1 (convergence patterns) — 1 hour
4. Phases 2.1-2.3 (sensitivity sweeps) — 3-4 hours (mostly compute)
5. Phase 3 (document patterns) — 1 hour
6. Phase 4 (regenerate diagrams) — 2 hours
7. Phase 5 (report writing) — 3-4 hours

Total: approximately 12-14 hours of work.
