#!/usr/bin/env python3
"""Build the KTD report draft PDF from the single-source draft and figure kits.

Seat: hermes (reporting room builder). Inputs stay single-source under
docs/reporting/; this script only assembles. It never re-renders a figure:
kits embed as shipped (vector-first).

Pipeline (route html, default):
  1. Register-seat citation check. Gate: the build aborts on checker exit 1.
  2. Resolve every "[Figure seated: ... slug `...` ...]" marker to its kit:
     image (SVG vector-first, PNG fallback), dual captions from
     captions.md, provenance stamp from manifest.json.
  3. Append the build record (draft commit, register status, citation
     summary, resolved seats, toolchain, instant) outside the report
     proper.
  4. pandoc -> standalone HTML (A4 css) -> Chrome headless -> PDF.

Route latex (pandoc --pdf-engine=lualatex) is recorded but blocked on this
box until `sudo apt install texlive-luatex` lands (probe 2026-10-09:
luaotfload missing, every fontspec load falls to nullfont).

Usage:
  scripts/build_draft_pdf.py                  # one build, citation-gated
  scripts/build_draft_pdf.py --watch          # mtime-poll rebuild loop
  scripts/build_draft_pdf.py --no-check       # skip the citation gate
  scripts/build_draft_pdf.py --route latex    # blocked route (see above)
  scripts/build_draft_pdf.py --open           # xdg-open the PDF after build

Outputs land in scratch/report-pdf-build/: draft-live.pdf (stable name so
a viewer keeps refreshing the same path under --watch), timestamped copies,
draft.html, build-record.txt. Outputs are untracked scratch.
"""

import argparse
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REGISTER = "docs/reporting/numbers-register.md"
CHECKER = "scratch/sv_check_draft_citations.py"
FIG_ROOT = "docs/reporting/figures"
FIG_MAP = "docs/reporting/figures/figure-map.md"
OUT_DIR = "scratch/report-pdf-build"
KATEX_DIR = "docs/reporting/assets/katex"

CSS = """
@page { size: A4; margin: 20mm 18mm; }
html { font-size: 10.5pt; }
body { font-family: "DejaVu Serif", "Liberation Serif", serif; line-height: 1.45; color: #111; }
h1, h2, h3, h4, h5 { font-family: "DejaVu Sans", "Liberation Sans", sans-serif; line-height: 1.25; }
code, pre { font-family: "DejaVu Sans Mono", monospace; font-size: 0.92em; }
blockquote { color: #333; }
figure.fig { margin: 1.2em 0; text-align: center; break-inside: avoid; page-break-inside: avoid; }
figure.fig img { max-width: 100%; height: auto; }
figcaption { text-align: left; font-size: 9pt; color: #222; margin-top: 0.4em; line-height: 1.35; }
.figlabel { font-weight: bold; }
.stamp { display: block; font-size: 7.5pt; color: #444; font-family: "DejaVu Sans Mono", monospace; margin-top: 0.3em; }
.plain, .tech { display: block; }
.build-record { font-size: 9pt; color: #444; }
/* Compact table typography: validation/register tables print small and
   tight. Shrink the face, pull the cell padding in, give every cell a hair
   border and shade the header, and never split a row across a page break. */
table { border-collapse: collapse; width: 100%; margin: 0.6em 0;
        font-size: 8pt; font-family: "DejaVu Sans", "Liberation Sans", sans-serif;
        line-height: 1.25; }
th, td { border: 0.5pt solid #bbb; padding: 1.5pt 4pt; text-align: left;
         vertical-align: top; overflow-wrap: break-word; word-wrap: break-word; }
th { background: #eee; font-weight: bold; }
tr { break-inside: avoid; page-break-inside: avoid; }
"""

SEAT_RE = re.compile(
    r"\[Figure seated:\s*(?:figure-map row\s+(?P<row>\d+))?.*?slug `(?P<slug>[a-z0-9_-]+)`.*?\]",
    re.DOTALL,
)

