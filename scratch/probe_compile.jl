using KiteTurbineDynamics
const KTD = KiteTurbineDynamics
println("loaded OK")
println("BACK_LINE_T_DESIGN_N = ", KTD.BACK_LINE_T_DESIGN_N)
println(
    "back_line_tension at trimmed = ",
    KTD.back_line_tension(14.2127, 14.2127, 0.0, 707_000.0),
)
println("k_soft = ", KTD.BACK_LINE_T_DESIGN_N / KTD.BACK_LINE_SOFT_TRAVEL_M)
