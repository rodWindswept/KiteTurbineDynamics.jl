# F4 — prose: "The search" (convergence of the three 5 kW campaigns)

Differential evolution is a search, and a search needs a trace. This figure
shows the three 5 kW campaigns — 18.0 m, 21.2 m and 25.0 m — as their three
islands each descend the fitness landscape over 30 generations. The
objective is a penalty to be minimised: lower is better, and any design the
evaluator rejects scores 1e9, off the chart.

The eye should first catch the shapes, not the numbers. Every panel shows
the same signature: a steep early descent, a long tail of diminishing
returns, and a plateau where all three islands agree. At 18 m the islands
converge by generation 12 onto −6.22; at 21.2 m they take until generation
16 to reach −6.66; at 25 m the descent is sharpest and the plateau deepest
at −7.31. The plateaus are not noise — the three independent searches land
on the same value, which is the search's way of saying it found the edge of
the design space, not a lucky point.

The three plateau levels tell a quiet physical story: the longer the chain,
the lower the fitness at the same power. Each extra metre of TRPT buys more
drag, more twist compliance and more mass for the same rotor, and the
optimiser's best answer degrades accordingly.

This is the honest companion to the ladder: the ladder says what is
possible, the convergence curves say the search actually got there — and
that the corrected model let it, with every rejected design kept visible in
the record.
