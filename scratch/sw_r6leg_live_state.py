import os
REPO = os.getcwd()
SP = "docs/agents/stale-phrases.md"
AGENT_DOCS = ["docs/agents/domain.md","docs/agents/instrument-trust-log.md",
 "docs/agents/genome-glossary.md","docs/agents/physics-topology.md",
 "docs/agents/physics-validation-ledger.md","CONTEXT.md"]
negation = ("never write","do not write","don't write","avoid writing",
 "never say","do not use","don't use","never call","do not ","don't ",
 "avoid ","retired","historically called","previously called",
 "formerly called","was called","is a placeholder","not a rotor term","superseded")
def _plain(s): return s.replace("**","").replace("*","").replace("`","")
content = open(SP, errors="ignore").read()
blocks = content.split("## ")[1:]
entries = []
for block in blocks:
    lines = block.splitlines()
    phrase = lines[0].strip()
    replacement = None; skill_only = False
    for line in lines[1:]:
        if line.startswith("Replacement:"): replacement = line.split("Replacement:",1)[1].strip()
        elif "(skill-only)" in line: skill_only = True
    if replacement and not skill_only: entries.append((phrase, replacement))
print(f"{len(entries)} scored entries")
total_flags = 0
for phrase, repl in entries:
    flags = []
    for doc in AGENT_DOCS:
        p = os.path.join(REPO, doc)
        if not os.path.exists(p): continue
        for n, line in enumerate(open(p, errors="ignore").read().splitlines(), 1):
            if _plain(phrase) not in _plain(line): continue
            low = _plain(line).lower()
            if any(m in low for m in negation): continue
            flags.append(f"{doc}:{n}")
            break
    if flags:
        total_flags += len(flags)
        print(f"  FLAGS {phrase!r}: {flags}")
print(f"TOTAL live flags under current list: {total_flags}")
