"""Science-writer prose pass, round 2: the three direction paragraphs for the close
(supplied by the author seat in the room, ledger section 3a at b9a7f46).

Assertions:
  B1  zero STE hits inside the three paragraphs (close baseline is 0.00/100w)
  B2  no em dash, no marketing/aspiration adjective
  B3  the only new numeric token is `60`, target-class, in the plan-probe sentence;
      no floor value, no 18.8 digit, no NR token, no cost/carbon token
  B4  each paragraph at or under the close's four-sentence ceiling
Plus desk checks: the register's row count for the length screen (six rows),
and the draft's own terminology for the folded class and the ten-slot genome.
"""
import re, subprocess, sys

PARAS = [
    ("capability pair",
     "The search already moves ten genes, so the same pipeline can probe wider parameter regimes. "
     "The expansion rotor model lands with tests, so the room can study multi-rotor and expansion-class machines."),
    ("target set",
     "Wider parameter regimes, flying higher on longer shafts, and the scale where multi-rotor machines win are programme targets too. "
     "The length study runs to 60 m as a plan probe. That figure is not a signed row."),
    ("signed-screen honesty",
     "The signed length screen varied length alone on one pre-fold genome. Its three longer rows read below the power floor. "
     "The folded class passed at the base length. The record sits in section 2.3."),
]

OUT = "scratch/sw_v059_directions_text.txt"
with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n\n".join(p for _, p in PARAS) + "\n")

for name, p in PARAS:
    sent = [s for s in re.split(r"(?<=[.!?])\s+", p) if s.strip()]
    print("%-22s %d words, %d sentences" % (name, len(p.split()), len(sent)))
    for s in sent:
        print("    %2dw  %s" % (len(s.split()), s))

body = "\n".join(p for _, p in PARAS)
em = body.count("\u2014") + body.count("\u2013")
print("B2 em dashes:", em)

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
print("B2 marketing/aspiration hits:", hits or "none")

print("B3 NR tokens:", re.findall(r"NR-\d+", body) or "none")
print("B3 integer tokens:", re.findall(r"(?<![\d.])\d+(?![\d.])", body))
print("B3 decimal tokens:", re.findall(r"-?\d+\.\d+", body) or "none")
print("B3 cost/carbon tokens:", re.findall(r"p/kWh|\u00a3|gCO2e|MWh|kW/kg|LCOE", body) or "none")

rc, out = subprocess.run([sys.executable, "ste-lint.py", OUT], capture_output=True, text=True)[:1] if False else (None, None)
r = subprocess.run([sys.executable, "ste-lint.py", OUT], capture_output=True, text=True)
print("B1 ste-lint rc=%d" % r.returncode)
for l in [l for l in r.stdout.strip().split("\n") if l.strip()][-5:]:
    print("   ", l)