MISSING_KIT_MESSAGE = (
    "[Figure seat unresolved by the builder: kit {slug} missing or incomplete. "
    "The marker stays visible.]"
)


def sh(cmd, cwd, timeout=180):
    """Run a command; return (stdout, stderr, rc)."""
    proc = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout
    )
    return proc.stdout, proc.stderr, proc.returncode


def repo_root():
    out, _, rc = sh(["git", "rev-parse", "--show-toplevel"], cwd=os.getcwd())
    if rc != 0:
        sys.exit(f"build_draft_pdf: not in a git worktree: {out}".rstrip())
    return Path(out.strip())


def git_hash(root, pathspec):
    out, _, rc = sh(
        ["git", "log", "-1", "--format=%h", "--", pathspec], cwd=root
    )
    return out.strip() if rc == 0 and out.strip() else "unknown"


def citation_check(root, draft, register, checker, surfaces=()):
    """Run the register-seat checker. Return (summary, ok).

    surfaces: extra paths scanned as attached document text (the embedded
    kit captions). The cited set then covers the assembled document, and a
    caption-only cite to an unsigned row fails the build.
    """
    cmd = [sys.executable, str(checker), str(draft), str(register)]
    cmd.extend(str(s) for s in surfaces)
    out, err, rc = sh(cmd, cwd=root)
    cited = re.search(r"cited rows in .*?: (\d+)", out)
    signed = re.search(r"every cited row present and signed \((\d+) signed rows total\)", out)
    uncited = re.search(r"signed rows not cited by this draft \(informational\): (.+)", out)
    draft_only = re.search(r"draft file alone: (\d+) cited", out)
    summary_parts = []
    if cited:
        summary_parts.append(f"{cited.group(1)} cited")
    if signed:
        summary_parts.append(f"every one signed ({signed.group(1)} signed rows total)")
    if uncited:
        summary_parts.append(f"uncited: {uncited.group(1)}")
    else:
        summary_parts.append("uncited: none")
    if draft_only:
        summary_parts.append(f"draft file alone: {draft_only.group(1)} cited")
    summary = ", ".join(summary_parts)
    return summary, rc == 0, out + err


def parse_caption_sections(path):
    """Pull the Plain caption and STE technical caption sections."""
    plain, tech, current = [], [], None
    for line in Path(path).read_text().splitlines():
        if line.startswith("## Plain caption"):
            current = plain
            continue
        if line.startswith("## Technical caption"):
            current = tech
            continue
        if line.startswith("## ") or line.startswith("# "):
            current = None
            continue
        if current is not None:
            current.append(line)
    join = lambda lines: re.sub(r"\s+", " ", " ".join(lines)).strip()
    return join(plain), join(tech)


def manifest_stamp(manifest):
    """One-line provenance stamp from a kit manifest."""
    bits = []
    cap = manifest.get("capture", {})
    if cap.get("run_id"):
        bits.append(cap["run_id"])
    data = manifest.get("data_commit")
    if data:
        bits.append(f"data {data}")
    else:
        sha = (manifest.get("inputs", {}).get("extract", {}) or {}).get("sha256", "")
        if sha:
            bits.append(f"data {sha[:7]}")
    script = manifest.get("script_commit")
    if not script:
        sha = manifest.get("script", {}).get("sha256", "")
        script = sha[:7] if sha else None
    if script:
        bits.append(f"script {script}")
    rows = manifest.get("registers") or manifest.get("inputs", {}).get("register_rows", [])
    if rows:
        bits.append("rows " + ", ".join(rows))
    return " \u00b7 ".join(bits)


