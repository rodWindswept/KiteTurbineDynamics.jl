#!/usr/bin/env node
"use strict";

/**
 * Phase L: Generate TRPT_Optimisation_Report_v4.docx
 * Covers the v2 → v3 → v4 structural optimisation campaign.
 */

const fs   = require("fs");
const path = require("path");

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, Header, Footer, AlignmentType, HeadingLevel, BorderStyle,
  WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak,
  LevelFormat, TabStopType, TabStopPosition,
} = require("docx");

// ── Paths ─────────────────────────────────────────────────────────────────────
const WORKTREE = path.resolve(__dirname, "..");
const FIGS     = path.join(WORKTREE, "figures");
const OUT      = path.join(WORKTREE, "TRPT_Optimisation_Report_v4.docx");

// ── Palette ───────────────────────────────────────────────────────────────────
const WS_BLUE   = "1a6b9a";
const WS_ORANGE = "e07b39";
const DARK      = "222222";
const MID_GREY  = "666666";
const LIGHT_BG  = "EEF4F8";
const HEADER_BG = "1a6b9a";

// ── Page geometry (A4, 2 cm margins) ─────────────────────────────────────────
// A4: 11906 × 16838 DXA   |   2 cm = 1134 DXA   |   content width = 9638 DXA
const PAGE_W   = 11906;
const PAGE_H   = 16838;
const MARGIN   = 1134;   // ~2 cm
const CONTENT_W = PAGE_W - 2 * MARGIN;   // 9638 DXA

// ── Helpers ───────────────────────────────────────────────────────────────────

function img(filename, widthPx, heightPx) {
  const p = path.join(FIGS, filename);
  if (!fs.existsSync(p)) {
    console.warn(`WARN: figure not found: ${p}`);
    return null;
  }
  const data = fs.readFileSync(p);
  const ext  = path.extname(filename).slice(1).toLowerCase();
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 160, after: 80 },
    children: [
      new ImageRun({
        type: ext === "jpg" ? "jpeg" : ext,
        data,
        transformation: { width: widthPx, height: heightPx },
        altText: { title: filename, description: filename, name: filename },
      }),
    ],
  });
}

function caption(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 240 },
    children: [
      new TextRun({
        text,
        italics: true,
        size: 18,   // 9pt
        color: MID_GREY,
        font: "Arial",
      }),
    ],
  });
}

function para(text, opts = {}) {
  return new Paragraph({
    spacing: { before: 0, after: 200 },
    alignment: AlignmentType.JUSTIFIED,
    ...opts,
    children: [
      new TextRun({
        text,
        size: 22,   // 11pt
        font: "Arial",
        color: DARK,
        ...opts.run,
      }),
    ],
  });
}

function bold(text, size = 22) {
  return new TextRun({ text, bold: true, size, font: "Arial", color: DARK });
}

function run(text, opts = {}) {
  return new TextRun({ text, size: 22, font: "Arial", color: DARK, ...opts });
}

function mixedPara(runs, opts = {}) {
  return new Paragraph({
    spacing: { before: 0, after: 200 },
    alignment: AlignmentType.JUSTIFIED,
    ...opts,
    children: runs,
  });
}

const CELL_BORDER = { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC" };
const CELL_BORDERS = {
  top: CELL_BORDER, bottom: CELL_BORDER,
  left: CELL_BORDER, right: CELL_BORDER,
};

function headerCell(text, w) {
  return new TableCell({
    width: { size: w, type: WidthType.DXA },
    borders: CELL_BORDERS,
    shading: { fill: HEADER_BG, type: ShadingType.CLEAR },
    margins: { top: 80, bottom: 80, left: 140, right: 140 },
    verticalAlign: VerticalAlign.CENTER,
    children: [
      new Paragraph({
        children: [new TextRun({ text, bold: true, color: "FFFFFF", size: 18, font: "Arial" })],
      }),
    ],
  });
}

function dataCell(text, w, shade = false) {
  return new TableCell({
    width: { size: w, type: WidthType.DXA },
    borders: CELL_BORDERS,
    shading: { fill: shade ? "F5F8FB" : "FFFFFF", type: ShadingType.CLEAR },
    margins: { top: 80, bottom: 80, left: 140, right: 140 },
    children: [
      new Paragraph({
        children: [new TextRun({ text, size: 18, font: "Arial", color: DARK })],
      }),
    ],
  });
}

function makeTable(headers, rows, colWidths) {
  const total = colWidths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((h, i) => headerCell(h, colWidths[i])),
      }),
      ...rows.map((row, ri) =>
        new TableRow({
          children: row.map((cell, ci) => dataCell(cell, colWidths[ci], ri % 2 === 0)),
        })
      ),
    ],
  });
}

function hRule(color = "CCCCCC", size = 6) {
  return new Paragraph({
    spacing: { before: 120, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size, color, space: 1 } },
    children: [],
  });
}

function spacer(after = 120) {
  return new Paragraph({ spacing: { after }, children: [] });
}

// ── Section builders ──────────────────────────────────────────────────────────

