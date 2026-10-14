#!/usr/bin/env julia
# scratch/sv_r6_count_nr051_check.jl — science-validator, 2026-10-14.
#
# The round-6 seat packet, independent reads (no simulator, no ODE):
#   1. The count glance (NR-002): 508 of 930.  Status census of the three
#      committed island telemetry files.
#   2. The corner-grid picks (the NR-051 proposal).  The projection
#      replicates the certified pca-landscape kit (NR-044) in Julia — a
#      different instrument than the kit's numpy path.  Every anchor
#      gates BEFORE any pick prints.  The four picks re-derive as the
#      least-distance feasible design to each [1,99] percentile window
#      corner.
#   3. A diagonal-extreme secondary read, within the window and over the
#      whole feasible set, recorded beside the mint's cross-check note.
#
# Run: JULIA_DEPOT_PATH=$PWD/.julia_depot julia --project=. \
#      scratch/sv_r6_count_nr051_check.jl

using LinearAlgebra
using Statistics
using Printf

const RD = joinpath(pwd(), "scripts", "results",
                    "v13_5kw_masslift_len18.8_rotorcount_bankderate2")

n_ck = Ref(0)
n_fail = Ref(0)
function chk!(name, cond, detail = "")
    n_ck[] += 1
    cond || (n_fail[] += 1)
    println("check: $(name): $(cond ? "OK" : "FAIL")  $(detail)")
end

function load_rows()
    rows = NamedTuple[]
    for isl in 1:3
        ls = readlines(joinpath(RD, "island_$(isl)", "telemetry.csv"))
        idx = nothing
        for ln in ls
            s = strip(ln)
            (isempty(s) || startswith(s, "#")) && continue
            if idx === nothing
                idx = Dict(c => i for (i, c) in enumerate(split(s, ",")))
                continue
            end
            f = split(s, ",")
            push!(rows, (
                isl = isl,
                gen = parse(Int, f[idx["gen"]]),
                ridx = parse(Int, f[idx["idx"]]),
                X = [parse(Float64, f[idx["x$(i)"]]) for i in 1:10],
                fit = parse(Float64, f[idx["fitness"]]),
                st = f[idx["status"]],
            ))
        end
    end
    rows
end

rows = load_rows()
n = length(rows)
per_isl = [count(r -> r.isl == i, rows) for i in 1:3]
statuses = Dict{String,Int}()
for r in rows
    statuses[r.st] = get(statuses, r.st, 0) + 1
end

X = permutedims(reduce(hcat, [r.X for r in rows]))
fit = [r.fit for r in rows]
st = [r.st for r in rows]
feas = [s == "ok" && f < 1e6 for (s, f) in zip(st, fit)]

println("== 1. the count glance ==")
@printf("rows: %d  per island: %d/%d/%d\n", n, per_isl...)
println("statuses: ", join(["$k=$v" for (k, v) in sort(collect(statuses))], " "))
chk!("rows 930", n == 930, "got $(n)")
chk!("per island 310", per_isl == [310, 310, 310], string(per_isl))
chk!("status mix", statuses == Dict("ok" => 508, "reject" => 301,
                                    "clearance_reject" => 110,
                                    "reject_twist" => 11),
    string(sort(collect(statuses))))
chk!("feasible rows 508", count(feas) == 508, "got $(count(feas))")

println("\n== 2. the projection (NR-044 anchors first) ==")
mu = sum(X, dims = 1) ./ n
sd = [sqrt(sum(abs2, X[:, j] .- mu[j]) / (n - 1)) for j in 1:10]
Z = (X .- mu) ./ permutedims(sd)
F = svd(Z)
s2 = F.S .^ 2
frac = s2 ./ sum(s2)
shares = 100 .* frac
V = F.V
pc1 = Z * V[:, 1]
pc2 = Z * V[:, 2]