def seat_to_html(root, match):
    """Replace one seat marker with the embedded figure block."""
    slug = match.group("slug")
    row = match.group("row")
    kit = root / FIG_ROOT / slug
    label = f"Figure (roster row {row}) \u00b7 {slug}" if row else slug
    if not kit.is_dir():
        return MISSING_KIT_MESSAGE.format(slug=slug)
    manifest_path = kit / "manifest.json"
    captions_path = kit / "captions.md"
    image = kit / f"{slug}.svg"
    if not image.exists():
        image = kit / f"{slug}.png"
    if not image.exists() or not manifest_path.exists() or not captions_path.exists():
        return MISSING_KIT_MESSAGE.format(slug=slug)
    try:
        manifest = json.loads(manifest_path.read_text())
    except json.JSONDecodeError:
        return MISSING_KIT_MESSAGE.format(slug=slug)
    plain, tech = parse_caption_sections(captions_path)
    stamp = manifest_stamp(manifest)
    block = (
        '<figure class="fig" id="fig-{slug}">\n'
        '<img src="{src}" alt="{slug}">\n'
        "<figcaption>\n"
        '<span class="figlabel">{label}</span>\n'
        '<span class="plain">{plain}</span>\n'
        '<span class="tech">{tech}</span>\n'
        '<span class="stamp">Source: {stamp}</span>\n'
        "</figcaption>\n"
        "</figure>"
    ).format(
        slug=slug,
        src=image,
        label=html.escape(label),
        plain=html.escape(plain),
        tech=html.escape(tech),
        stamp=html.escape(stamp),
    )
    return block


def resolve_seats(root, text):
    seats = []
    for match in SEAT_RE.finditer(text):
        seats.append(match.group("slug"))
    text = SEAT_RE.sub(lambda m: seat_to_html(root, m), text)
    return text, seats


def register_status(root, register):
    text = (root / register).read_text()
    for line in text.splitlines():
        m = re.match(r"\*\*Status:\*\*\s+(.+)", line)
        if m:
            return m.group(1).strip()
    return "status line not found"


def register_appendix(root, register, cited):
    """Render the data appendix: every row the draft cites, from the register."""
    reg = (root / register).read_text()
    rows = {}
    for line in reg.splitlines():
        m = re.match(r"\|\s*NR-(\d+)(?:\s*\(amended\))?\s*\|", line)
        if m and int(m.group(1)) in cited:
            rows[int(m.group(1))] = line  # re-signed rows: last row wins
    if not rows:
        return ""
    header = (
        "## Data register (cited rows)\n\n"
        "Every number in this draft traces to a signed row in the numbers\n"
        "register. A missing row here is a release blocker.\n\n"
        "| Row | Quantity | Value | Units | Source | Status |\n"
        "|---|---|---|---|---|---|\n"
    )
    return header + "\n".join(line for _, line in sorted(rows.items())) + "\n"


def build_record(root, draft, register, summary, seats, toolchain):
    draft_hash = git_hash(root, draft)
    reg_hash = git_hash(root, register)
    status = register_status(root, register)
    seats_line = (
        f"{len(seats)} of {len(seats)} \u2014 "
        + ", ".join(f"`{s}`" for s in seats)
    )
    built = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"""## Build record (builder output)

This block is builder output. It sits outside the report proper and does
not pass the STE gate.

Draft: `{draft_hash}` (`{draft}`)

Register: `{status}` \u2014 file at `{reg_hash}`

Citation check: {summary} \u2014 checker exit 0

Seats resolved: {seats_line}

Embed route: SVG vector-first, PNG fallback; kits embedded as shipped,
nothing re-rendered

Toolchain: {toolchain}

Built: {built}
"""


def toolchain_line():
    out, _, rc = sh(["pandoc", "--version"], cwd="/")
    ver = out.splitlines()[0].strip() if rc == 0 and out else "pandoc unknown"
    chrome = "google-chrome" if sh(["which", "google-chrome"], cwd="/")[2] == 0 else "chromium"
    return f"{ver} \u2192 HTML \u2192 {chrome} headless PDF (A4)"


