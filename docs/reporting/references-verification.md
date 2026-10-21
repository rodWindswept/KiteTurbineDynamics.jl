# References verification: the source pass on `references.bib`

**Slug** `references-verification`

**Date** 2026-10-08. **Status** PASS, 15 of 18 checked, 3 open. **Owner** @science-writer. **Readers** the report room, @author, @hermes.

## 1. Scope and method

This record covers the verification pass on `docs/reporting/references.bib` (seed `a7ca235`). The pass ran on 2026-10-08.

- I re-read every DOI from Crossref and compared each field with the entry.
- I fetched every URL again and checked it against the named work.
- I read the chapter title of Read (2018) from the publisher page-one preview PDF.
- No value passed on the seed notes. Every value passed on its own record.

Result: 15 of 18 entries verified. Three entries hold no public source yet. They stay `[pending]` and wait on a room decision (section 4).

## 2. The 15 checked entries

| Entry | Source read | Result |
|---|---|---|
| `loyd1980crosswind` | Crossref, `10.2514/3.48021` | J. Energy 4(3):106-111, 1980. The title note holds. |
| `cherubini2015airborne` | Crossref, `10.1016/j.rser.2015.07.053` | RSER 51:1461-1476, 2015. |
| `diehl2013airborne` | Crossref, `10.1007/978-3-642-39965-7_1` | Springer Berlin Heidelberg, pages 3-22, 2013. |
| `trevisi2020unified` | Crossref, `10.1016/j.renene.2020.07.129` | Renewable Energy 162:893-907, 2020. The record note holds. |
| `vanderburg2022dominant` | Crossref, `10.3390/en15197291` | Energies 15(19):7291, 2022. |
| `vandekaa2021exploring` | Crossref, `10.1016/j.jclepro.2021.128918` | J. Clean. Prod. 321:128918, 2021. |
| `pereira2023review` | Crossref, `10.3390/en16010351` | Energies 16(1):351, online 28 December 2022. The year note holds. |
| `flather1895rope` | archive.org item `ropedrivingtreat00flatrich` | Item live. Title and author match. |
| `tulloch2023tensile` | Crossref, `10.3390/en16062610` | Energies 16(6):2610, online 9 March 2023. The year note holds. |
| `benhaiem2018rotating` | Crossref, `10.1007/978-981-10-1947-0_22` | Springer Singapore, pages 539-577, 2018. |
| `read2018kitenetworks` | DOI record and page-one preview | Pages 515-537, 2018. Title ruling: section 3, item 4. |
| `joshi2025system` | Crossref, `10.5194/wes-10-695-2025` | Wind Energy Science 10(4):695-718, 2025. |
| `aull2020design` | Crossref, `10.3390/automation1010001` | Automation 1(1):1-16, 2020. The DOI note holds. |
| `joshi2023value` | Crossref, `10.3390/en16042075` | Energies 16(4):2075, 2023. |
| `weber2021challenges` | energy.gov PDF and the OSTI record `10.2172/1813974` | Both live. The companion DOI resolves to "Airborne Wind Energy", August 2021. The same DOE URL stands in the reference list of `joshi2025system`. |

## 3. Corrections and rulings applied

1. **Tulloch year.** The journal record stands: Energies 16(6):2610, 9 March 2023. The seed note carries the point. No change to the entry.

2. **Aull DOI.** The entry keeps the registered form. The corpus form carries an extra zero and does not resolve.

3. **Trevisi record.** The entry keeps the DOI record: volume 162, 2020. The 2021 range belongs to the companion paper.

4. **Read (2018) title.** The printed chapter reads "Kite Networks for Harvesting Wind Energy". The page-one preview carries the space. The Springer HTML page and the Crossref record render "HarvestingWind", with no space. Ruling: the citation follows the printed form. The entry carries that form now, and the note keeps the quirk.

## 4. The three entries without a public source — settled 2026-10-17 (founder)

### 4.1 `ranneberg2014rotokite` — DROPPED

Founder ruling 2026-10-17: EnerKíte is a pumping/yo-yo company. The
"rotary momentum frame" attribution in the draft does not hold, and the
report has no solid use for the citation. The `.bib` entry and the §1
prose line were both removed.

### 4.2 `jamieson` — UPGRADED to a peer-reviewed source

Founder ruling 2026-10-17: keep, prefer the original published work. A
public, peer-reviewed source was located: Jamieson, P. and Branney, M.
(2012), "Multi-rotors; a solution to 20 MW and beyond?", Energy Procedia
24:52-59, DOI 10.1016/j.egypro.2012.06.086 (135 citations, ScienceDirect).
The 2024 Glasgow deck entry was replaced by `jamieson2012multirotor`.

### 4.3 `hancock2024bladelens` — KEPT on the weaker standard

Founder ruling 2026-10-17: keep with a weaker standard. No published
equivalent was located (Hancock is a career blade engineer at LM Wind
Power). The entry now records "slides held, no public archive" in the
note, and the `.bib` comment marks the weaker standard.

## 5. Gate statement

The 16 checked entries pass the references gate. The Hancock entry stands
on the weaker standard with an explicit no-public-archive note. Ranneberg
is dropped.

## 6. Unterweger entry and the section 8 render (2026-10-21)

The founder ruled the DOI standard on 2026-10-21 (return 3, comment 14).
Section 8 prints the rendered bibliography now, and the builder seat ran the rebuild.

- The Unterweger entry joined on the same ruling (return 3, comment 98). The URL resolves. The page prints no year, so the year field reads n.d.

- The render numbers by first appearance. Entries 1 to 10 match the body order. Entries 11 to 18 keep the file order.

- The checked count moves from 16 to 17: sixteen from the 2026-10-08 pass plus Unterweger, checked by URL.

## 7. Hancock cites as unpublished (2026-10-21)

The founder ruled the one residual call: the entry without a public DOI cites as unpublished. The weaker-standard label from 2026-10-17 ("slides held, no public archive") leaves the report entry and the note. Both now read "Unpublished". The `.bib` comment records both rulings. Section 4.3 above stays as the record. This section supersedes its weaker-standard sentence.

## 8. Unterweger entry corrected from the artefact (2026-10-21)

Section 6 recorded the year as `n.d.` because the someawe.org page prints no year.
The artefact prints one on every page.
The PDF in the corpus reads `Master's Thesis Presentation` on the title slide.
The same slide reads `January 31, 2022`, and every footer repeats the date.
Page one reads `1 / 47`.
The document metadata records a CreationDate of 31 January 2022.

The wiki note carries 2021 in its header.
No page of the artefact prints 2021.

The printed form wins over the page, per the gate rule.

- The entry now reads `Master thesis presentation`, year 2022, and 47 slides in the note.

- The checked count stays 17.
The entry was already inside it on a resolving URL.
This pass upgrades the evidence from a live URL to an artefact read.
It adds no entry.

- The draft section 8 line still reads "Master thesis, no year printed, posted by the Some AWE group".
The render follows this entry when the draft owner lands it.

Gate statement: the entry passes on its own artefact read.
No other entry moves.
