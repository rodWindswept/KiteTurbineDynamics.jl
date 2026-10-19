import hashlib, sys
src = open("scratch/au_sec61_f3_candidate.md").read()
A_OLD = ("The model remains unbridled. It gives every blade one bank angle, all the way round.\n"
         "No bridle exists to go slack, so no design in this report can check that a bridle stays loaded.\n")
A_NEW = ("The model carries no tether-to-blade bridle. It gives every blade one bank angle, all the way round.\n"
         "No such bridle exists to go slack, so no design in this report can check that a bridle stays loaded.\n")
assert src.count(A_OLD) == 1, src.count(A_OLD)
out = src.replace(A_OLD, A_NEW)
open("scratch/sw_probe_full_G3.md","w").write(out)
print("md5", hashlib.md5(out.encode()).hexdigest()[:8])
print("lines", out.count("\n") + (0 if out.endswith("\n") else 1), "words", len(out.split()))
