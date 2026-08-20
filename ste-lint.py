# ste-lint.py — ASD-STE100 linter with habit-hook fix-guidance.
# Version: 0.2.0 | Date: 2026-08-20 | Author: Windswept & Interesting
#
# Fuses the cue (violation) with the routine (fix-guidance): each violation
# prints a [HOOK:ste] line telling the agent HOW to fix it, not just that it
# failed. --fail-above N exits 1 when any file breaches N violations/100w, so
# a pre-commit hook can block on it.
import re, sys, json, glob, os

MARKETING = ["seamless","seamlessly","robust","powerful","cutting-edge","effortless","effortlessly",
    "world-class","next-generation","revolutionary","blazing","lightning-fast","elegant","delightful",
    "turnkey","best-in-class","state-of-the-art","game-changing","first-class","battle-tested",
    "enterprise-grade","supercharge","unlock","unleash","empower","empowers"]
BANNED = ["begin","begins","commence","commences","initiate","initiates","originate",
    "utilize","utilizes","utilizing","leverage","leverages","leveraging","facilitate","facilitates",
    "ensure","ensures","ensuring","prior to","subsequent to","obtain","obtains","acquire","acquires",
    "demonstrate","demonstrates","additionally","furthermore","moreover","comprehensive","comprehensively",
    "utilization","aforementioned","henceforth","therein","whilst","amongst","numerous","myriad","plethora",
    "in order to","a variety of","in the event that","due to the fact that","it is important to note"]
PHRASAL = ["spin up","spin down","reach out","dive into","dives into","diving into","kick off","kicks off",
    "roll out","rolls out","tear down","ramp up","circle back","drill down","spun up","reaching out"]
MODAL_HEDGE = ["it is important to note","it should be noted","it is worth noting","please note that",
    "as mentioned","as noted above"]
BE = r"(?:am|is|are|was|were|be|been|being)"
PP_IRREG = r"(?:done|made|sent|read|built|kept|held|set|put|run|written|shown|given|taken|found|got|gotten|seen|known|thrown|drawn)"

GUIDANCE = {
    "long_sentence(>20w)": "split — max 20 words (instruction) / 25 (descriptive). Two short sentences beat one long. (ste-writing)",
    "semicolon": "replace ';' with a period — write two sentences. (ste-writing)",
    "contraction": "expand — \"don't\" -> \"do not\". (ste-writing)",
    "passive_voice": "active voice — \"<actor> <verb> <object>\", not \"<object> is <verb>ed\". (ste-writing)",
    "ing_main_verb": "use a simple tense, not \"be + -ing\" as the main verb. (ste-writing)",
    "nominalization": "use the verb — \"analyze\", not \"perform an analysis\". (ste-writing)",
    "phrasal_verb": "one plain verb — \"start\", not \"spin up\"; \"examine\", not \"dive into\". (ste-writing)",
    "banned_word": "short common word — start/use/help/make sure/show. (ste-writing)",
    "marketing_adjective": "drop it — \"works\", not \"seamless\"; \"fast\", not \"blazing\". (ste-writing)",
    "modal_hedge": "state the finding directly — cut \"it is important to note\". (ste-writing)",
    "long_paragraph(>6s)": "one topic per paragraph, max six sentences — split it. (ste-writing)",
}
EM_DASH_GUIDANCE = "no em dash — use a period or comma. (ste-writing)"

def strip_code(t):
    t = re.sub(r"```.*?```", " ", t, flags=re.S)
    t = re.sub(r"`[^`]*`", " ", t)
    return t

def sentences(text):
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if not s: continue
        s = re.sub(r"^\s*#{1,6}\s*", "", s)
        s = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+", "", s)
        if not s: continue
        parts = re.split(r"(?<=[.!?:])\s+(?=[A-Z0-9\"'\-])", s)
        for p in parts:
            p = p.strip()
            if p: out.append(p)
    return out