@printf("PC1 share = %.10f -> %.6f\n", shares[1], round(shares[1], digits = 6))
@printf("PC2 share = %.10f -> %.6f\n", shares[2], round(shares[2], digits = 6))
@printf("pair total = %.10f -> %.6f\n", shares[1] + shares[2],
        round(shares[1] + shares[2], digits = 6))
chk!("PC1 share x1e6", round(Int, frac[1] * 1e6) == round(Int, 0.22434667 * 1e6),
    @sprintf("%.10f", shares[1]))
chk!("PC2 share x1e6", round(Int, frac[2] * 1e6) == round(Int, 0.17263044 * 1e6),
    @sprintf("%.10f", shares[2]))
chk!("pair total x1e6",
    round(Int, (frac[1] + frac[2]) * 1e6) == round(Int, 0.39697710 * 1e6),
    @sprintf("%.10f", shares[1] + shares[2]))

seed_i = findfirst(r -> r.isl == 1 && r.gen == 0, rows)
win_i = argmin([feas[i] ? fit[i] : Inf for i in 1:n])
@printf("seed: i%d-g%d-%d  pc (%.6f, %.6f)  fit %.6f\n",
        rows[seed_i].isl, rows[seed_i].gen, rows[seed_i].ridx,
        pc1[seed_i], pc2[seed_i], fit[seed_i])
@printf("winner: i%d-g%d-%d  pc (%.6f, %.6f)  fit %.6f  island %d\n",
        rows[win_i].isl, rows[win_i].gen, rows[win_i].ridx,
        pc1[win_i], pc2[win_i], fit[win_i], rows[win_i].isl)
chk!("seed pc 3dp", (round(pc1[seed_i], digits = 3), round(pc2[seed_i], digits = 3)) == (0.531, -1.297))
chk!("winner pc 3dp", (round(pc1[win_i], digits = 3), round(pc2[win_i], digits = 3)) == (0.885, 2.869))
chk!("seed fit 3dp", round(fit[seed_i], digits = 3) == 36.109)
chk!("winner fit 3dp", round(fit[win_i], digits = 3) == 27.364)
chk!("winner island 3", rows[win_i].isl == 3)

x1w, x2w = quantile(pc1, [0.01, 0.99])
y1w, y2w = quantile(pc2, [0.01, 0.99])
@printf("window: pc1 [%.3f, %.3f]  pc2 [%.3f, %.3f]\n", x1w, x2w, y1w, y2w)
chk!("window pc1 3dp", (round(x1w, digits = 3), round(x2w, digits = 3)) == (-5.133, 1.671))
chk!("window pc2 3dp", (round(y1w, digits = 3), round(y2w, digits = 3)) == (-2.178, 3.125))

println("\n== 3. the four picks ==")
corners = [
    ("low PC1 / low PC2",   x1w, y1w, "i1-g13-i1", (-1.454423, -1.238178), 60.646),
    ("low PC1 / high PC2",  x1w, y2w, "i1-g7-i7",  (-2.088227, 0.152353),  58.864),
    ("high PC1 / low PC2",  x2w, y1w, "i2-g21-i4", (1.132051, -1.488592),  33.704),
    ("high PC1 / high PC2", x2w, y2w, "i3-g26-i8", (1.679755, 3.050611),   33.812),
]
pick_tag = Dict{String,String}()
for (cname, cx, cy, want_tag, (wpc1, wpc2), wfit) in corners
    d = sqrt.((pc1 .- cx) .^ 2 .+ (pc2 .- cy) .^ 2)
    d_feas = [feas[i] ? d[i] : Inf for i in 1:n]
    i = argmin(d_feas)
    r = rows[i]
    tag = "i$(r.isl)-g$(r.gen)-i$(r.ridx)"
    pick_tag[cname] = tag
    @printf("\n%s corner (%.3f, %.3f):\n", cname, cx, cy)
    @printf("  pick: %s  pc (%.6f, %.6f)  fit %.6f  dist %.6f\n",
            tag, pc1[i], pc2[i], fit[i], d[i])
    chk!("pick tag $cname", tag == want_tag, tag)
    chk!("pick pc $cname", (round(pc1[i], digits = 6), round(pc2[i], digits = 6)) == (wpc1, wpc2))
    chk!("pick fit 6dp $cname", round(fit[i], digits = 6) == wfit)
    chk!("pick display 3dp $cname", round(fit[i], digits = 3) == round(wfit, digits = 3))
    ia = argmin(d)
    @printf("  context: nearest-all reads status %s (dist %.3f); the pick stays feasible\n",
            rows[ia].st, d[ia])
    nl = round(Int, r.X[4])
    rc = clamp(round(Int, r.X[6]), 1, 3)
    @printf("  genes: n_lines %d  rotor_count %.6f -> %d  bank_top %.4f  bank_bottom %.4f  blade_scale_top %.4f\n",
            nl, r.X[6], rc, r.X[7], r.X[8], r.X[9])