function titleSection() {
  return [
    spacer(2880),   // push title down ~2 inches
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 160 },
      children: [
        new TextRun({
          text: "TRPT Structural Optimisation",
          bold: true,
          size: 52,
          font: "Arial",
          color: WS_BLUE,
        }),
      ],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 320 },
      children: [
        new TextRun({
          text: "Torsional Constraint Recovery and Variable Ring Spacing (v2\u2013v4 Campaign)",
          bold: true,
          size: 32,
          font: "Arial",
          color: DARK,
        }),
      ],
    }),
    hRule(WS_BLUE, 12),
    spacer(400),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 120 },
      children: [new TextRun({ text: "Windswept Energy", bold: true, size: 26, font: "Arial", color: DARK })],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 120 },
      children: [new TextRun({ text: "April 2026", size: 24, font: "Arial", color: MID_GREY })],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 120 },
      children: [new TextRun({ text: "KiteTurbineDynamics.jl \u2014 Campaign trpt_opt_v4", size: 22, font: "Arial", color: MID_GREY, italics: true })],
    }),
    spacer(2880),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function execSummary() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "1. Executive Summary", font: "Arial" })],
    }),
    hRule(),
    para(
      "This report documents three successive optimisation campaigns " +
      "(v2, v3, and v4) that sized the Tensile Rotary Power Transmission (TRPT) shaft " +
      "of the Windswept kite turbine for 10\u202fkW and 50\u202fkW power classes, with the " +
      "objective of minimising structural mass while satisfying Euler column-buckling " +
      "and torsional stability constraints. The shaft is the airborne structural spine " +
      "of the kite turbine: a tapered polygon frame of carbon-fibre tubes linking " +
      "rotor rings from hub to ground, transmitting torque without a conventional " +
      "tower or gearbox."
    ),
    para(
      "The v2 campaign introduced Differential Evolution (DE) optimisation across " +
      "60 islands and achieved a nominal 10\u202fkW best mass of 2.808\u202fkg, but only " +
      "constrained Euler beam buckling. Post-hoc analysis revealed that 54 of 60 " +
      "island designs were torsionally infeasible, with the torsional factor of safety " +
      "falling as low as 0.069 against the Tulloch/Wacker collapse criterion. " +
      "These designs were physically invalid."
    ),
    para(
      "The v3 campaign added an explicit torsional stability constraint " +
      "(compressive FOS \u2265 1.5 against 500\u202fMPa CFRP limit) and recovered valid " +
      "designs, but the formulation forced a cylindrical taper (taper ratio = 1.0) " +
      "to isolate the effect of the new constraint. The 10\u202fkW optimum rose to " +
      "15.435\u202fkg \u2014 a 5.5\u00d7 mass penalty relative to the infeasible v2 result, " +
      "confirming that the torsional criterion is structurally significant."
    ),
    para(
      "The v4 campaign restored taper freedom and replaced the arbitrary axial-profile " +
      "family with a physically motivated constant L/r ring-spacing rule, " +
      "in which every inter-ring segment operates at the same normalised slenderness. " +
      "Ring count and positions became derived quantities rather than free variables. " +
      "Across all 60 islands (all feasible), the 10\u202fkW optimum converged to " +
      "10.587\u202fkg \u2014 a 31.4\u202f% reduction on v3 and within 3.8\u00d7 of " +
      "the physically unattainable v2 value. The 50\u202fkW optimum was 79.51\u202fkg."
    ),
    para(
      "Phase K analysis of the v4 results established four design rules: " +
      "all islands preferred n_lines\u202f=\u202f8 polygon lines; circular and elliptical " +
      "cross-sections are mass-equivalent and roughly 6.7\u00d7 lighter than airfoil " +
      "sections; the preferred L/r ratio is approximately 2.0 at 10\u202fkW; and " +
      "aggressive taper is strongly confirmed, with r_bottom/r_hub \u2248 0.21 at " +
      "10\u202fkW and \u22480.08 at 50\u202fkW. These findings directly inform the v5 " +
      "campaign specification."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionBackground() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "2. Background: TRPT and the Torsional Collapse Problem", font: "Arial" })],
    }),
    hRule(),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "2.1 What is TRPT?", font: "Arial" })],
    }),
    para(
      "Tensile Rotary Power Transmission is the load-bearing and power-transmitting " +
      "structure of the Windswept kite turbine. Rotor blades rotate in a ring at " +
      "altitude, generating aerodynamic torque. Instead of a conventional tower, " +
      "the torque is carried to ground by a helical tensile shaft: a series of " +
      "rigid polygon frames (rings) connected by tether lines running at a " +
      "constant helix angle. As the rings are progressively twisted relative " +
      "to one another, the tether lines carry both tension and shear, " +
      "transmitting the net torque to a ground-level generator without a gearbox " +
      "or rigid mast. The shaft tapers from a wide hub ring at rotor altitude " +
      "to a narrow ground ring, so that the lower sections \u2014 which experience " +
      "lower tether tension \u2014 can be made correspondingly lighter."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "2.2 The Torsional Collapse Criterion", font: "Arial" })],
    }),
    para(
      "Each polygon ring is a structural frame: n_lines beams (carbon-fibre tubes) " +
      "joined at vertices (knuckle fittings). The tether lines pull inward at each " +
      "vertex with force proportional to the transmitted torque and inversely " +
      "proportional to the ring radius. This inward force places the polygon beams " +
      "in compression. The Tulloch/Wacker torsional collapse criterion " +
      "describes a physical instability: the restoring torque of the shaft " +
      "has a maximum beyond which the rings collapse inward. " +
      "The critical torque capacity is:"
    ),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 120 },
      children: [
        new TextRun({
          text: "\u03c4_cap = T_total \u00d7 r\u00b2 / \u221a(L\u00b2 + 2r\u00b2)",
          italics: true,
          size: 22,
          font: "Arial",
          color: DARK,
        }),
      ],
    }),
    para(
      "where r is the ring radius and L is the inter-ring segment length. " +
      "The ratio L/r is therefore the key stability parameter: " +
      "as L/r decreases (rings packed closer together relative to their radius), " +
      "the collapse threshold falls and the structure becomes more vulnerable. " +
      "Empirically, a threshold near L/r \u2248 1.0 marks the onset of torsional " +
      "instability; practical designs operate well above this value."
    ),
    para(
      "The v2 campaign constrained only Euler column buckling of the polygon beams " +
      "(P_crit/N_comp \u2265 1.8), and did not evaluate torsional stability. " +
      "Because the optimiser was free to reduce ring radius and pack rings densely " +
      "to minimise beam length and hence beam mass, it routinely produced " +
      "designs with L/r far below the stability threshold. " +
      "Retrospective analysis found 54 of the 60 v2 island results were " +
      "torsionally infeasible, with the minimum torsional FOS reaching 0.069 \u2014 " +
      "roughly 15\u00d7 below the requirement. The apparent 2.808\u202fkg optimum was " +
      "physically unrealisable."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "2.3 Why L/r is the Central Design Parameter", font: "Arial" })],
    }),
    para(
      "Once torsional stability is enforced, the L/r ratio at each ring becomes " +
      "the governing structural quantity. A high L/r (long segments relative to " +
      "ring radius) reduces the inward line force per vertex, lowering polygon " +
      "compression and reducing required beam cross-section. However, it also " +
      "reduces the number of rings along the shaft, which affects torsional " +
      "stiffness and the distribution of the total shaft torque across segments. " +
      "The v4 formulation explicitly targets a constant L/r throughout the " +
      "tapered shaft by deriving ring positions from a geometric series, " +
      "ensuring every segment is loaded at the same normalised slenderness. " +
      "This is structurally optimal for a column under axial compression: " +
      "no segment carries headroom that another segment cannot afford."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionFormulation() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "3. Optimisation Formulation", font: "Arial" })],
    }),
    hRule(),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "3.1 Decision Variables", font: "Arial" })],
    }),
    para(
      "The v4 campaign optimised nine independent design variables. " +
      "Ring positions and ring count were derived quantities, not free variables."
    ),
    spacer(80),
    makeTable(
      ["Variable", "Symbol", "Bounds", "Description"],
      [
        ["Do_top",        "D\u2080",    "5\u2013120 mm (scaled)", "Outer beam diameter at hub ring"],
        ["t_over_D",      "t/D",       "0.01\u20130.05",         "Wall thickness ratio"],
        ["beam_aspect",   "b/a or t/c","Profile-dependent",     "Ellipticity (elliptical) or thickness ratio (airfoil)"],
        ["Do_scale_exp",  "\u03b1",    "0\u20131",               "Taper exponent: D(r) = D\u2080\u00b7(r/r_hub)^\u03b1"],
        ["r_hub",         "r_top",     "0.8\u20131.2 \u00d7 r_rotor", "Hub ring radius (m)"],
        ["r_bottom",      "r_bot",     "0.3\u20131.5 m",         "Ground ring radius (m)"],
        ["target_Lr",     "L/r",       "0.4\u20132.0",           "Target slenderness for each shaft segment"],
        ["knuckle_mass",  "m_k",       "0.01\u20130.20 kg",      "Per-vertex knuckle fitting mass"],
        ["n_lines",       "n",         "3\u20138 (integer)",      "Polygon sides (ring vertices)"],
      ],
      [2200, 1400, 2000, 3438]
    ),
    spacer(160),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "3.2 Constant L/r Ring Spacing \u2014 the v4 Innovation", font: "Arial" })],
    }),
    para(
      "For a linearly tapered shaft tapering from r_hub at the top to r_bottom " +
      "at the ground over total tether length L_tether, the constant-L/r " +
      "constraint requires every inter-ring segment to satisfy:"
    ),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 80 },
      children: [new TextRun({ text: "L_seg_i / r_mid_i = target_Lr    (for all i)", italics: true, size: 22, font: "Arial", color: DARK })],
    }),
    para(
      "Under a linear taper, this produces ring radii forming a geometric series " +
      "r_i = r_hub \u00b7 k^i, where the common ratio is:"
    ),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 80 },
      children: [new TextRun({ text: "k = (2 \u2212 \u03b1\u00b7c) / (2 + \u03b1\u00b7c),    \u03b1 = (r_hub \u2212 r_bottom) / L_tether,    c = target_Lr", italics: true, size: 22, font: "Arial", color: DARK })],
    }),
    para(
      "The ring count n_rings was derived from the geometric series terminating " +
      "at r_bottom; it was not a free variable. A 9-parameter design vector " +
      "therefore fully determined a complete shaft layout. This replaced the " +
      "v2/v3 approach of selecting a ring count explicitly and distributing rings " +
      "according to one of five parametric axial-profile families " +
      "(linear, elliptic, parabolic, trumpet, straight-taper), which added " +
      "parameters without physical motivation."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "3.3 Beam Cross-Section Families", font: "Arial" })],
    }),
    para(
      "Three cross-section families were included in the v4 campaign. " +
      "Circular thin-walled tubes were parametrised by Do_top and t/D alone (beam_aspect fixed at 1.0). " +
      "Elliptical thin-walled tubes added a minor-to-major axis ratio b/a as a free variable. " +
      "NACA-style airfoil sections used a thickness-to-chord ratio t/c in place of the aspect ratio."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "3.4 Constraints", font: "Arial" })],
    }),
    spacer(80),
    makeTable(
      ["Constraint", "Threshold", "Implementation"],
      [
        ["Euler column buckling FOS",  "\u2265 1.8", "Hard penalty (mass \u2192 \u221e if infeasible)"],
        ["Torsional compressive FOS",  "\u2265 1.5", "Hard penalty; \u03c3_comp \u2264 500 MPa / 1.5 = 333 MPa"],
        ["Ground ring radius",         "\u2264 1.5 m","Hard geometric bound on r_bottom"],
        ["Wall thickness ratio t/D",   "0.01\u20130.15", "Manufacturability bounds"],
      ],
      [3200, 1900, 4538]
    ),
    spacer(160),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "3.5 Differential Evolution Setup", font: "Arial" })],
    }),
    para(
      "The campaign ran 60 independent Differential Evolution (DE) islands on a " +
      "168-hour compute budget, with approximately 2.8 hours per island. " +
      "Islands covered two power configurations (10\u202fkW and 50\u202fkW), " +
      "three beam profiles (circular, elliptical, airfoil), five L/r " +
      "initialisation zones (biased starting populations from [0.4\u20130.8] to [1.6\u20132.0]), " +
      "and two independent random seeds \u2014 giving " +
      "2 \u00d7 3 \u00d7 5 \u00d7 2 = 60 islands. " +
      "DE parameters were population 64, mutation factor F\u202f=\u202f0.7, " +
      "crossover CR\u202f=\u202f0.9, with stall-restart at 1,500 stagnant generations. " +
      "Each island performed approximately 1.28\u202f\u00d7\u202f10\u2078 function evaluations."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionProgression() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "4. Campaign Progression: v2 \u2192 v3 \u2192 v4", font: "Arial" })],
    }),
    hRule(),
    para(
      "Three successive campaigns refined the TRPT shaft design. " +
      "Each introduced a correction to a physical shortcoming of its predecessor."
    ),
    spacer(80),
    makeTable(
      ["Campaign", "Constraint set", "Best mass (10\u202fkW)", "Torsional FOS", "Notes"],
      [
        ["v2", "Beam buckling FOS \u2265 1.8 only",
          "2.808 kg",  "Not checked",
          "54/60 islands torsionally infeasible (FOS as low as 0.069). Physically invalid."],
        ["v3", "Beam FOS \u2265 1.8 + torsional FOS \u2265 1.5",
          "15.435 kg", "1.50 (at limit)",
          "Valid but cylindrical (taper ratio forced to 1.0). 5 rings, r_hub = 1.99 m."],
        ["v4", "Beam FOS \u2265 1.8 + torsional FOS \u2265 1.5",
          "10.587 kg", "1.50 (all feasible)",
          "Taper free, constant L/r spacing. \u224819 rings, r_hub = 1.6 m. \u221231.4 % vs v3."],
      ],
      [900, 2800, 1700, 1500, 2738]
    ),
    spacer(200),
    para(
      "The v2 campaign established the DE infrastructure and explored the " +
      "full beam-profile space (three cross-section families, five axial-profile " +
      "families, two seeds). Its results were physically unsound: the optimiser " +
      "minimised mass by reducing ring size and packing rings closely, " +
      "inadvertently driving L/r below the torsional stability threshold " +
      "without any constraint to prevent it."
    ),
    para(
      "The v3 campaign introduced the torsional compressive-stress check, " +
      "with FOS \u2265 1.5 enforced as a hard penalty. To isolate the contribution " +
      "of this constraint from other changes, the shaft taper was fixed " +
      "cylindrical (taper ratio = 1.0) for v3. The optimum mass rose to " +
      "15.435\u202fkg, confirming that the torsional constraint carries genuine " +
      "structural mass. All 30 v3 10\u202fkW islands converged to the same design, " +
      "regardless of beam profile or axial-profile family \u2014 indicating that the " +
      "torsional constraint, not the beam buckling, became the active driver " +
      "of mass under cylindrical geometry."
    ),
    para(
      "The v4 campaign freed the taper by promoting r_bottom and the taper " +
      "exponent Do_scale_exp to independent decision variables, and replaced " +
      "the five axial-profile families with the constant L/r geometric-series " +
      "rule. Every one of the 60 islands was feasible. The 10\u202fkW optimum " +
      "converged to 10.587\u202fkg with remarkable robustness: all 10 circular " +
      "islands and all 10 elliptical islands returned the same value to " +
      "within numerical precision, regardless of the L/r initialisation zone " +
      "or seed. This is strong evidence that DE found the global optimum."
    ),
    spacer(100),
    (() => {
      const el = img("fig_v2_v3_v4_comparison.png", 540, 305);
      return el || spacer(100);
    })(),
    caption(
      "Figure 1. Comparison of v2, v3, and v4 campaign results for the 10\u202fkW class. " +
      "Left panel: best shaft mass. Right panel: beam and torsional FOS constraint margins. " +
      "v2 is torsionally invalid (FOS not checked); v3 recovers validity at the cost of " +
      "5.5\u00d7 mass; v4 restores taper and recovers 31.4\u202f% of that mass."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionWinnerSpec() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "5. v4 Winning Design Specification", font: "Arial" })],
    }),
    hRule(),
    para(
      "The 10\u202fkW winner was island 11 (elliptical beam profile, L/r initialisation " +
      "zone 1, seed 1). The identical optimum was reached by all 20 non-airfoil " +
      "10\u202fkW islands. The full parameter set is listed below."
    ),
    spacer(80),
    makeTable(
      ["Parameter", "Symbol", "Value"],
      [
        ["Total shaft mass",         "m_total",       "10.587 kg"],
        ["Beam mass",                "m_beams",        "~10.577 kg"],
        ["Knuckle mass",             "m_knuckles",     "0.010 kg \u00d7 n_lines \u00d7 n_rings"],
        ["Beam profile",             "\u2014",         "Circular / Elliptical (identical)"],
        ["n_lines (polygon sides)",  "n",              "8"],
        ["Hub ring radius",          "r_hub",          "1.600 m"],
        ["Ground ring radius",       "r_bottom",       "0.336 m"],
        ["Taper ratio",              "r_bottom/r_hub", "0.210"],
        ["Tether length",            "L",              "30.0 m"],
        ["Target L/r",               "target_Lr",      "2.0"],
        ["Derived ring count",       "n_rings",        "\u224819"],
        ["Top beam diameter",        "Do_top",         "38.9 mm"],
        ["Wall ratio",               "t/D",            "0.020 (minimum manufacturable)"],
        ["Taper exponent",           "\u03b1",         "0.492"],
        ["Beam FOS (worst ring)",    "FOS_beam",       "1.80 (at constraint)"],
        ["Torsional FOS (all rings)","FOS_tors",       "\u22651.50 (all feasible)"],
        ["Evaluations per island",   "\u2014",         "1.28 \u00d7 10\u2078"],
        ["Wall-clock time",          "\u2014",         "200 s per island"],
      ],
      [3500, 2200, 3938]
    ),
    spacer(200),
    para(
      "The winning shaft is a long, narrow, sharply tapering structure. " +
      "With a hub ring of 1.6\u202fm radius tapering to 0.336\u202fm at the ground " +
      "over 30\u202fm of tether, the geometry resembles a slender cone rather " +
      "than the short, wide cylinder produced by v3. The roughly 19 rings " +
      "give inter-ring spacings of order 1.5\u20132.0\u202fm near the hub, " +
      "shrinking to 0.3\u20130.5\u202fm near the ground as the ring radius decreases. " +
      "This is consistent with the constant L/r rule: shorter radii " +
      "demand shorter inter-ring segments to maintain the same normalised slenderness."
    ),
    para(
      "The wall thickness ratio t/D\u202f=\u202f0.020 sat at its lower bound " +
      "throughout, indicating that the optimiser was prevented from making " +
      "thinner walls only by the manufacturability constraint. " +
      "The taper exponent \u03b1\u202f=\u202f0.492 means beam diameter scales as " +
      "D(r)\u202f\u221d\u202fr^{0.49}, roughly as the square root of radius. " +
      "This is close to the theoretically expected scaling for a shaft whose " +
      "dominant load (tether tension) scales with ring area."
    ),
    spacer(100),
    (() => {
      const el = img("fig_v4_geometry.png", 380, 580);
      return el || spacer(100);
    })(),
    caption(
      "Figure 2. Side-elevation schematic of the v4 winning 10\u202fkW shaft. " +
      "The shaft tapers from r_hub\u202f=\u202f1.6\u202fm at the rotor (top) to " +
      "r_bottom\u202f=\u202f0.34\u202fm at the ground over 30\u202fm of tether, " +
      "with approximately 19 rings spaced by the constant L/r\u202f=\u202f2.0 rule."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionDesignSpace() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "6. Design Space Analysis (Phase K)", font: "Arial" })],
    }),
    hRule(),
    para(
      "Phase K carried out a systematic analysis of all 60 v4 island results to " +
      "extract design rules for the v5 campaign. The principal findings are " +
      "summarised below."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "6.1 n_lines: Every Island Chose 8", font: "Arial" })],
    }),
    para(
      "Every one of the 60 islands converged to n_lines\u202f=\u202f8 polygon lines. " +
      "The physical explanation is straightforward: with more polygon sides, " +
      "each beam segment becomes shorter (L_poly \u221d 1/n), and Euler " +
      "buckling capacity scales as P_crit \u221d 1/L\u00b2, so buckling capacity " +
      "grows roughly as n\u00b2. The compressive force per segment N_comp scales " +
      "only slowly with n, giving a strong incentive for more lines. " +
      "The optimum at n\u202f=\u202f8 (rather than the maximum allowed, which was 8) " +
      "reflects the competing cost of knuckle hardware: joint mass scales " +
      "as n_lines \u00d7 n_rings, so beyond a crossover point additional lines " +
      "cost more in knuckles than they save in beam material."
    ),
    para(
      "Because every island returned n_lines\u202f=\u202f8 against the upper " +
      "bound of 8, the true optimum in n may lie above 8. " +
      "The v5 campaign should raise the upper bound to at least 12 and " +
      "reduce the knuckle mass assumption, which currently makes joints " +
      "disproportionately expensive at high n."
    ),
    new Paragraph({
      spacing: { before: 160, after: 200 },
      alignment: AlignmentType.JUSTIFIED,
      border: {
        left: { style: BorderStyle.SINGLE, size: 12, color: WS_ORANGE, space: 6 },
      },
      indent: { left: 360 },
      children: [
        new TextRun({ text: "Important caveat \u2014 aerodynamic efficiency not modelled: ", bold: true, size: 22, font: "Arial", color: WS_ORANGE }),
        new TextRun({
          text:
            "The v4 objective function treated power output (10\u202fkW or 50\u202fkW) as a " +
            "fixed target independent of n_lines. In wind rotor aerodynamics, " +
            "increasing blade or line count raises rotor solidity, which reduces the " +
            "induction factor efficiency and the power coefficient C_p \u2014 this is why " +
            "commercial wind turbines use three blades rather than ten. " +
            "If n_lines also governs rotor blade count in the Windswept design, " +
            "higher n_lines may require a larger rotor to achieve the same power output, " +
            "increasing structural loads and partially or fully offsetting the mass " +
            "saving from shorter polygon beams. " +
            "The n_lines\u202f=\u202f8 result therefore assumes rotor aerodynamic efficiency is " +
            "independent of line count. This assumption has not been verified. " +
            "If blade-count solidity effects reduce C_p at high n_lines, the " +
            "true structural optimum may be at a lower n_lines than 8.",
          size: 22, font: "Arial", color: DARK,
        }),
      ],
    }),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "6.2 Cross-Section: Circular \u2248 Elliptical \u226b Airfoil", font: "Arial" })],
    }),
    para(
      "Circular and elliptical sections produced identical mass results " +
      "for both power classes: 10.587\u202fkg at 10\u202fkW and 79.51\u202fkg " +
      "at 50\u202fkW. The elliptical section degenerates to circular (beam_aspect " +
      "converges to 1.0) because the loading on each polygon beam is " +
      "circumferentially symmetric: all n_lines beams in a ring experience " +
      "equal compressive load regardless of orientation. An asymmetric " +
      "cross-section therefore offers no structural benefit."
    ),
    para(
      "Airfoil cross-sections incurred a 6.7\u00d7 mass penalty at 10\u202fkW " +
      "(70.78\u202fkg vs 10.587\u202fkg) and 9.4\u00d7 at 50\u202fkW " +
      "(749.50\u202fkg vs 79.51\u202fkg). An airfoil profile has low second moment " +
      "of area in the minor-axis direction and a large enclosed cross-sectional " +
      "area, so it is simultaneously weak in the critical Euler buckling " +
      "direction and heavy. For TRPT polygon frames, airfoil sections are " +
      "anti-optimal. The v5 campaign should exclude the airfoil family entirely."
    ),
    spacer(80),
    (() => {
      const el = img("fig_v4_pareto.png", 520, 325);
      return el || spacer(80);
    })(),
    caption(
      "Figure 3. Final shaft mass for all 60 v4 islands, grouped by power configuration " +
      "and beam profile. Within each group, 10 seeds/variants (5 L/r zones \u00d7 2 seeds) " +
      "are plotted individually; horizontal lines show group means. " +
      "Circular and elliptical results are indistinguishable; airfoil results are " +
      "dramatically heavier. The 10\u202fkW winner is marked with a gold star."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "6.3 Preferred L/r Ratio", font: "Arial" })],
    }),
    para(
      "For 10\u202fkW circular and elliptical designs, target_Lr converged " +
      "tightly to 2.0 \u2014 the upper end of the search space [0.4, 2.0]. " +
      "This means the optimiser consistently preferred the longest " +
      "inter-ring spacings available. Longer spacings reduce the number " +
      "of rings for a given tether length, lowering total knuckle mass, " +
      "and allow the polygon beams to span wider distances which " +
      "reduces the required compressive resistance per beam. " +
      "Airfoil and 50\u202fkW designs showed wider scatter in target_Lr, " +
      "as those configurations hit the structural limit harder and " +
      "the optimiser explored a broader range before convergence."
    ),
    para(
      "The consistent pressure against the upper bound of the L/r search space " +
      "is a further signal that the v5 campaign should relax this bound. " +
      "There is no physical reason to cap L/r at 2.0; values up to " +
      "3.0 or higher may yield further mass reduction if torsional " +
      "stability remains satisfied."
    ),
    spacer(80),
    (() => {
      const el = img("fig_v4_Lr_sweep.png", 520, 325);
      return el || spacer(80);
    })(),
    caption(
      "Figure 4. L/r sensitivity analysis from the v4 campaign. " +
      "10\u202fkW circular/elliptical islands cluster at target_Lr \u2248 2.0 " +
      "(upper bound), indicating that the optimal L/r is at or beyond the " +
      "current search limit."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "6.4 Taper: Aggressive Taper Confirmed", font: "Arial" })],
    }),
    para(
      "All islands strongly preferred tapered shafts. The mean r_bottom/r_hub " +
      "was 0.210 for 10\u202fkW designs and 0.084 for 50\u202fkW designs. " +
      "These values indicate sharply conical geometry: the 50\u202fkW ground " +
      "ring has a radius less than one-twelfth that of the hub ring."
    ),
    para(
      "The physical driver is the load distribution along the shaft. " +
      "Lower rings carry less tether tension and experience smaller " +
      "polygon compression forces, so they can be made dramatically smaller " +
      "without violating structural constraints. Making the lower rings " +
      "small reduces both beam mass (shorter polygon circumference) and " +
      "knuckle count. The extreme taper values in the 50\u202fkW case suggest " +
      "that the ground ring radius is approaching the lower bound of the " +
      "search space and may benefit from being relaxed in v5."
    ),
    spacer(80),
    (() => {
      const el = img("fig_v4_taper_heatmap.png", 480, 300);
      return el || spacer(80);
    })(),
    caption(
      "Figure 5. Taper ratio (r_bottom/r_hub) versus shaft mass for all 60 v4 islands. " +
      "Both power classes show consistent clustering at aggressive taper values " +
      "(0.21 at 10\u202fkW, 0.08 at 50\u202fkW), confirming that cylindrical or " +
      "mildly tapered designs are suboptimal."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "6.5 Convergence Robustness", font: "Arial" })],
    }),
    para(
      "The 60-island heatmap (Figure 6) illustrates the convergence quality " +
      "of the v4 campaign. Within each (configuration, beam profile) group, " +
      "all 10 seeds and L/r initialisation variants returned the same mass " +
      "to within numerical precision. The only within-group variation is " +
      "between the three beam profiles, and that variation is large and " +
      "structurally meaningful. This consistency across different starting " +
      "conditions and random seeds provides strong evidence that the " +
      "Differential Evolution algorithm located the global optimum for " +
      "each group, rather than a seed-dependent local minimum."
    ),
    spacer(80),
    (() => {
      const el = img("fig_v4_island_heatmap.png", 550, 275);
      return el || spacer(80);
    })(),
    caption(
      "Figure 6. 60-island heatmap of v4 campaign results (log\u2081\u2080 kg scale). " +
      "Rows correspond to (power config, beam profile) groups; " +
      "columns correspond to the 10 (variant, seed) combinations. " +
      "Within each row, values are identical to 3\u202fsignificant figures, " +
      "confirming global convergence."
    ),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