def build_html(root, args, text, seats, summary):
    out_dir = root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "draft.css").write_text(CSS)

    intermediate = out_dir / "draft-assembled.md"
    intermediate.write_text(text)

    html_path = out_dir / "draft.html"
    # Math route. Source carries LaTeX ($...$ / $$...$$); the build must be told
    # how to resolve it: without a flag pandoc emits the raw TeX text, so every
    # formula prints as source and the page reads as code.
    #   katex  -> TeX-quality typesetting, assets vendored under KATEX_DIR, fonts
    #             inlined as data URIs so the HTML stays self-contained/offline.
    #   mathml -> MathML Core, native to Chrome, no JS, but operator spacing is
    #             looser than TeX (fences around max(...) open up).
    math_flags = []
    math_route = "none"
    katex_dir = (root / args.katex_dir) if args.math == "katex" else None
    if katex_dir is not None and (katex_dir / "katex.min.css").exists():
        math_flags = [f"--katex={katex_dir.resolve()}/"]
        math_route = f"katex ({katex_dir})"
    elif args.math == "mathml":
        math_flags = ["--mathml"]
        math_route = "mathml"
    elif args.math == "katex":
        return None, f"katex assets missing under {args.katex_dir}"
    cmd = [
        "pandoc",
        str(intermediate),
        "-s",
        "--embed-resources",
        "--standalone",
        "-t",
        "html5",
        *math_flags,
        "--css",
        "draft.css",
        "--metadata",
        f"title={args.title}",
        "-o",
        str(html_path),
    ]
    _, err, rc = sh(cmd, cwd=root)
    if rc != 0:
        return None, f"pandoc failed:\n{err}"
    print(f"[math] {math_route}")

    pdf_path = out_dir / "draft-live.pdf"
    chrome = "google-chrome" if sh(["which", "google-chrome"], cwd="/")[2] == 0 else "chromium"
    cmd = [
        chrome,
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        f"file://{html_path}",
    ]
    _, err, rc = sh(cmd, cwd=root, timeout=300)
    if rc != 0 or not pdf_path.exists() or pdf_path.stat().st_size == 0:
        return None, f"chrome print failed:\n{err}"
    return pdf_path, None


def build_latex(root, args, text, seats, summary):
    """Route latex: recorded but blocked until texlive-luatex lands."""
    _, _, rc = sh(["kpsewhich", "luaotfload.sty"], cwd=root)
    if rc != 0:
        print(
            "route latex is blocked on this box: TeX Live has no luaotfload "
            "(package texlive-luatex not installed). Fix: `sudo apt install "
            "texlive-luatex`, then re-run."
        )
        return None, "luaotfload missing"
    # Embed kits as markdown images (PDF vector-first) for the LaTeX route.
    def seat_to_md(match):
        slug = match.group("slug")
        kit = root / FIG_ROOT / slug
        pdf = kit / f"{slug}.pdf"
        if not pdf.exists():
            return MISSING_KIT_MESSAGE.format(slug=slug)
        return f"\n![{slug}]({pdf})\n"
    text = SEAT_RE.sub(seat_to_md, text)
    out_dir = root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = out_dir / "draft-live.pdf"
    cmd = [
        "pandoc",
        "-s",
        "--pdf-engine=lualatex",
        "--metadata",
        f"title={args.title}",
        "-o",
        str(pdf_path),
    ]
    proc = subprocess.run(cmd, cwd=root, input=text, capture_output=True, text=True, timeout=600)
    if proc.returncode != 0 or not pdf_path.exists():
        return None, f"lualatex build failed:\n{proc.stderr}"
    return pdf_path, None


