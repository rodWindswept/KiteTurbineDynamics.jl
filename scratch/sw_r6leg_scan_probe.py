import os
REPO = os.getcwd()
AGENT_DOCS = ["docs/agents/domain.md","docs/agents/instrument-trust-log.md",
 "docs/agents/genome-glossary.md","docs/agents/physics-topology.md",
 "docs/agents/physics-validation-ledger.md","CONTEXT.md"]
negation = ("never write","do not write","don't write","avoid writing",
 "never say","do not use","don't use","never call","do not ","don't ",
 "avoid ","retired","historically called","previously called",
 "formerly called","was called","is a placeholder","not a rotor term","superseded")
def _plain(s): return s.replace("**","").replace("*","").replace("`","")
phrases = ["hub ring", '"hub ring"', "hub rotor", "The topmost ring hosts ONLY the cp/ct rotor",
           "expansion_params_from_rotors excludes the decoder's topmost rotor"]
for phrase in phrases:
    flags = []
    for doc in AGENT_DOCS:
        p = os.path.join(REPO, doc)
        if not os.path.exists(p): continue
        for n, line in enumerate(open(p, errors="ignore").read().splitlines(), 1):
            if phrase not in _plain(line): continue
            low = _plain(line).lower()
            if any(m in low for m in negation): continue
            flags.append(f"{doc}:{n}: {line.strip()[:100]}")
    print(f"=== phrase: {phrase!r} -> {len(flags)} flag(s)")
    for f in flags: print("   FLAG", f)
