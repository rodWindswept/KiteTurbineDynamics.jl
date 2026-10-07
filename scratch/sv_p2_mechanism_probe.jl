# sv_p2_mechanism_probe.jl — static: how many expansion rotors does seed_genome(5.0)
# build in THIS tree?  The EXPANSION_PHYSICS toggles (induction, blade_inertia)
# are consumed only at expansion-rotor sites, so a machine with zero expansion
# rotors cannot show a LEGACY-vs-DEFAULT difference (the P2 guard's premise).
# Used for docs/validation/2026-10-07-acceptance-repoint-fold-tip.md.
# Run: scripts/ktd-julia scratch/sv_p2_mechanism_probe.jl
# Note: predates-present at f9f3182 — `decode_winner` post-dates that revision.
using KiteTurbineDynamics
const ROOT = pwd()
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))   # decode_winner, CLI-guarded

x = seed_genome(5.0)
println("seed = ", x)
d = decode_winner(x; L=18.8, KW=5.0)
println("dec.rotors = ", length(d.dec.rotors), "   n_rings = ", d.dec.n_rings)
for (i, r) in enumerate(d.dec.rotors)
    println("  rotor ", i, ": ring_idx=", r.ring_idx)
end
sys, _u0, _pc = KiteTurbineDynamics.build_system_from_v10(
    d.dec, 1.0, d.k_mp;
    tether_diameter=d.p.tether_diameter, base_params=d.p,
)
println("expansion_rotors = ", length(sys.expansion_rotors))
for (i, er) in enumerate(sys.expansion_rotors)
    println("  er ", i, ": ring_idx=", er.ring_idx, "  n_blades=", er.n_blades)
end
println("MECHANISM_PROBE_DONE")