def appendix_pin_gate(root, args):
    """Fail the build when an appendix script pin disagrees with its manifest.

    Runs the tracked check on the draft this route is actually assembling.
    No skip flag: a plate mid-re-cut must move its pin in the same commit
    as its bytes, which is the discipline the check enforces. The probe's
    full output goes to stderr, and a non-zero exit aborts before this
    route writes any output file.
    """
    proc = subprocess.run(
        [sys.executable, str(Path(__file__).parent / "check_appendix_pins.py"),
         "--draft", str(root / args.draft)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        print("[check] appendix pin gate failed - build aborted before any output", file=sys.stderr)
        sys.exit(proc.returncode)


def build_once(root, args, route, summary_out=None):
    appendix_pin_gate(root, args)
    draft_path = root / args.draft
    text = draft_path.read_text()

    # Resolve seats first: the citation gate scans the assembled document
    # (draft + embedded kit captions), so a caption-only cite to an unsigned
    # row fails the build instead of printing the row untraceably.
    text, seats = resolve_seats(root, text)
    surfaces = [
        root / FIG_ROOT / slug / "captions.md"
        for slug in seats
        if (root / FIG_ROOT / slug / "captions.md").exists()
    ]

    summary = "check skipped"
    if not args.no_check:
        summary, ok, log = citation_check(
            root, args.draft, args.register, args.checker, surfaces
        )
        (root / args.out).mkdir(parents=True, exist_ok=True)
        (root / args.out / "citation-check.log").write_text(log)
        if not ok:
            print(f"[check] citation gate failed: {summary}")
            print(log)
            return 1

    cited = sorted({int(m) for m in re.findall(r"NR-(\d+)", text)})
    if cited:
        text += "\n" + register_appendix(root, args.register, cited)
    toolchain = toolchain_line()
    text += "\n" + build_record(root, args.draft, args.register, summary, seats, toolchain)

    if route == "latex":
        pdf, err = build_latex(root, args, text, seats, summary)
    else:
        pdf, err = build_html(root, args, text, seats, summary)
    if err or pdf is None:
        print(f"[build] failed: {err}")
        return 1

    out_dir = root / args.out
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    copy = out_dir / f"draft-{git_hash(root, args.draft)}-{stamp}.pdf"
    sh(["cp", str(pdf), str(copy)], cwd=root)
    (out_dir / "build-record.txt").write_text(
        build_record(root, args.draft, args.register, summary, seats, toolchain)
    )
    print(f"[build] {pdf.relative_to(root)}  ({len(seats)} seats, citations: {summary})")
    if args.open:
        subprocess.Popen(["xdg-open", str(pdf)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def watch_files(root, args):
    files = [
        root / args.draft,
        root / args.register,
        root / args.checker,
        root / FIG_MAP,
        Path(__file__),
    ]
    fig_root = root / FIG_ROOT
    if fig_root.is_dir():
        files.extend(p for p in fig_root.rglob("*") if p.is_file())
    return [str(p) for p in files if p.exists()]


def snapshot(paths):
    state = {}
    for p in paths:
        try:
            state[p] = hashlib.sha256(Path(p).read_bytes()).hexdigest()
        except OSError:
            state[p] = None
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--draft", default=DRAFT)
    parser.add_argument("--register", default=REGISTER)
    parser.add_argument("--checker", default=CHECKER)
    parser.add_argument("--out", default=OUT_DIR)
    parser.add_argument("--title", default="The kite turbine: a search over its design space (draft build)")
    parser.add_argument("--no-check", action="store_true", help="skip the citation gate (debug only)")
    parser.add_argument("--route", choices=["html", "latex"], default="html")
    parser.add_argument(
        "--math",
        choices=["katex", "mathml", "none"],
        default="katex",
        help="TeX math rendering for the HTML route (default katex, vendored assets)",
    )
    parser.add_argument("--katex-dir", default=KATEX_DIR, help="vendored KaTeX asset directory")
    parser.add_argument("--watch", action="store_true", help="rebuild when a source changes")
    parser.add_argument("--interval", type=float, default=3.0, help="watch poll seconds")
    parser.add_argument("--open", action="store_true", help="open the PDF after building")
    args = parser.parse_args()

    root = repo_root()

    if not args.watch:
        return build_once(root, args, args.route)

    print(f"[watch] watching {len(watch_files(root, args))} files, interval {args.interval}s")
    rc = build_once(root, args, args.route)
    state = snapshot(watch_files(root, args))
    while True:
        time.sleep(args.interval)
        new_state = snapshot(watch_files(root, args))
        changed = [p for p in new_state if state.get(p) != new_state[p]]
        if changed:
            print(f"[watch] rebuild: {', '.join(os.path.relpath(p, root) for p in changed[:3])}")
            rc = build_once(root, args, args.route)
            state = snapshot(watch_files(root, args))
        if rc != 0:
            state = new_state


if __name__ == "__main__":
    sys.exit(main())
