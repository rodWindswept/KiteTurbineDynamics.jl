#!/usr/bin/env python3
"""Verify the F3 committed pair and build + measure G3 and its word leg.

G3 = F3 candidate with SW's two-line repair (the absolute unbridled claims).
Word leg = G3 candidate with the one-word list-item drop at 1117.
"""
import hashlib, subprocess, sys

def md5(b): return hashlib.md5(b).hexdigest()

F3C = "scratch/au_sec61_f3_candidate.md"
F3W = "scratch/au_sec61_f3_word.md"
G3C = "scratch/av_g3_candidate.md"
G3W = "scratch/av_g3_word.md"

src = open(F3C, "rb").read()
print("F3 candidate md5:", md5(src), "(declared 9a7a5d17)")
print("F3 candidate lines/words:", len(src.splitlines()), len(src.split()))
sw = open(F3W, "rb").read()
print("F3 word md5:", md5(sw), "(declared a308305d)")
print("F3 word lines/words:", len(sw.splitlines()), len(sw.split()))

text = src.decode("utf-8")
o1 = "The model remains unbridled. It gives every blade one bank angle, all the way round."
n1 = "The model carries no tether-to-blade bridle. It gives every blade one bank angle, all the way round."
o2 = "No bridle exists to go slack, so no design in this report can check that a bridle stays loaded."
n2 = "No such bridle exists to go slack, so no design in this report can check that a bridle stays loaded."
for name, old, new in (("1", o1, n1), ("2", o2, n2)):
    c = text.count(old)
    print(f"swap {name} count: {c}")
    if c != 1: sys.exit(1)
g3 = text.replace(o1, n1).replace(o2, n2)
gb = g3.encode("utf-8")
open(G3C, "wb").write(gb)
print("G3 candidate md5:", md5(gb), "(declared 4b49cfca)")
print("G3 candidate lines/words:", len(g3.splitlines()), len(g3.split()))

# word leg: drop the bank item from the 1117 list
w_old = "The tilt gives side force and moment: bank, steer and load relief."
w_new = "The tilt gives side force and moment: steer and load relief."
print("word-patch count:", g3.count(w_old))
wg = g3.replace(w_old, w_new)
wb = wg.encode("utf-8")
open(G3W, "wb").write(wb)
print("G3 word md5:", md5(wb), "lines/words:", len(wg.splitlines()), len(wg.split()))
