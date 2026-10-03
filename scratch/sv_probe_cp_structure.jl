# sv_probe_cp_structure.jl — is the cp_bem/cp_at_tsr gap exactly 1 at n=5, and does it move with λ?
using KiteTurbineDynamics
const BEM = KiteTurbineDynamics.BEM

println("=== ratio cp_bem(n, λ)/cp_at_tsr(λ), across blade counts (λ = 4.1) ===")
for n in 2:10
    r = BEM.cp_bem(n, 4.1) / cp_at_tsr(4.1)
    println("n=", lpad(n, 2), "  cp_bem=", round(BEM.cp_bem(n, 4.1), digits=6),
            "  ratio=", round(r, digits=6))
end

println("\n=== same ratio across λ, at n = 3 (the winner/seed count) and n = 5 ===")
for lam in (3.0, 3.5, 4.1, 4.5, 5.0, 6.0)
    r3 = BEM.cp_bem(3, lam) / cp_at_tsr(lam)
    r5 = BEM.cp_bem(5, lam) / cp_at_tsr(lam)
    println("λ=", lpad(lam, 4), "  n=3 ratio=", round(r3, digits=6),
            "   n=5 ratio=", round(r5, digits=6))
end

println("\n=== the ODE's own number at λ=4.1 vs the sizing number at n=3 ===")
println("cp_at_tsr(4.1) = ", cp_at_tsr(4.1), "   cp_bem(3,4.1) = ", BEM.cp_bem(3, 4.1),
        "   ratio = ", round(cp_at_tsr(4.1) / BEM.cp_bem(3, 4.1), digits=6))
