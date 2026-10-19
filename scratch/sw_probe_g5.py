import hashlib
src = open("scratch/au_g4_candidate.md").read()
OLD = "No such bridle exists to go slack, so nothing here can check that it stays loaded.\n"
NEW = "No such bridle exists to go slack, so nothing here checks that it stays loaded.\n"
assert src.count(OLD) == 1, src.count(OLD)
out = src.replace(OLD, NEW)
open("scratch/sw_probe_full_G5.md","w").write(out)
print("md5", hashlib.md5(out.encode()).hexdigest()[:8], "lines", out.count("\n"), "words", len(out.split()))
