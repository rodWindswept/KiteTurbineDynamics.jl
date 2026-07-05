# Get Involved — KiteTurbineDynamics.jl

KiteTurbineDynamics.jl is open-source (MIT) and actively developed. The quickest way to engage:

1. **Clone and test**
   ```bash
   git clone https://github.com/rodread/KiteTurbineDynamics.jl
   cd KiteTurbineDynamics.jl
   julia --project=. test/runtests.jl
   ```
   917 tests in 23 files, Julia 1.12, ~3 min full suite. If the suite isn't green on your machine, that's a bug report we want.

2. **Read the decisions** — `DECISIONS.md` (2,252+ lines) documents every architectural choice from V6 through V10, including the mistakes and the simulator-integrity audit of July 2026. We keep the invalidated results visible; the drift history is part of the record.

3. **Explore the campaigns** — the V10 Tight PCA landscape and non-dimensional physics atlas visualise the 14-dimensional design space (see `scripts/`).

4. **Contact Rod** — rod@windswept.energy. Direct email preferred for initial discussions.

## Where help is most valuable

In priority order (these mirror the Known Limitations in the technical report):

1. BEM / lifting-line cross-validation of the constant-C_L expansion rotor model
2. Wake interaction between rotors (currently: none — downstream rotors see freestream)
3. Dynamic-aware objective function for the DE optimiser (static solver under-predicts dynamic k_mppt ~3.3×)
4. Structural blade design (current blade mass is a constant-thickness skin assumption)
5. Hardware validation of anything — every result is currently simulation-only

> Suggested destination: merge this file's content into the repo README or a top-level `CONTRIBUTING.md` — onboarding instructions belong where the clone happens, not in a PDF.