function sectionConclusions() {
  return [
    new Paragraph({
      heading: HeadingLevel.HEADING_1,
      children: [new TextRun({ text: "7. Conclusions and Next Steps", font: "Arial" })],
    }),
    hRule(),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "7.1 Conclusions", font: "Arial" })],
    }),
    para(
      "The v4 campaign produced physically sound, globally converged shaft " +
      "designs for both the 10\u202fkW and 50\u202fkW Windswept kite turbine. " +
      "The key conclusions are as follows."
    ),
    para(
      "The constant L/r ring-spacing rule is the correct structural principle " +
      "for TRPT shaft design. By deriving ring positions from a geometric series " +
      "rather than an arbitrary parametric profile, every segment operates at " +
      "the same normalised slenderness, eliminating both structural waste and " +
      "the need to hand-tune the axial profile. The derived ring count of " +
      "approximately 19 is much higher than the 5 rings in v3, reflecting the " +
      "fundamental physics: a tapered shaft benefits from many thin rings " +
      "rather than few heavy ones."
    ),
    para(
      "Restoring taper freedom saved 31.4\u202f% of shaft mass relative to v3, " +
      "reducing the 10\u202fkW optimum from 15.435\u202fkg to 10.587\u202fkg. " +
      "This saving is robust across all 20 relevant v4 islands and cannot be " +
      "attributed to search noise. The v4 formulation is therefore " +
      "both structurally valid and practically lighter than v3."
    ),
    para(
      "Airfoil cross-sections are structurally disqualified for TRPT polygon " +
      "frames. The 6.7\u00d7 mass penalty at 10\u202fkW and 9.4\u00d7 at 50\u202fkW " +
      "arise from a fundamental geometric mismatch: airfoil profiles have " +
      "low buckling resistance in the minor-axis direction and high material " +
      "volume. Circular and elliptical thin-walled tubes are equivalent in mass " +
      "and should be the only families considered in future campaigns."
    ),
    para(
      "The 50\u202fkW shaft mass of 79.51\u202fkg implies a shaft-to-power ratio " +
      "of 1.59\u202fkg/kW, compared with 1.06\u202fkg/kW at 10\u202fkW. " +
      "The scaling penalty is modest and confirms that a 50\u202fkW " +
      "TRPT kite turbine is structurally viable."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "7.2 Next Steps: v5 Campaign Specification", font: "Arial" })],
    }),
    para(
      "The Phase K analysis identified three adjustments to the search space " +
      "that are warranted before the v5 campaign runs."
    ),
    para(
      "First, the n_lines question requires aerodynamic validation before the " +
      "search bound is simply raised. Every island hit the upper bound of 8, " +
      "suggesting the structural optimum lies at higher n_lines; however, " +
      "the v4 objective function treated power output as fixed regardless of n_lines. " +
      "In wind rotor theory, increasing blade or tether-line count raises rotor " +
      "solidity, reducing the power coefficient C_p and requiring a larger rotor " +
      "to achieve the same rated power \u2014 three-bladed turbines are the industry " +
      "standard precisely because of this trade-off. " +
      "The v5 campaign should incorporate a BEM-derived C_p(n_lines, TSR) curve " +
      "so that high-solidity configurations are correctly penalised through " +
      "increased rotor loads and structural mass. Until this coupling is " +
      "implemented, the n_lines result should be treated as a structural lower " +
      "bound on mass, not a definitive system optimum."
    ),
    para(
      "Second, the airfoil cross-section family should be excluded entirely. " +
      "This halves the island count needed to cover the beam-profile space " +
      "and allows the budget to be redirected to broader L/r and taper " +
      "exploration. A focused 30-island run (2 configs \u00d7 2 profiles \u00d7 " +
      "5 zones \u00d7 \u20131.5 seeds) would give the same statistical robustness " +
      "at half the compute cost."
    ),
    para(
      "Third, the upper bound on target_Lr should be raised from 2.0 to at " +
      "least 3.0. The consistent clustering at the upper boundary is a " +
      "clear signal that the optimum lies beyond the current search range. " +
      "Before doing so, it is worth verifying analytically that L/r\u202f>\u202f2.0 " +
      "remains compatible with the torsional stability criterion across the " +
      "full range of design loads."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "7.3 Logging and Analysis Improvements", font: "Arial" })],
    }),
    para(
      "The v4 campaign logged a binary torsion_ok flag rather than a scalar " +
      "torsional FOS per ring. This made it impossible to analyse convergence " +
      "of the torsional margin independently from beam buckling. The v5 " +
      "campaign logging should record the per-ring torsional compressive FOS " +
      "alongside the existing beam buckling FOS, enabling per-generation " +
      "convergence analysis of both constraints."
    ),
    new Paragraph({
      heading: HeadingLevel.HEADING_2,
      children: [new TextRun({ text: "7.4 Outstanding Validation Work", font: "Arial" })],
    }),
    para(
      "The optimiser results are quasi-static, simplified-load estimates. " +
      "The design load factor (DLF\u202f=\u202f1.2) and peak wind speed " +
      "(13\u202fm/s at 30\u00b0 elevation) are first-approximation assumptions. " +
      "Higher-fidelity finite element analysis (FEA) is required before " +
      "committing to fabrication dimensions. An original eight-document " +
      "structural validity review was deferred during the optimisation " +
      "phase and remains to be completed; it is now lower priority given " +
      "that the v4 formulation is physically well-founded, but it should " +
      "be addressed before the first physical prototype of the optimised shaft."
    ),
  ];
}

