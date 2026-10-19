import hashlib
src = open("scratch/sw_probe_full_G5.md").read()
P = [("Each point takes the same method, on the current model, with one stated capacity factor for the whole curve.\n",
      "Each point takes the same method, on the current model, with one capacity factor for the whole curve.\n"),
     ("The curve states one capacity factor.\n", "The curve takes one capacity factor.\n")]
for old, new in P:
    assert src.count(old) == 1, (src.count(old), old[:40])
    src = src.replace(old, new)
open("scratch/sw_probe_full_G5_word.md","w").write(src)
print("md5", hashlib.md5(src.encode()).hexdigest()[:8], "lines", src.count("\n"), "words", len(src.split()))