end

# composition read: low-PC1 picks many-line two-rotor; high-PC1 picks one-rotor
nl_of = [round(Int, rows[argmin([feas[i] ? sqrt((pc1[i]-cx)^2 + (pc2[i]-cy)^2) : Inf for i in 1:n])].X[4])
         for (cname, cx, cy, _, _, _) in corners]
rc_of = [clamp(round(Int, rows[argmin([feas[i] ? sqrt((pc1[i]-cx)^2 + (pc2[i]-cy)^2) : Inf for i in 1:n])].X[6]), 1, 3)
         for (cname, cx, cy, _, _, _) in corners]
chk!("low picks many-line (7, 8)", nl_of[1] == 7 && nl_of[2] == 8, "low n_lines $(nl_of[1:2])")
chk!("low picks two-rotor", rc_of[1] == 2 && rc_of[2] == 2, "low rotor count $(rc_of[1:2])")
chk!("high picks one-rotor lines (3, 3)", nl_of[3] == 3 && nl_of[4] == 3, "high n_lines $(nl_of[3:4])")
chk!("high picks one-rotor", rc_of[3] == 1 && rc_of[4] == 1, "high rotor count $(rc_of[3:4])")

# winner gene mapping sanity (pins the column order without reading the decoder)
rw = rows[win_i]
chk!("winner n_lines reads 3", round(Int, rw.X[4]) == 3)
chk!("winner rotor count reads 1", clamp(round(Int, rw.X[6]), 1, 3) == 1)
chk!("winner blade scale top ~0.821", isapprox(rw.X[9], 0.821; atol = 0.01),
    @sprintf("%.6f", rw.X[9]))
chk!("winner blade scale bottom ~0.20", isapprox(rw.X[10], 0.20; atol = 0.01),
    @sprintf("%.6f", rw.X[10]))

println("\n== 4. the diagonal-extreme secondary read ==")
inwin = [x1w <= pc1[i] <= x2w && y1w <= pc2[i] <= y2w for i in 1:n]
sumv = pc1 .+ pc2
diffv = pc1 .- pc2
specs = [
    ("low PC1 / low PC2",   sumv,  false),
    ("low PC1 / high PC2",  diffv, false),
    ("high PC1 / low PC2",  diffv, true),
    ("high PC1 / high PC2", sumv,  true),
]
for (cname, v, maximise) in specs
    for (label, mask) in [("window", feas .& inwin), ("all-feasible", feas)]
        m = [mask[i] ? (maximise ? -v[i] : v[i]) : Inf for i in 1:n]
        i = argmin(m)
        tag = "i$(rows[i].isl)-g$(rows[i].gen)-i$(rows[i].ridx)"
        agree = tag == pick_tag[cname]
        @printf("diag (%s, %s): %s  pc (%.3f, %.3f)  fit %.3f  agree=%s\n",
                cname, label, tag, pc1[i], pc2[i], fit[i], agree ? "yes" : "no")
    end
end

println("\nCHECKER: $(n_ck[]) checks, $(n_fail[]) fail")
exit(n_fail[] == 0 ? 0 : 1)