// ── Assemble document ─────────────────────────────────────────────────────────

const allChildren = [
  ...titleSection(),
  ...execSummary(),
  ...sectionBackground(),
  ...sectionFormulation(),
  ...sectionProgression(),
  ...sectionWinnerSpec(),
  ...sectionDesignSpace(),
  ...sectionConclusions(),
];

const doc = new Document({
  numbering: { config: [] },
  styles: {
    default: {
      document: { run: { font: "Arial", size: 22, color: DARK } },
    },
    paragraphStyles: [
      {
        id: "Heading1", name: "Heading 1",
        basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 36, bold: true, color: WS_BLUE, font: "Arial" },
        paragraph: {
          spacing: { before: 400, after: 80 },
          outlineLevel: 0,
        },
      },
      {
        id: "Heading2", name: "Heading 2",
        basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, color: DARK, font: "Arial" },
        paragraph: {
          spacing: { before: 280, after: 80 },
          outlineLevel: 1,
        },
      },
    ],
  },
  sections: [
    {
      properties: {
        page: {
          size: { width: PAGE_W, height: PAGE_H },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN },
        },
      },
      headers: {
        default: new Header({
          children: [
            new Paragraph({
              border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC", space: 1 } },
              tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
              children: [
                new TextRun({ text: "Windswept Energy \u2014 TRPT Structural Optimisation v2\u2013v4", size: 16, font: "Arial", color: MID_GREY }),
                new TextRun({ text: "\tApril 2026", size: 16, font: "Arial", color: MID_GREY }),
              ],
            }),
          ],
        }),
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              border: { top: { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC", space: 1 } },
              tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
              children: [
                new TextRun({ text: "CONFIDENTIAL \u2014 Windswept & Interesting Ltd", size: 16, font: "Arial", color: MID_GREY }),
                new TextRun({ text: "\tPage ", size: 16, font: "Arial", color: MID_GREY }),
                new TextRun({ children: [PageNumber.CURRENT], size: 16, font: "Arial", color: MID_GREY }),
              ],
            }),
          ],
        }),
      },
      children: allChildren,
    },
  ],
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(OUT, buf);
  console.log(`Written: ${OUT}`);
}).catch(err => {
  console.error("DOCX generation failed:", err);
  process.exit(1);
});
