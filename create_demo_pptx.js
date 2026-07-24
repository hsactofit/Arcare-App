/**
 * MediFit Wellness360 — Product Demo (premium redesign)
 */
const pptxgen = require("pptxgenjs");
const path = require("path");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");

const {
  FaRobot, FaShieldAlt, FaDumbbell, FaChartPie,
  FaTrophy, FaHeartbeat, FaCheck, FaBolt,
  FaMobileAlt, FaComments, FaMapMarkerAlt, FaUser,
  FaArrowRight, FaStar, FaLeaf, FaFire,
} = require("react-icons/fa");
const { MdEmergency, MdQrCodeScanner, MdSpa, MdTrendingUp } = require("react-icons/md");
const { HiSparkles } = require("react-icons/hi");

const SHOT = path.join(__dirname, "screenshots");
const img = (n) => path.join(SHOT, n);

// ── Palette ──────────────────────────────────────────────
const C = {
  ink: "0A1628",
  deep: "0D2137",
  teal: "0D9488",
  tealDark: "0F766E",
  mint: "2DD4BF",
  coral: "F43F5E",
  amber: "F59E0B",
  violet: "8B5CF6",
  sky: "0EA5E9",
  cream: "F8FAFC",
  white: "FFFFFF",
  soft: "F0FDFA",
  muted: "64748B",
  line: "E2E8F0",
  card: "FFFFFF",
  slate: "334155",
};

const shadowSoft = { type: "outer", color: "0A1628", blur: 18, offset: 4, angle: 140, opacity: 0.12 };
const shadowPhone = { type: "outer", color: "0A1628", blur: 28, offset: 10, angle: 160, opacity: 0.22 };

function renderIconSvg(Icon, color, size = 256) {
  return ReactDOMServer.renderToStaticMarkup(
    React.createElement(Icon, { color, size: String(size) })
  );
}

async function iconPng(Icon, color, size = 256) {
  const svg = renderIconSvg(Icon, color, size);
  const buf = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

function phone(slide, x, y, w, h, screenshot) {
  // Soft glow plate
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + 0.08, y: y + 0.1, w, h,
    fill: { color: "0D9488", transparency: 88 },
    rectRadius: 0.32,
  });
  // Bezel
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: "111827" },
    rectRadius: 0.32,
    shadow: shadowPhone,
  });
  // Inner screen
  const p = 0.09;
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + p, y: y + p, w: w - p * 2, h: h - p * 2,
    fill: { color: C.white },
    rectRadius: 0.24,
  });
  slide.addImage({
    path: screenshot,
    x: x + p + 0.02,
    y: y + p + 0.02,
    w: w - p * 2 - 0.04,
    h: h - p * 2 - 0.04,
  });
  // Notch
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + w / 2 - 0.35, y: y + 0.12, w: 0.7, h: 0.12,
    fill: { color: "111827" },
    rectRadius: 0.06,
  });
}

function pill(slide, text, x, y, bg, fg) {
  const w = Math.max(1.4, text.length * 0.11 + 0.5);
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h: 0.3,
    fill: { color: bg },
    rectRadius: 0.15,
  });
  slide.addText(text, {
    x, y, w, h: 0.3,
    fontSize: 10, fontFace: "Calibri", color: fg,
    bold: true, align: "center", valign: "middle", margin: 0, charSpacing: 1,
  });
}

function footer(slide, page, total, dark = false) {
  slide.addText(`MediFit Wellness360  ·  ${page}/${total}`, {
    x: 0.5, y: 5.3, w: 9, h: 0.25,
    fontSize: 10, fontFace: "Calibri",
    color: dark ? "5B7A85" : C.muted,
    margin: 0,
  });
}

let pres;

