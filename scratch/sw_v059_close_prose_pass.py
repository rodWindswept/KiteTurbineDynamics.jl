"""Science-writer prose pass on the v0.59 close (supply: f2a8773, md5 9f9cd83b...).

Assertions, as promised to the room:
  A1  zero new STE hits against the pre-fold section 5 baseline
  A2  no em dash and no marketing or aspiration adjective inside the close
  A3  value + station + state on any signed number it repeats (none repeats)
Plus desk checks: the close text in the candidate == the supply section 2 text.
"""
import re, subprocess, sys, hashlib

SUPPLY = "scratch/au_v058_close_supply.md"
CAND = "scratch/au_v058_close_draft_candidate.md"
OUT = "scratch/sw_v059_close_text.txt"

lines = open(SUPPLY, encoding="utf-8").read().split("\n")
# section 2 body: from the bold lead to the next "## "
start = next(i for i, l in enumerate(lines) if l.startswith("**Where this goes.**"))
end = next(i for i, l in enumerate(lines) if i > start and l.startswith("## "))
close_paras = [l.strip() for l in lines[start:end] if l.strip()]
close = "\n\n".join(close_paras) + "\n"
open(OUT, "w", encoding="utf-8").write(close)

body = close.replace("**", "")
words = re.findall(r"[A-Za-z0-9'\-\.]+", body)
sent = [s for s in re.split(r"(?<=[.!?])\s+", body.replace("\n", " ")) if s.strip()]
print("close: %d words, %d sentences, %d paragraphs, mean %.1f words"
      % (len(words), len(sent), len(close_paras), len(words) / len(sent)))

# ---- A2: em dash and aspiration / marketing adjectives
em = body.count("\u2014") + body.count("\u2013")
print("A2 em dashes inside the close:", em)

MARKETING = ["seamless", "robust", "powerful", "cutting-edge", "effortless", "world-class",
             "next-generation", "revolutionary", "blazing", "elegant", "delightful", "turnkey",
             "best-in-class", "state-of-the-art", "game-changing", "first-class", "battle-tested",
             "enterprise-grade", "supercharge", "unlock", "unleash", "empower", "comprehensive",
             "unprecedented", "transformative", "disruptive", "scalable", "novel", "unique",
             "significant", "substantial", "considerable", "remarkable", "exciting", "ambitious"]
ASPIRATION = ["potential", "opportunity", "opportunities", "vision", "roadmap", "journey",
              "promise", "promising", "future-proof", "market-leading", "world beating",
              "game changer", "step change", "step-change", "breakthrough", "enabler",
              "paradigm", "mission-critical", "value proposition", "impact", "transform",
              "revolution", "leverage", "best", "leading", "unmatched", "unrivalled", "pioneering"]
low = body.lower()
hits = [(w, len(re.findall(r"\b%s\b" % re.escape(w), low))) for w in MARKETING + ASPIRATION]
hits = [h for h in hits if h[1]]
print("A2 marketing/aspiration adjective hits:", hits or "none")

# ---- A3: signed-number repeats. Signed display forms are 3 dp values from the register.
nums = re.findall(r"-?\d+\.\d+", body)
print("A3 decimal numbers inside the close:", nums)
print("A3 register row-ID tokens inside the close:", re.findall(r"NR-\d+", body) or "none")
ints = re.findall(r"(?<![\d.])\d+(?![\d.])", body)
print("A3 integer tokens inside the close:", ints)
cost = [t for t in re.findall(r"p/kWh|\u00a3|gCO2e|MWh|kW/kg|LCOE", body)]
print("A3 cost/carbon tokens inside the close:", cost or "none")

# ---- A1: ste-lint, close alone and the candidate section 5 slice
def ste(path):
    r = subprocess.run([sys.executable, "ste-lint.py", path], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

rc, out = ste(OUT)
tail = [l for l in out.strip().split("\n") if l.strip()][-6:]
print("A1 ste-lint on the close alone: rc=%d" % rc)
for l in tail:
    print("   ", l)

# candidate section 5 slice
c = open(CAND, encoding="utf-8").read().split("\n")
try:
    s5 = next(i for i, l in enumerate(c) if re.match(r"^#+\s*5[\.\s]", l))
    s6 = next(i for i, l in enumerate(c) if i > s5 and re.match(r"^#+\s*6[\.\s]", l))
    slice_txt = "\n".join(c[s5:s6])
    open("scratch/sw_v059_s5_slice.txt", "w", encoding="utf-8").write(slice_txt)
    print("candidate section 5 slice: %d words" % len(re.findall(r"[A-Za-z0-9'\-\.]+", slice_txt)))
    rc2, out2 = ste("scratch/sw_v059_s5_slice.txt")
    print("A1 ste-lint on the candidate section 5 slice: rc=%d" % rc2)
    for l in [l for l in out2.strip().split("\n") if l.strip()][-6:]:
        print("   ", l)
except StopIteration:
    print("section 5 slice not located")

# ---- desk check: close text in the candidate identical to the supply
if "Where this goes" in "\n".join(c):
    cand_close = [p for p in re.split(r"\n\s*\n", "\n".join(c))
                  if "Where this goes" in p or "The instrument sizes and scores" in p
                  or "The validated rung is the machine" in p]
    joined = " ".join(" ".join(p.split()) for p in cand_close)
    print("candidate carries the three close paragraphs:", len(cand_close))
    print("candidate close md5:", hashlib.md5(" ".join(joined.split()).encode()).hexdigest()[:12])
print("supply close md5:", hashlib.md5(" ".join(close.split()).encode()).hexdigest()[:12])
