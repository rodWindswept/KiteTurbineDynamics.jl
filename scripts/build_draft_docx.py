#!/usr/bin/env python3
"""Build the KTD report draft DOCX (LibreOffice Writer review copy).

Seat: hermes (reporting room builder). Same single-source assembly as
build_draft_pdf.py: same draft file, same citation gate, same figure kits,
same register appendix, same build record. Only the output route differs —
pandoc -> DOCX with an A4 reference document, figures embedded as the
shipped PNGs (nothing re-rendered). SVG is not embeddable in the DOCX
format, so the PNG sibling of each kit is used, exactly as shipped.

The DOCX is a review copy for comment and edit in LibreOffice Writer
(Insert > Comment; Edit > Track Changes > Record). It is not the source:
edits land back in the room and are transcribed into the single-source
markdown by the owning seats.

Usage:
  scripts/build_draft_docx.py                  # one build, citation-gated
  scripts/build_draft_docx.py --no-check       # skip the citation gate

Outputs land in scratch/report-pdf-build/: draft-live.docx (stable name),
a timestamped copy, draft-assembled-docx.md, build-record-docx.txt.
Outputs are untracked scratch.
"""

import argparse
import html
import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import build_draft_pdf as bdp

TOOLCHAIN = "pandoc 3.1.3 \u2192 DOCX (A4 reference doc, LibreOffice review copy)"


def seat_to_md(root, match):
    """Replace one seat marker with a markdown image block + captions.

    DOCX cannot embed SVG, so this route uses the kit's PNG sibling —
    still the shipped bytes, nothing re-rendered.
    """
    slug = match.group("slug")
    row = match.group("row")
    kit = root / bdp.FIG_ROOT / slug
    label = f"Figure (roster row {row}) \u00b7 {slug}" if row else slug
    if not kit.is_dir():
        return bdp.MISSING_KIT_MESSAGE.format(slug=slug)
    manifest_path = kit / "manifest.json"
    captions_path = kit / "captions.md"
    image = kit / f"{slug}.png"
    if not image.exists() or not manifest_path.exists() or not captions_path.exists():
        return bdp.MISSING_KIT_MESSAGE.format(slug=slug)
    try:
        manifest = json.loads(manifest_path.read_text())
    except json.JSONDecodeError:
        return bdp.MISSING_KIT_MESSAGE.format(slug=slug)
    plain, tech = bdp.parse_caption_sections(captions_path)
    stamp = bdp.manifest_stamp(manifest)
    block = (
        f"\n![{slug}]({image})\n\n"
        f"**{html.escape(label)}**\n\n"
        f"{plain}\n\n"
        f"> {tech}\n\n"
        f"`Source: {stamp}`\n"
    )
    return block


def resolve_seats_md(root, text):
    seats = []
    for match in bdp.SEAT_RE.finditer(text):
        seats.append(match.group("slug"))
    text = bdp.SEAT_RE.sub(lambda m: seat_to_md(root, m), text)
    return text, seats


def a4_reference_doc(out_dir):
    """Default pandoc reference docx, repaged to A4. Cached in the out dir."""
    ref = out_dir / "reference-a4.docx"
    if ref.exists():
        return ref
    default = out_dir / "reference-default.docx"
    _, err, rc = bdp.sh(
        ["pandoc", "-o", str(default), "--print-default-data-file", "reference.docx"],
        cwd="/",
    )
    if rc != 0:
        sys.exit(f"could not fetch pandoc reference docx: {err}")
    with zipfile.ZipFile(default) as zin:
        names = zin.namelist()
        data = {n: zin.read(n) for n in names}
    doc = data["word/document.xml"]
    # US Letter -> A4 (twips). Patch every pgSz in the reference document
    # (belt), and expand the empty body <w:sectPr /> pandoc ships (braces).
    doc = doc.replace(b'w:w="12240" w:h="15840"', b'w:w="11906" w:h="16838"')
    a4_sectpr = (
        b"<w:sectPr>"
        b'<w:pgSz w:w="11906" w:h="16838"/>'
        b'<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"'
        b' w:header="720" w:footer="720" w:gutter="0"/>'
        b"</w:sectPr>"
    )
    doc = doc.replace(b"<w:sectPr />", a4_sectpr)
    data["word/document.xml"] = doc
    data["word/styles.xml"] = compact_table_style(data["word/styles.xml"])
    with zipfile.ZipFile(ref, "w", zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, data[n])
    default.unlink()
    return ref


# Compact table style: the default pandoc "Table" style carries no borders
# and no size, so register/validation tables render as bare, full-size text.
# Re-skin it with hair borders, tight cell margins, and an 8 pt whole-table
# run size so the review copy reads as a table, not a wall of pipe text.
TABLE_STYLE_RE = re.compile(
    r'<w:style w:type="table"[^>]*>.*?</w:style>', re.DOTALL
)