async function main() {
  pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.author = "MediFit";
  pres.title = "MediFit Wellness360 — Product Showcase";
  pres.subject = "Premium product demo with live device screenshots";

  const I = {
    robot: await iconPng(FaRobot, "#0D9488"),
    shield: await iconPng(FaShieldAlt, "#F43F5E"),
    dumbbell: await iconPng(FaDumbbell, "#0EA5E9"),
    chart: await iconPng(FaChartPie, "#8B5CF6"),
    trophy: await iconPng(FaTrophy, "#F59E0B"),
    heart: await iconPng(FaHeartbeat, "#F43F5E"),
    check: await iconPng(FaCheck, "#0D9488"),
    bolt: await iconPng(FaBolt, "#F59E0B"),
    mobile: await iconPng(FaMobileAlt, "#0D9488"),
    chat: await iconPng(FaComments, "#8B5CF6"),
    pin: await iconPng(FaMapMarkerAlt, "#0EA5E9"),
    user: await iconPng(FaUser, "#0D9488"),
    star: await iconPng(FaStar, "#F59E0B"),
    leaf: await iconPng(FaLeaf, "#0D9488"),
    fire: await iconPng(FaFire, "#F43F5E"),
    spark: await iconPng(HiSparkles, "#2DD4BF"),
    sos: await iconPng(MdEmergency, "#F43F5E"),
    qr: await iconPng(MdQrCodeScanner, "#0EA5E9"),
    spa: await iconPng(MdSpa, "#0D9488"),
    trend: await iconPng(MdTrendingUp, "#0D9488"),
    checkW: await iconPng(FaCheck, "#FFFFFF"),
    robotW: await iconPng(FaRobot, "#FFFFFF"),
    shieldW: await iconPng(FaShieldAlt, "#FFFFFF"),
    trophyW: await iconPng(FaTrophy, "#FFFFFF"),
  };

  const TOTAL = 12;

  // ═══════════════════════════════════════════════════════
  // 1. TITLE — cinematic
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    // Diagonal accent band
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 0.18, h: 5.625, fill: { color: C.teal },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 6.8, y: -1.8, w: 5, h: 5,
      fill: { color: C.teal, transparency: 82 },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 7.5, y: 3.2, w: 3.5, h: 3.5,
      fill: { color: C.violet, transparency: 88 },
    });

    s.addImage({ data: I.spark, x: 0.7, y: 1.05, w: 0.32, h: 0.32 });
    s.addText("PRODUCT SHOWCASE  ·  LIVE DEVICE CAPTURE", {
      x: 1.1, y: 1.08, w: 5, h: 0.3,
      fontSize: 11, fontFace: "Calibri", color: C.mint,
      bold: true, margin: 0, charSpacing: 1.5,
    });
    s.addText("Wellness that\nactually works\ntogether.", {
      x: 0.7, y: 1.55, w: 5.6, h: 2.0,
      fontSize: 38, fontFace: "Arial", color: C.white,
      bold: true, margin: 0,
    });
    s.addText(
      "AI coaching · SOS safety · Gym QR · Plans · Challenges\nOne app. Full health stack.",
      {
        x: 0.7, y: 3.7, w: 5.2, h: 0.7,
        fontSize: 14, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.7, y: 4.6, w: 2.2, h: 0.45,
      fill: { color: C.teal },
      rectRadius: 0.1,
    });
    s.addText("MediFit Wellness360", {
      x: 0.7, y: 4.6, w: 2.2, h: 0.45,
      fontSize: 12, fontFace: "Arial", color: C.white,
      bold: true, align: "center", valign: "middle", margin: 0,
    });

    phone(s, 6.7, 0.45, 2.75, 4.75, img("boot.png"));
  }

  // ═══════════════════════════════════════════════════════
  // 2. AGENDA / journey
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.08, fill: { color: C.teal },
    });
    s.addText("The experience journey", {
      x: 0.55, y: 0.35, w: 8, h: 0.45,
      fontSize: 28, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("From open → insight → action — designed as one continuous loop.", {
      x: 0.55, y: 0.85, w: 8.5, h: 0.3,
      fontSize: 14, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    const steps = [
      { n: "01", t: "Home", d: "Score & plans", icon: I.spa, c: C.teal },
      { n: "02", t: "AI Buddy", d: "Ask & log", icon: I.robot, c: C.violet },
      { n: "03", t: "Gym + SOS", d: "Real world", icon: I.qr, c: C.sky },
      { n: "04", t: "Challenges", d: "Stay hooked", icon: I.trophy, c: C.amber },
      { n: "05", t: "Progress", d: "See wins", icon: I.trend, c: C.coral },
    ];
    // Connecting line
    s.addShape(pres.shapes.RECTANGLE, {
      x: 1.15, y: 2.55, w: 7.7, h: 0.04,
      fill: { color: C.line },
    });
    steps.forEach((st, i) => {
      const x = 0.55 + i * 1.85;
      s.addShape(pres.shapes.OVAL, {
        x: x + 0.45, y: 2.3, w: 0.5, h: 0.5,
        fill: { color: st.c },
        shadow: shadowSoft,
      });
      s.addText(st.n, {
        x: x + 0.45, y: 2.3, w: 0.5, h: 0.5,
        fontSize: 11, fontFace: "Arial", color: C.white, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 3.15, w: 1.7, h: 1.55,
        fill: { color: C.white },
        rectRadius: 0.14,
        shadow: shadowSoft,
      });
      s.addImage({ data: st.icon, x: x + 0.6, y: 3.35, w: 0.42, h: 0.42 });
      s.addText(st.t, {
        x: x + 0.1, y: 3.9, w: 1.5, h: 0.3,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true,
        align: "center", margin: 0,
      });
      s.addText(st.d, {
        x: x + 0.1, y: 4.2, w: 1.5, h: 0.3,
        fontSize: 11, fontFace: "Calibri", color: C.muted,
        align: "center", margin: 0,
      });
    });
    footer(s, 2, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 3. WHAT MAKES IT BETTER — bento
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.08, fill: { color: C.teal },
    });
    s.addText("What makes it better", {
      x: 0.5, y: 0.28, w: 7, h: 0.4,
      fontSize: 26, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Six advantages most wellness apps never ship together.", {
      x: 0.5, y: 0.7, w: 8, h: 0.28,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    // Large feature card left
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.4, y: 1.15, w: 4.55, h: 3.85,
      fill: { color: C.deep },
      rectRadius: 0.18,
    });
    s.addImage({ data: I.robotW, x: 0.7, y: 1.45, w: 0.5, h: 0.5 });
    s.addText("AI that acts", {
      x: 0.7, y: 2.15, w: 3.9, h: 0.4,
      fontSize: 22, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "Not generic tips. The chatbot reads profile, goals, water, nutrition & workouts — then answers with context and can log health data from chat.",
      {
        x: 0.7, y: 2.65, w: 3.9, h: 1.3,
        fontSize: 13, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.7, y: 4.2, w: 2.4, h: 0.4,
      fill: { color: C.teal },
      rectRadius: 0.1,
    });
    s.addText("Health Chatbot API  →", {
      x: 0.7, y: 4.2, w: 2.4, h: 0.4,
      fontSize: 11, fontFace: "Arial", color: C.white, bold: true,
      align: "center", valign: "middle", margin: 0,
    });

    // Right bento grid 2x2
    const small = [
      { t: "SOS safety", d: "One-tap alert + emergency numbers", icon: I.shield, bg: "FFF1F2", ac: C.coral },
      { t: "Gym QR", d: "Check-in, timer, checkout logs", icon: I.qr, bg: "F0F9FF", ac: C.sky },
      { t: "Unified score", d: "Active · Sleep · Nutri · Mind", icon: I.chart, bg: "F5F3FF", ac: C.violet },
      { t: "Gamified goals", d: "Challenges, points, ranks", icon: I.trophy, bg: "FFFBEB", ac: C.amber },
    ];
    small.forEach((c, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 5.15 + col * 2.3;
      const y = 1.15 + row * 1.95;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y, w: 2.15, h: 1.8,
        fill: { color: C.white },
        rectRadius: 0.14,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.18, y: y + 0.22, w: 0.48, h: 0.48,
        fill: { color: c.bg },
        rectRadius: 0.12,
      });
      s.addImage({ data: c.icon, x: x + 0.27, y: y + 0.31, w: 0.3, h: 0.3 });
      s.addText(c.t, {
        x: x + 0.18, y: y + 0.85, w: 1.8, h: 0.3,
        fontSize: 14, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(c.d, {
        x: x + 0.18, y: y + 1.2, w: 1.8, h: 0.4,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 3, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 4. HOME — magazine layout
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    // Left dark panel
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 4.3, h: 5.625, fill: { color: C.deep },
    });
    pill(s, "HOME DASHBOARD", 0.45, 0.45, "134E4A", C.mint);
    s.addText("Your day,\nin one glance.", {
      x: 0.45, y: 1.0, w: 3.5, h: 1.2,
      fontSize: 28, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "Wellness score, active goals, SOS, gym, and today’s plans — no digging through tabs.",
      {
        x: 0.45, y: 2.35, w: 3.4, h: 0.9,
        fontSize: 13, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );

    const items = [
      "Ring score: Active · Sleep · Nutrition · Mind",
      "Active challenge progress card",
      "SOS + Gym quick actions",
      "Today’s workout & nutrition plans",
    ];
    items.forEach((t, i) => {
      const y = 3.4 + i * 0.42;
      s.addImage({ data: I.checkW, x: 0.5, y: y + 0.02, w: 0.22, h: 0.22 });
      s.addText(t, {
        x: 0.85, y, w: 3.1, h: 0.3,
        fontSize: 12, fontFace: "Calibri", color: "CBD5E1", margin: 0, valign: "middle",
      });
    });

    phone(s, 5.15, 0.35, 2.55, 4.9, img("ok_home.png"));
    phone(s, 7.55, 0.7, 2.15, 4.2, img("r8_home_lower.png"));
  }

  // ═══════════════════════════════════════════════════════
  // 5. AI BUDDY — hero
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    s.addShape(pres.shapes.OVAL, {
      x: -2, y: -2, w: 5, h: 5,
      fill: { color: C.violet, transparency: 88 },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 7, y: 3, w: 4, h: 4,
      fill: { color: C.teal, transparency: 85 },
    });

    phone(s, 0.5, 0.4, 2.7, 4.85, img("ok_ai.png"));

    s.addText("AI BUDDY", {
      x: 3.7, y: 0.7, w: 5.5, h: 0.3,
      fontSize: 12, fontFace: "Calibri", color: C.mint,
      bold: true, margin: 0, charSpacing: 2,
    });
    s.addText("A coach that\nalready knows you.", {
      x: 3.7, y: 1.1, w: 5.6, h: 1.15,
      fontSize: 30, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });

    const aiCards = [
      { icon: I.chat, t: "Context-aware", d: "Uses real health + goals in every reply" },
      { icon: I.bolt, t: "Actionable chat", d: "Log water, steps, nutrition from messages" },
      { icon: I.star, t: "Memory", d: "Conversation history across sessions" },
    ];
    aiCards.forEach((c, i) => {
      const y = 2.5 + i * 0.85;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 3.7, y, w: 5.6, h: 0.75,
        fill: { color: "12263A" },
        rectRadius: 0.12,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 3.9, y: y + 0.15, w: 0.45, h: 0.45,
        fill: { color: "1E3A4C" },
        rectRadius: 0.1,
      });
      s.addImage({ data: c.icon, x: 3.98, y: y + 0.23, w: 0.28, h: 0.28 });
      s.addText(c.t, {
        x: 4.55, y: y + 0.1, w: 4.5, h: 0.28,
        fontSize: 14, fontFace: "Arial", color: C.white, bold: true, margin: 0,
      });
      s.addText(c.d, {
        x: 4.55, y: y + 0.38, w: 4.5, h: 0.28,
        fontSize: 12, fontFace: "Calibri", color: "94A3B8", margin: 0,
      });
    });
  }

  // ═══════════════════════════════════════════════════════
  // 6. CHALLENGES + PROGRESS split
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });

    // Left half
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.3, y: 0.3, w: 4.6, h: 5.05,
      fill: { color: C.white },
      rectRadius: 0.16,
      shadow: shadowSoft,
    });
    pill(s, "CHALLENGES", 0.55, 0.5, "FFFBEB", C.amber);
    s.addText("Make habits\ncompetitive.", {
      x: 0.55, y: 0.95, w: 2.2, h: 0.9,
      fontSize: 20, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Points, progress bars, rewards — Gym Check-in at 40%.", {
      x: 0.55, y: 1.95, w: 2.15, h: 0.7,
      fontSize: 12, fontFace: "Calibri", color: C.muted, margin: 0,
    });
    phone(s, 2.7, 0.85, 2.0, 4.15, img("ok_challenges.png"));

    // Right half
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 5.1, y: 0.3, w: 4.6, h: 5.05,
      fill: { color: C.white },
      rectRadius: 0.16,
      shadow: shadowSoft,
    });
    pill(s, "PROGRESS", 5.35, 0.5, "F0FDFA", C.teal);
    s.addText("Trends that\nshow momentum.", {
      x: 5.35, y: 0.95, w: 2.2, h: 0.9,
      fontSize: 20, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Daily / Weekly / Monthly graphs for steps, kcal, sleep, water.", {
      x: 5.35, y: 1.95, w: 2.15, h: 0.7,
      fontSize: 12, fontFace: "Calibri", color: C.muted, margin: 0,
    });
    phone(s, 7.5, 0.85, 2.0, 4.15, img("try_pr.png"));
  }

  // ═══════════════════════════════════════════════════════
  // 7. SOS + GYM — dual feature
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 5, h: 5.625, fill: { color: "1C0A0E" },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 5, y: 0, w: 5, h: 5.625, fill: { color: "071520" },
    });

    // SOS side
    s.addImage({ data: I.sos, x: 0.45, y: 0.4, w: 0.4, h: 0.4 });
    s.addText("SAFETY", {
      x: 0.95, y: 0.48, w: 2, h: 0.28,
      fontSize: 11, fontFace: "Calibri", color: C.coral, bold: true, margin: 0, charSpacing: 2,
    });
    s.addText("Help in\none tap.", {
      x: 0.45, y: 0.95, w: 2.3, h: 1.0,
      fontSize: 26, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText("Alert contacts · Police · Ambulance · Fire · Manage emergency list", {
      x: 0.45, y: 2.1, w: 2.2, h: 0.9,
      fontSize: 12, fontFace: "Calibri", color: "FCA5A5", margin: 0,
    });
    phone(s, 2.65, 0.55, 2.15, 4.55, img("r6_sos.png"));

    // Gym side
    s.addImage({ data: I.qr, x: 5.4, y: 0.4, w: 0.4, h: 0.4 });
    s.addText("GYM", {
      x: 5.9, y: 0.48, w: 2, h: 0.28,
      fontSize: 11, fontFace: "Calibri", color: C.sky, bold: true, margin: 0, charSpacing: 2,
    });
    s.addText("Scan.\nTrain.\nLog.", {
      x: 5.4, y: 0.95, w: 2.3, h: 1.35,
      fontSize: 26, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText("Partner gym QR · Live duration · Checkout with exercises & sets", {
      x: 5.4, y: 2.45, w: 2.2, h: 0.9,
      fontSize: 12, fontFace: "Calibri", color: "7DD3FC", margin: 0,
    });
    phone(s, 7.6, 0.55, 2.15, 4.55, img("r7_gym.png"));
  }

  // ═══════════════════════════════════════════════════════
  // 8. PLANS + INSIGHTS
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.08, fill: { color: C.violet },
    });
    s.addText("Plans + deep insights", {
      x: 0.5, y: 0.3, w: 6, h: 0.4,
      fontSize: 26, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("AI-generated plans meet metric-level coaching.", {
      x: 0.5, y: 0.75, w: 8, h: 0.28,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    // Two feature rows with phones
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.4, y: 1.2, w: 4.5, h: 3.95,
      fill: { color: C.white },
      rectRadius: 0.16,
      shadow: shadowSoft,
    });
    s.addImage({ data: I.dumbbell, x: 0.65, y: 1.45, w: 0.35, h: 0.35 });
    s.addText("Workout Plans", {
      x: 1.15, y: 1.48, w: 2.5, h: 0.32,
      fontSize: 16, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Day schedule · sets · rest · muscle tags · Create with AI", {
      x: 0.65, y: 1.95, w: 2.0, h: 0.9,
      fontSize: 12, fontFace: "Calibri", color: C.muted, margin: 0,
    });
    phone(s, 2.7, 1.55, 2.0, 3.35, img("r9_workout.png"));

    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 5.1, y: 1.2, w: 4.5, h: 3.95,
      fill: { color: C.white },
      rectRadius: 0.16,
      shadow: shadowSoft,
    });
    s.addImage({ data: I.heart, x: 5.35, y: 1.45, w: 0.35, h: 0.35 });
    s.addText("Metric deep-dive", {
      x: 5.85, y: 1.48, w: 2.5, h: 0.32,
      fontSize: 16, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Trends · history · live AI Wellness Buddy on every metric", {
      x: 5.35, y: 1.95, w: 2.0, h: 0.9,
      fontSize: 12, fontFace: "Calibri", color: C.muted, margin: 0,
    });
    phone(s, 7.4, 1.55, 2.0, 3.35, img("r10_nutrition.png"));
  }

  // ═══════════════════════════════════════════════════════
  // 9. PROFILE
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });

    phone(s, 0.55, 0.4, 2.7, 4.85, img("try_pf.png"));

    s.addText("PROFILE", {
      x: 3.8, y: 0.7, w: 5, h: 0.28,
      fontSize: 11, fontFace: "Calibri", color: C.teal, bold: true, margin: 0, charSpacing: 2,
    });
    s.addText("Identity that\npowers the AI.", {
      x: 3.8, y: 1.1, w: 5.5, h: 1.1,
      fontSize: 30, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText(
      "Weight, height, BMI, goals, and Health Connect preferences feed the coach, plans, and wellness score.",
      {
        x: 3.8, y: 2.35, w: 5.3, h: 0.7,
        fontSize: 14, fontFace: "Calibri", color: C.muted, margin: 0,
      }
    );

    const stats = [
      { v: "24.7", l: "BMI · Normal", c: C.teal },
      { v: "80kg", l: "Weight", c: C.sky },
      { v: "180cm", l: "Height", c: C.violet },
    ];
    stats.forEach((st, i) => {
      const x = 3.8 + i * 1.9;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 3.3, w: 1.75, h: 1.35,
        fill: { color: C.white },
        rectRadius: 0.14,
        shadow: shadowSoft,
      });
      s.addText(st.v, {
        x, y: 3.5, w: 1.75, h: 0.55,
        fontSize: 24, fontFace: "Arial", color: st.c, bold: true,
        align: "center", margin: 0,
      });
      s.addText(st.l, {
        x: x + 0.1, y: 4.15, w: 1.55, h: 0.3,
        fontSize: 12, fontFace: "Calibri", color: C.muted,
        align: "center", margin: 0,
      });
    });
  }

  // ═══════════════════════════════════════════════════════
  // 10. COMPARISON — cleaner
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.08, fill: { color: C.teal },
    });
    s.addText("Why MediFit wins", {
      x: 0.5, y: 0.3, w: 8, h: 0.4,
      fontSize: 26, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Against single-purpose fitness apps", {
      x: 0.5, y: 0.75, w: 8, h: 0.28,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    // Header row
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.45, y: 1.2, w: 9.1, h: 0.5,
      fill: { color: C.deep },
      rectRadius: 0.08,
    });
    s.addText("Capability", {
      x: 0.65, y: 1.2, w: 3.2, h: 0.5,
      fontSize: 12, fontFace: "Arial", color: C.white, bold: true, valign: "middle", margin: 0,
    });
    s.addText("Typical apps", {
      x: 4.0, y: 1.2, w: 2.5, h: 0.5,
      fontSize: 12, fontFace: "Arial", color: "94A3B8", bold: true, valign: "middle", margin: 0,
    });
    s.addText("MediFit", {
      x: 6.7, y: 1.2, w: 2.6, h: 0.5,
      fontSize: 12, fontFace: "Arial", color: C.mint, bold: true, valign: "middle", margin: 0,
    });

    const rows = [
      ["AI coach with your data", "Generic tips", "Context + can log for you"],
      ["Emergency SOS", "Rare / none", "Contacts + 100 / 102 / 101"],
      ["Gym QR sessions", "Manual only", "Check-in → timer → log"],
      ["Workout + nutrition plans", "Usually one", "Both · AI-generated"],
      ["Challenges & points", "Social only", "Progress-linked rewards"],
      ["Unified wellness score", "Fragmented metrics", "4 pillars · one ring"],
    ];
    rows.forEach((r, i) => {
      const y = 1.8 + i * 0.52;
      if (i % 2 === 0) {
        s.addShape(pres.shapes.RECTANGLE, {
          x: 0.45, y, w: 9.1, h: 0.52,
          fill: { color: C.soft },
        });
      }
      s.addText(r[0], {
        x: 0.65, y, w: 3.2, h: 0.52,
        fontSize: 12, fontFace: "Calibri", color: C.ink, bold: true, valign: "middle", margin: 0,
      });
      s.addText(r[1], {
        x: 4.0, y, w: 2.5, h: 0.52,
        fontSize: 12, fontFace: "Calibri", color: C.muted, valign: "middle", margin: 0,
      });
      s.addImage({ data: I.check, x: 6.7, y: y + 0.14, w: 0.22, h: 0.22 });
      s.addText(r[2], {
        x: 7.05, y, w: 2.3, h: 0.52,
        fontSize: 12, fontFace: "Calibri", color: C.tealDark, bold: true, valign: "middle", margin: 0,
      });
    });
  }

  // ═══════════════════════════════════════════════════════
  // 11. SCREEN GALLERY
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    s.addText("The app, on device", {
      x: 0.5, y: 0.25, w: 9, h: 0.4,
      fontSize: 24, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText("Real screenshots from USB debugging — not mockups.", {
      x: 0.5, y: 0.65, w: 9, h: 0.28,
      fontSize: 12, fontFace: "Calibri", color: "64748B", margin: 0,
    });

    const gallery = [
      { f: "ok_home.png", l: "Home" },
      { f: "ok_ai.png", l: "AI Buddy" },
      { f: "ok_challenges.png", l: "Challenges" },
      { f: "try_pr.png", l: "Progress" },
      { f: "r6_sos.png", l: "SOS" },
      { f: "try_pf.png", l: "Profile" },
    ];
    gallery.forEach((g, i) => {
      const x = 0.35 + i * 1.6;
      // mini phone
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 1.15, w: 1.48, h: 3.55,
        fill: { color: "111827" },
        rectRadius: 0.18,
        shadow: shadowPhone,
      });
      s.addImage({
        path: img(g.f),
        x: x + 0.06, y: 1.21, w: 1.36, h: 3.43,
      });
      s.addText(g.l, {
        x, y: 4.85, w: 1.48, h: 0.3,
        fontSize: 11, fontFace: "Arial", color: C.mint, bold: true,
        align: "center", margin: 0,
      });
    });
  }

  // ═══════════════════════════════════════════════════════
  // 12. CLOSING
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 0.18, h: 5.625, fill: { color: C.mint },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 6, y: -2, w: 6, h: 6,
      fill: { color: C.teal, transparency: 85 },
    });

    s.addImage({ data: I.spark, x: 0.7, y: 1.4, w: 0.4, h: 0.4 });
    s.addText("Optimize. Sync. Thrive.", {
      x: 0.7, y: 2.0, w: 8.5, h: 0.7,
      fontSize: 36, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "MediFit Wellness360 unifies coaching, safety, gym, plans, and progress\ninto one polished product — proven on a real device.",
      {
        x: 0.7, y: 2.85, w: 8, h: 0.75,
        fontSize: 15, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );

    const tags = ["AI Coach", "SOS", "Gym QR", "Plans", "Challenges", "Trends"];
    tags.forEach((t, i) => {
      const x = 0.7 + i * 1.45;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 3.9, w: 1.35, h: 0.4,
        fill: { color: "1E293B" },
        rectRadius: 0.1,
      });
      s.addText(t, {
        x, y: 3.9, w: 1.35, h: 0.4,
        fontSize: 11, fontFace: "Calibri", color: C.mint, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
    });

    s.addText("Secure · HIPAA-aligned  ·  Live USB capture  ·  July 2026", {
      x: 0.7, y: 5.05, w: 8, h: 0.25,
      fontSize: 11, fontFace: "Calibri", color: "475569", margin: 0,
    });
  }

  const out = path.join(__dirname, "MediFit_Wellness360_Demo.pptx");
  await pres.writeFile({ fileName: out });
  console.log("Wrote", out);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
