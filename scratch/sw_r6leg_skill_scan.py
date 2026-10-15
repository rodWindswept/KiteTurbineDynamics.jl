import os, re
def phrase_pattern(phrase):
    tokens = [re.escape(t) for t in phrase.split()]
    return re.compile(r"[-_\s]+".join(tokens), re.IGNORECASE)
ROOTS = ["/home/rod/.hermes/skills", "/home/rod/.hermes/profiles/science-writer/skills"]
for phrase in ["hub ring", '"hub ring"', "hub rotor"]:
    rx = phrase_pattern(phrase)
    hits = []
    for root in ROOTS:
        for r, d, files in os.walk(root):
            for fname in files:
                if fname != "SKILL.md": continue
                p = os.path.join(r, fname)
                try: content = open(p, errors="ignore").read()
                except OSError: continue
                # strip banner context + strikethrough as the checker does
                content = re.sub(r"~~.+?~~", " ", content, flags=re.DOTALL)
                for i, line in enumerate(content.splitlines(), 1):
                    if rx.search(line):
                        hits.append(f"{p}:{i}: {line.strip()[:110]}")
    print(f"=== {phrase!r}: {len(hits)} skill hit(s)")
    for h in hits[:12]: print("  ", h)
