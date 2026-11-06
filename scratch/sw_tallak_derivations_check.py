#!/usr/bin/env python3
"""Verify the Tallak Tveide derivation blocks against Tulloch 4.30-4.34,
src/trpt_twist_limit.jl and the ontology C5-C8 / R61 language.
Read-only. Prints one line per check.
"""
import math

def h(th, r0, r1, l):
    A = l*l - r0*r0 - r1*r1
    B = 2*r0*r1
    return math.sqrt(A + B*math.cos(th))

def tau(th, r0, r1, l, T=1.0):
    return T*r0*r1*math.sin(th)/h(th, r0, r1, l)

def cos_peak(r0, r1, l):
    A = l*l - r0*r0 - r1*r1
    B = 2*r0*r1
    return (math.sqrt(A*A - B*B) - A)/B

def margin(th, dpeak):
    c = math.cos(dpeak)
    return math.sqrt(1 + c*c - 2*c*math.cos(th))/math.sin(th)

def glauert(a, g):
    return 4*a*(math.cos(g) - a)*math.sqrt(1 - 2*a*math.cos(g) + a*a)

def cubic_root(g):
    # -3a^3 + 7a^2 c - 3a c^2 - 2a + c = 0, root in (0,1)
    c = math.cos(g)
    lo, hi = 0.0, 1.0
    f = lambda a: -3*a**3 + 7*a*a*c - 3*a*c*c - 2*a + c
    for _ in range(200):
        mid = (lo + hi)/2
        if f(lo)*f(mid) <= 0: hi = mid
        else: lo = mid
    return (lo + hi)/2

print("== block 3/6: peak and margin ==")
for th_deg, dp_deg, tag in [(33.95, 98.86, "S1"), (22.82, 92.64, "S5")]:
    th, dp = math.radians(th_deg), math.radians(dp_deg)
    print(f"{tag}: M(theta,delta_peak) = {margin(th, dp):.4f}  (row capacity/torque S1 2.0287, S5 2.6936)")

print("\n== block 4: series ==")
for r0, r1, l in [(0.5, 1.0, 20.0), (0.8, 1.0, 5.0), (0.4, 0.4, 1.0)]:
    dp = math.degrees(math.acos(cos_peak(r0, r1, l)))
    lin_rad = math.degrees(r0*r1/(l*l))
    print(f"r0={r0} r1={r1} l={l}: delta_peak={dp:.4f} deg, 90+deg(r0r1/l^2)={90+lin_rad:.4f}")

print("\n== block 5: peak torque identity ==")
for r0, r1, l in [(0.4, 0.4, 1.0), (0.575, 0.575, 1.6)]:
    h0 = math.sqrt(l*l - (r0-r1)**2)
    hpi = math.sqrt(l*l - (r0+r1)**2)
    ident = (h0 - hpi)/2
    # numeric max of tau/T over theta
    grid = [math.radians(x/100) for x in range(0, 18000)]
    num = max(tau(t, r0, r1, l) for t in grid)
    print(f"r0={r0} r1={r1} l={l}: identity={ident:.10f}, numeric max={num:.10f}, diff={abs(ident-num):.2e}")

print("\n== block 7: inverse margin ==")
r0 = r1 = 0.4; l = 1.0
c = cos_peak(r0, r1, l)
for M in [2.0, 3.0]:
    disc = c*c - M*M*(1 + c*c - M*M)
    th = math.acos((c + math.sqrt(disc))/M**2)
    print(f"M={M}: theta={math.degrees(th):.6f} deg, M(theta)={margin(th, math.acos(c)):.10f}")

print("\n== block 8/9: zero crossing and rings-meet angle ==")
for r0, r1, l in [(0.4, 0.4, 1.0), (1.0, 1.0, 1.5), (0.4, 0.4, 0.7)]:
    if l >= r0 + r1:
        cross = 180.0
        tau180 = tau(math.pi, r0, r1, l)
        print(f"r0={r0} r1={r1} l={l}: l>=sum -> crossing 180, tau(180)={tau180:.2e}")
    else:
        cross = math.degrees(math.acos((r0*r0 + r1*r1 - l*l)/(2*r0*r1)))
        print(f"r0={r0} r1={r1} l={l}: l<sum -> rings meet at {cross:.4f} deg")

print("\n== block 10: y(x) == 1/M and y(1)=1 ==")
r0 = r1 = 0.4; l = 1.0
c = cos_peak(r0, r1, l); dp = math.acos(c)
for x in [0.5, 1.0]:
    th = x*dp
    y = math.sin(th)/math.sqrt(1 + c*c - 2*c*math.cos(th))
    print(f"x={x}: y={y:.10f}, 1/M={1/margin(th, dp):.10f}")

print("\n== blocks 11/12: Glauert ==")
for gdeg in [0, 10, 20, 30, 40, 50]:
    g = math.radians(gdeg)
    a = cubic_root(g)
    print(f"gamma={gdeg}: a={a:.6f}, Cp={glauert(a, g):.6f}")

print("\n== block 13: Jensen ==")
import random
random.seed(1)
ws = [10 + random.random() for _ in range(10000)]
mc = sum(w**3 for w in ws)/len(ws)
mw = sum(ws)/len(ws)
print(f"mean(w^3)={mc:.6f}, (mean w)^3={mw**3:.6f}, diff={mc-mw**3:.6e} (>=0)")

print("\n== E3 numbers from the signed rows ==")
k = 2.24
w = 13.380259861740395
Pm = 5308.7794439367935  # W, NR-008
Pend = 5314.0
kcube = k*w**3  # W: k in N m/(rad/s)^2 times (rad/s)^3 = W
print(f"k*w^3={kcube:.3f} W, P_mean={Pm:.3f} W, gap={kcube-Pm:.3f} W ({(kcube-Pm)/Pm*100:.4f} %)")
print(f"k*w^2={k*w*w:.6f} N m, tau_del={Pm/w:.6f} N m, diff={k*w*w-Pm/w:.6f} N m ({(k*w*w)/(Pm/w)*100-100:.4f} %)")
print(f"window swing NR-014 = 28.659374428010587 W, gap/swing = {(kcube-Pm)/28.659374428010587:.3f}")
