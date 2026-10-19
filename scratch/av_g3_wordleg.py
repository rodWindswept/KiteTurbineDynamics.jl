#!/usr/bin/env python3
"""Apply the F3 word-leg diff (the section 6.2 capacity-factor patch) to G3."""
import hashlib

def md5(b): return hashlib.md5(b).hexdigest()

g3 = open("scratch/av_g3_candidate.md", "rb").read().decode("utf-8")
pairs = [
    ("Each point takes the same method, on the current model, with one stated capacity factor for the whole curve.",
     "Each point takes the same method, on the current model, with one capacity factor for the whole curve."),
    ("The curve states one capacity factor.",
     "The curve takes one capacity factor."),
]
for i, (o, n) in enumerate(pairs):
    c = g3.count(o)
    print(f"pair {i+1} count: {c}")
    assert c == 1, f"pair {i+1} not unique"
    g3 = g3.replace(o, n)
b = g3.encode("utf-8")
open("scratch/av_g3_word.md", "wb").write(b)
print("G3 word md5:", md5(b), "lines/words:", len(b.splitlines()), len(b.split()))
# reverse check
for o, n in pairs:
    g3 = g3.replace(n, o)
print("reverse returns G3 candidate md5:", md5(g3.encode("utf-8")))
