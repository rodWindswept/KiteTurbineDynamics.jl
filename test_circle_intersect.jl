using LinearAlgebra

function place_sky_anchor(b_pos, ground_anchor, L_cyan, back_L0)
    # 2D intersection in XZ plane
    c1 = [b_pos[1], b_pos[3]]
    c2 = [ground_anchor[1], ground_anchor[3]]
    r1 = L_cyan
    r2 = back_L0

    d = norm(c2 - c1)
    if d > r1 + r2 || d < abs(r1 - r2)
        println("Warning: No intersection! d=$d, r1=$r1, r2=$r2")
        return b_pos + [0.0, 0.0, L_cyan] # fallback
    end

    a = (r1^2 - r2^2 + d^2) / (2*d)
    h_sq = r1^2 - a^2
    h = h_sq > 0 ? sqrt(h_sq) : 0.0

    P2 = c1 + a * (c2 - c1) / d

    # Two solutions
    p3_1 = [P2[1] + h * (c2[2] - c1[2]) / d, P2[2] - h * (c2[1] - c1[1]) / d]
    p3_2 = [P2[1] - h * (c2[2] - c1[2]) / d, P2[2] + h * (c2[1] - c1[1]) / d]

    # Pick the one with higher Z
    best_p = p3_1[2] > p3_2[2] ? p3_1 : p3_2
    return [best_p[1], b_pos[2], best_p[2]] # Restore Y
end

bx = 30.85
bz = 17.81
ax = 36.98
az = 0.0
L_cyan = 5.0
back_L0 = 20.55

s_pos = place_sky_anchor([bx, 0.0, bz], [ax, 0.0, az], L_cyan, back_L0)
println("Placed Sky Anchor: ", s_pos)
println("Cyan dist: ", norm(s_pos - [bx, 0.0, bz]))
println("Backline dist: ", norm(s_pos - [ax, 0.0, az]))