TABLE_STYLE_COMPACT = (
    '<w:style w:type="table" w:default="1" w:styleId="Table">'
    '<w:name w:val="Table" />'
    '<w:basedOn w:val="TableNormal" />'
    '<w:semiHidden /><w:unhideWhenUsed /><w:qFormat />'
    '<w:tblPr>'
    '<w:tblInd w:w="0" w:type="dxa" />'
    '<w:tblBorders>'
    '<w:top w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '<w:left w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '<w:right w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="999999" />'
    '</w:tblBorders>'
    '<w:tblCellMar>'
    '<w:top w:w="20" w:type="dxa" />'
    '<w:left w:w="80" w:type="dxa" />'
    '<w:bottom w:w="20" w:type="dxa" />'
    '<w:right w:w="80" w:type="dxa" />'
    '</w:tblCellMar>'
    '</w:tblPr>'
    '<w:tblStylePr w:type="wholeTable">'
    '<w:rPr><w:sz w:val="16" /><w:szCs w:val="16" /></w:rPr>'
    '</w:tblStylePr>'
    '<w:tblStylePr w:type="firstRow">'
    '<w:rPr><w:b /><w:sz w:val="16" /><w:szCs w:val="16" /></w:rPr>'
    '<w:tblPr><w:jc w:val="left" /><w:tblInd w:w="0" w:type="dxa" /></w:tblPr>'
    '<w:trPr><w:jc w:val="left" /></w:trPr>'
    '<w:tcPr><w:vAlign w:val="bottom" />'
    '<w:shd w:val="clear" w:color="auto" w:fill="EEEEEE" /></w:tcPr>'
    '</w:tblStylePr>'
    '</w:style>'
)


def compact_table_style(styles_xml: bytes) -> bytes:
    """Replace the default table style with a bordered, 8 pt compact one."""
    text = styles_xml.decode("utf-8")
    if not TABLE_STYLE_RE.search(text):
        return styles_xml  # no table style to skin; leave untouched
    return TABLE_STYLE_RE.sub(TABLE_STYLE_COMPACT, text).encode("utf-8")


def build_docx(root, args, text, seats, summary):
    bdp.appendix_pin_gate(root, args)
    out_dir = root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    intermediate = out_dir / "draft-assembled-docx.md"
    intermediate.write_text(text)
    ref = a4_reference_doc(out_dir)
    docx_path = out_dir / "draft-live.docx"
    cmd = [
        "pandoc",
        "-f",
        "markdown-smart",
        str(intermediate),
        "-s",
        "--reference-doc",
        str(ref),
        "-o",
        str(docx_path),
    ]
    _, err, rc = bdp.sh(cmd, cwd=root, timeout=300)
    if rc != 0 or not docx_path.exists() or docx_path.stat().st_size == 0:
        return None, f"pandoc docx failed:\n{err}"
    return docx_path, None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--draft", default=bdp.DRAFT)
    parser.add_argument("--register", default=bdp.REGISTER)
    parser.add_argument("--checker", default=bdp.CHECKER)
    parser.add_argument("--out", default=bdp.OUT_DIR)
    parser.add_argument("--no-check", action="store_true", help="skip the citation gate (debug only)")
    args = parser.parse_args()

    root = bdp.repo_root()
    draft_path = root / args.draft
    text = draft_path.read_text()

    summary = "check skipped"
    if not args.no_check:
        summary, ok, log = bdp.citation_check(root, args.draft, args.register, args.checker)
        (root / args.out).mkdir(parents=True, exist_ok=True)
        (root / args.out / "citation-check.log").write_text(log)
        if not ok:
            print(f"[check] citation gate failed: {summary}")
            print(log)
            return 1

    text, seats = resolve_seats_md(root, text)
    cited = sorted({int(m) for m in __import__("re").findall(r"NR-(\d+)", text)})
    if cited:
        text += "\n" + bdp.register_appendix(root, args.register, cited)
    text += "\n" + bdp.build_record(root, args.draft, args.register, summary, seats, TOOLCHAIN)

    docx, err = build_docx(root, args, text, seats, summary)
    if err or docx is None:
        print(f"[build] failed: {err}")
        return 1

    out_dir = root / args.out
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    copy = out_dir / f"draft-{bdp.git_hash(root, args.draft)}-{stamp}.docx"
    bdp.sh(["cp", str(docx), str(copy)], cwd=root)
    (out_dir / "build-record-docx.txt").write_text(
        bdp.build_record(root, args.draft, args.register, summary, seats, TOOLCHAIN)
    )
    print(f"[build] {docx.relative_to(root)}  ({len(seats)} seats, citations: {summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