def wc(s):
    return len([w for w in re.findall(r"[A-Za-z0-9][A-Za-z0-9'\-/]*", s)])

def count_ci(text, phrases):
    n = 0; hits = []
    low = text.lower()
    for ph in phrases:
        for m in re.finditer(r"(?<![a-z])" + re.escape(ph) + r"(?![a-z])", low):
            n += 1; hits.append(ph)
    return n, hits

def lint(text):
    raw = text
    text = strip_code(text)
    sents = sentences(text)
    words = sum(wc(s) for s in sents) or 1
    v = {}
    longs = [(wc(s), s) for s in sents if wc(s) > 20]
    v["long_sentence(>20w)"] = len(longs)
    v["semicolon"] = text.count(";")
    v["contraction"] = len(re.findall(r"\b\w+['’](?:t|re|ve|ll|d|s|m)\b", text))
    v["passive_voice"] = len(re.findall(rf"\b{BE}\s+(?:\w+ed|{PP_IRREG})\b", text, re.I))
    v["ing_main_verb"] = len(re.findall(rf"\b{BE}\s+\w+ing\b", text, re.I))
    v["nominalization"] = len(re.findall(r"\b(?:perform(?:s|ed)?|conduct(?:s|ed)?|provide(?:s|d)?|carry out|carries out|make use of|makes use of)\b", text, re.I)) + len(re.findall(r"\b\w{4,}(?:tion|ment|ance|ence)\s+of\b", text, re.I))
    v["phrasal_verb"], _ = count_ci(text, PHRASAL)
    v["banned_word"], bh = count_ci(text, BANNED)
    v["marketing_adjective"], mh = count_ci(text, MARKETING)
    v["modal_hedge"], _ = count_ci(text, MODAL_HEDGE)
    paras = [p for p in re.split(r"\n\s*\n", raw) if p.strip()]
    v["long_paragraph(>6s)"] = sum(1 for p in paras if len(sentences(strip_code(p))) > 6)
    em = raw.count("—") + raw.count("–")
    total = sum(v.values())
    per100 = {k: round(x*100.0/words, 2) for k, x in v.items()}
    return {
        "words": words, "sentences": len(sents),
        "violations": v, "total": total,
        "total_per100w": round(total*100.0/words, 2),
        "em_dash(slop-marker)": em,
        "longest_sentence_words": (max(longs)[0] if longs else max((wc(s) for s in sents), default=0)),
        "sample_marketing": list(dict.fromkeys(mh))[:6],
        "sample_banned": list(dict.fromkeys(bh))[:6],
    }

def emit_guidance(base, r):
    for k, n in r["violations"].items():
        if n > 0:
            print(f"[HOOK:ste] {base}: {k} x{n} -> {GUIDANCE.get(k, 'see ste-writing')}")
    if r["em_dash(slop-marker)"] > 0:
        print(f"[HOOK:ste] {base}: em_dash x{r['em_dash(slop-marker)']} -> {EM_DASH_GUIDANCE}")

if __name__ == "__main__":
    fail_above = None
    argv = list(sys.argv[1:])
    if "--fail-above" in argv:
        i = argv.index("--fail-above")
        fail_above = float(argv[i+1]); del argv[i:i+2]
    files = argv or []
    if not files:
        print(json.dumps(lint(sys.stdin.read()), indent=2)); sys.exit(0)
    exp = []
    for f in files: exp += sorted(glob.glob(f)) if any(c in f for c in "*?[") else [f]
    breach = False
    for f in exp:
        with open(f) as fh: r = lint(fh.read())
        base = os.path.basename(f)
        print(f"{base:32} words={r['words']:4d} total={r['total']:3d} per100w={r['total_per100w']:6.2f} em_dash={r['em_dash(slop-marker)']:2d}")
        emit_guidance(base, r)
        if fail_above is not None and r["total_per100w"] >= fail_above:
            breach = True
    sys.exit(1 if breach else 0)
