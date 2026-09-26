# src/shaft_moment.jl
#
# The moment of a force about the shaft axis.
#
# Why this is a named function and not an inline expression:
# a TRPT ring node carries two kinds of degree of freedom. Its three translational
# states hold the ring CENTRE. Its spin state holds the ring angle. The spin
# acceleration reads the torque accumulator only, and a force reads the
# translational equation only. So a force applied at a ring attachment point
# reaches the spin only when the code adds its moment to the accumulator.
#
# The ring centre sits on the shaft axis. A tangential force at the centre
# therefore does no work on the rotation. A force that is applied to the centre
# and never given its moment is a force that cannot slow the shaft.
#
# Use this function at every site where a force acts at a ring attachment radius
# and the source of that force must resist the rotation. The tether tension path
# already does this arithmetic inline (src/rope_forces.jl). The drag path did not.
#
# All three arguments are 3-vectors in the model frame. The result is a scalar in
# newton metre, signed about `shaft_dir`.

"""
    shaft_moment(r, F, shaft_dir) -> Float64

Return the component along `shaft_dir` of the moment `r × F`.

`r` is the moment arm, from the ring centre to the point where the force acts.
`F` is the force. `shaft_dir` is the unit vector of the shaft axis.

A unit `shaft_dir` is not required. The function projects `r × F` on the given
direction, so a scaled direction scales the result.
"""
@inline function shaft_moment(r, F, shaft_dir)
    return (r[1] * F[2] - r[2] * F[1]) * shaft_dir[3] +
           (r[2] * F[3] - r[3] * F[2]) * shaft_dir[1] +
           (r[3] * F[1] - r[1] * F[3]) * shaft_dir[2]
end
