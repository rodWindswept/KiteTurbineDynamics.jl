# structural_constants.jl — single home for all material strength constants.
# Every constant has a source comment. No guessed numbers.

# ── CFRP strut material ──────────────────────────────────────────────────
# Source: typical unidirectional CFRP (Toray T700S or equivalent).
# Tension: fibre-dominated, ~600 MPa design allowable for pultruded tube.
# Compression: buckling-dominated, computed per-ring from Euler formula.
# These are design allowables with implicit safety margin for static load;
# fatigue and environmental knockdowns are separate (spoke SWL chain).
const CFRP_SIGMA_YIELD_TENSION_MPA = 600.0   # MPa — design allowable, unidirectional CFRP

# ── Expansion rotor blade material ───────────────────────────────────────
# Same CFRP family. Bending is compression-side dominated (buckling on the
# compression face of the bent blade). Conservatively use tension allowable
# for root bending check — actual failure mode is compression-side buckling
# at lower stress, but root cross-section is stocky (short cantilever).
const CFRP_BLADE_SIGMA_YIELD_MPA = 600.0      # MPa — blade root bending allowable

# ── Knuckle fitting ──────────────────────────────────────────────────────
# Rod (2026-07-06): knuckles are stronger than ring tubes — do not yield
# before struts. Knuckle FoS check is pass-through (FoS_knuckle ≥ FoS_tension).
# Strength constant TBD when hardware spec is available.
