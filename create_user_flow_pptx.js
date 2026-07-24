/**
 * MediFit Wellness360 — User Flow (from app demo video)
 * Based on medifit_wellness.mp4 walkthrough
 */
const pptxgen = require("pptxgenjs");
const path = require("path");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");

const {
  FaRobot, FaShieldAlt, FaDumbbell, FaChartPie,
  FaTrophy, FaHeartbeat, FaCheck, FaBolt,
  FaMobileAlt, FaUser, FaArrowRight, FaTint,
  FaUtensils, FaWalking, FaBell, FaHome,
} = require("react-icons/fa");
const { MdEmergency, MdQrCodeScanner, MdSpa, MdTrendingUp } = require("react-icons/md");
const { HiSparkles } = require("react-icons/hi");

const SHOT = path.join(__dirname, "screenshots", "flow_shots");
const img = (n) => path.join(SHOT, n);

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
  slate: "334155",
  orange: "F97316",
};

const shadowSoft = { type: "outer", color: "0A1628", blur: 16, offset: 4, angle: 140, opacity: 0.12 };
const shadowPhone = { type: "outer", color: "0A1628", blur: 24, offset: 8, angle: 160, opacity: 0.2 };

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

function phone(slide, x, y, w, h, screenshot, pres) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + 0.06, y: y + 0.08, w, h,
    fill: { color: "0D9488", transparency: 88 },
    rectRadius: 0.28,
  });
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: "111827" },
    rectRadius: 0.28,
    shadow: shadowPhone,
  });
  const p = 0.08;
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + p, y: y + p, w: w - p * 2, h: h - p * 2,
    fill: { color: C.white },
    rectRadius: 0.22,
  });
  slide.addImage({
    path: screenshot,
    x: x + p + 0.015,
    y: y + p + 0.015,
    w: w - p * 2 - 0.03,
    h: h - p * 2 - 0.03,
  });
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x + w / 2 - 0.28, y: y + 0.1, w: 0.56, h: 0.1,
    fill: { color: "111827" },
    rectRadius: 0.05,
  });
}

function pill(slide, text, x, y, bg, fg, pres) {
  const w = Math.max(1.5, text.length * 0.1 + 0.55);
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h: 0.28,
    fill: { color: bg },
    rectRadius: 0.14,
  });
  slide.addText(text, {
    x, y, w, h: 0.28,
    fontSize: 10, fontFace: "Calibri", color: fg,
    bold: true, align: "center", valign: "middle", margin: 0, charSpacing: 0.8,
  });
}

function footer(slide, page, total) {
  slide.addText(`MediFit Wellness360  ·  User Flow  ·  ${page}/${total}`, {
    x: 0.45, y: 5.32, w: 9.1, h: 0.22,
    fontSize: 10, fontFace: "Calibri", color: C.muted, margin: 0,
  });
}

function sectionHeader(slide, title, subtitle, pres) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
  });
  slide.addShape(pres.shapes.RECTANGLE, {
    x: 0, y: 0, w: 10, h: 0.07, fill: { color: C.teal },
  });
  slide.addText(title, {
    x: 0.5, y: 0.28, w: 9, h: 0.4,
    fontSize: 24, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.5, y: 0.7, w: 9, h: 0.28,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });
  }
}

function flowStepCard(slide, x, y, w, h, n, title, desc, accent, pres) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: C.white },
    rectRadius: 0.12,
    shadow: shadowSoft,
  });
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w: 0.08, h,
    fill: { color: accent },
    rectRadius: 0.04,
  });
  slide.addShape(pres.shapes.OVAL, {
    x: x + 0.22, y: y + 0.18, w: 0.36, h: 0.36,
    fill: { color: accent },
  });
  slide.addText(String(n), {
    x: x + 0.22, y: y + 0.18, w: 0.36, h: 0.36,
    fontSize: 12, fontFace: "Arial", color: C.white, bold: true,
    align: "center", valign: "middle", margin: 0,
  });
  slide.addText(title, {
    x: x + 0.7, y: y + 0.18, w: w - 0.9, h: 0.32,
    fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0, valign: "middle",
  });
  slide.addText(desc, {
    x: x + 0.22, y: y + 0.58, w: w - 0.4, h: h - 0.72,
    fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
  });
}

let pres;

async function main() {
  pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.author = "MediFit";
  pres.title = "MediFit Wellness360 — User Flow";
  pres.subject = "End-to-end user journey from app demo video";

  const I = {
    robot: await iconPng(FaRobot, "#0D9488"),
    shield: await iconPng(FaShieldAlt, "#F43F5E"),
    dumbbell: await iconPng(FaDumbbell, "#0EA5E9"),
    chart: await iconPng(FaChartPie, "#8B5CF6"),
    trophy: await iconPng(FaTrophy, "#F59E0B"),
    heart: await iconPng(FaHeartbeat, "#F43F5E"),
    check: await iconPng(FaCheck, "#0D9488"),
    checkW: await iconPng(FaCheck, "#FFFFFF"),
    bolt: await iconPng(FaBolt, "#F59E0B"),
    mobile: await iconPng(FaMobileAlt, "#0D9488"),
    user: await iconPng(FaUser, "#0D9488"),
    spark: await iconPng(HiSparkles, "#2DD4BF"),
    sos: await iconPng(MdEmergency, "#F43F5E"),
    qr: await iconPng(MdQrCodeScanner, "#0EA5E9"),
    spa: await iconPng(MdSpa, "#0D9488"),
    trend: await iconPng(MdTrendingUp, "#0D9488"),
    water: await iconPng(FaTint, "#0EA5E9"),
    food: await iconPng(FaUtensils, "#F97316"),
    walk: await iconPng(FaWalking, "#0D9488"),
    bell: await iconPng(FaBell, "#8B5CF6"),
    home: await iconPng(FaHome, "#0D9488"),
    arrow: await iconPng(FaArrowRight, "#0D9488"),
  };

  const TOTAL = 15;

  // ═══════════════════════════════════════════════════════
  // 1. TITLE
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 0.16, h: 5.625, fill: { color: C.teal },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 6.6, y: -1.6, w: 5, h: 5,
      fill: { color: C.teal, transparency: 82 },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 7.4, y: 3.4, w: 3.2, h: 3.2,
      fill: { color: C.violet, transparency: 88 },
    });

    s.addImage({ data: I.spark, x: 0.65, y: 1.0, w: 0.3, h: 0.3 });
    s.addText("USER FLOW  ·  FROM APP DEMO VIDEO", {
      x: 1.05, y: 1.02, w: 5.5, h: 0.28,
      fontSize: 11, fontFace: "Calibri", color: C.mint,
      bold: true, margin: 0, charSpacing: 1.2,
    });
    s.addText("How a user\nmoves through\nMediFit.", {
      x: 0.65, y: 1.5, w: 5.5, h: 1.9,
      fontSize: 36, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "Sign up → Home → SOS & Gym → Plans → Log health\n→ AI Buddy chat → Challenges → Progress → Profile",
      {
        x: 0.65, y: 3.6, w: 5.4, h: 0.65,
        fontSize: 13, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.65, y: 4.5, w: 2.35, h: 0.42,
      fill: { color: C.teal },
      rectRadius: 0.1,
    });
    s.addText("MediFit Wellness360", {
      x: 0.65, y: 4.5, w: 2.35, h: 0.42,
      fontSize: 12, fontFace: "Arial", color: C.white,
      bold: true, align: "center", valign: "middle", margin: 0,
    });

    phone(s, 6.85, 0.5, 2.55, 4.65, img("02_home.jpg"), pres);
  }

  // ═══════════════════════════════════════════════════════
  // 2. JOURNEY MAP
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "End-to-end journey map",
      "Primary path from the demo video, plus AI Buddy chat — log data, health updates, and Q&A.",
      pres
    );

    const steps = [
      { n: "01", t: "Auth", d: "Create account\nor social login", c: C.teal },
      { n: "02", t: "Home", d: "Score, goals,\nplans hub", c: C.sky },
      { n: "03", t: "Safety", d: "SOS + gym\nQR check-in", c: C.coral },
      { n: "04", t: "Plans", d: "Workout &\nnutrition AI", c: C.violet },
      { n: "05", t: "Log", d: "Water, food,\nmetrics", c: C.orange },
      { n: "06", t: "AI Chat", d: "Log data &\nhealth Q&A", c: C.violet },
      { n: "07", t: "Engage", d: "Challenges &\nprogress", c: C.amber },
      { n: "08", t: "Profile", d: "Identity &\npreferences", c: C.tealDark },
    ];

    s.addShape(pres.shapes.RECTANGLE, {
      x: 0.55, y: 2.35, w: 8.9, h: 0.035,
      fill: { color: C.line },
    });

    steps.forEach((st, i) => {
      const x = 0.35 + i * 1.2;
      s.addShape(pres.shapes.OVAL, {
        x: x + 0.3, y: 2.15, w: 0.4, h: 0.4,
        fill: { color: st.c },
        shadow: shadowSoft,
      });
      s.addText(st.n, {
        x: x + 0.3, y: 2.15, w: 0.4, h: 0.4,
        fontSize: 9, fontFace: "Arial", color: C.white, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 2.85, w: 1.12, h: 1.85,
        fill: { color: C.white },
        rectRadius: 0.12,
        shadow: shadowSoft,
      });
      s.addText(st.t, {
        x: x + 0.05, y: 3.05, w: 1.02, h: 0.35,
        fontSize: 12, fontFace: "Arial", color: C.ink, bold: true,
        align: "center", margin: 0,
      });
      s.addText(st.d, {
        x: x + 0.05, y: 3.45, w: 1.02, h: 1.0,
        fontSize: 10, fontFace: "Calibri", color: C.muted,
        align: "center", margin: 0,
      });
    });

    footer(s, 2, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 3. AUTH
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 4.35, h: 5.625, fill: { color: C.deep },
    });
    pill(s, "STEP 01  ·  AUTH", 0.45, 0.45, "134E4A", C.mint, pres);
    s.addText("Create account\n& enter the app.", {
      x: 0.45, y: 1.0, w: 3.6, h: 1.1,
      fontSize: 26, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "Demo opens on Create Account. User can also use Google or Apple, then land on Home.",
      {
        x: 0.45, y: 2.3, w: 3.5, h: 0.75,
        fontSize: 13, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );

    const bullets = [
      "Full name, email, password",
      "Terms & privacy acceptance",
      "Google / Apple social signup",
      "Existing users → Log In",
    ];
    bullets.forEach((t, i) => {
      const y = 3.25 + i * 0.42;
      s.addImage({ data: I.checkW, x: 0.5, y: y + 0.02, w: 0.2, h: 0.2 });
      s.addText(t, {
        x: 0.82, y, w: 3.2, h: 0.28,
        fontSize: 12, fontFace: "Calibri", color: "CBD5E1", margin: 0, valign: "middle",
      });
    });

    phone(s, 5.6, 0.4, 2.65, 4.85, img("01_signup.jpg"), pres);

    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 8.5, y: 2.0, w: 1.2, h: 1.6,
      fill: { color: C.white },
      rectRadius: 0.12,
      shadow: shadowSoft,
    });
    s.addText("Next", {
      x: 8.55, y: 2.25, w: 1.1, h: 0.25,
      fontSize: 11, fontFace: "Calibri", color: C.muted, align: "center", margin: 0,
    });
    s.addText("Home\nDashboard", {
      x: 8.55, y: 2.55, w: 1.1, h: 0.7,
      fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, align: "center", margin: 0,
    });
    footer(s, 3, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 4. HOME HUB
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "02  ·  Home — daily command center",
      "Everything starts here: wellness score, quick actions, today’s plans, bottom nav.",
      pres
    );

    phone(s, 0.45, 1.15, 2.2, 4.0, img("02_home.jpg"), pres);

    const cards = [
      { t: "SOS & Gym tiles", d: "One-tap emergency and gym QR entry from the top of Home.", icon: I.sos, ac: C.coral },
      { t: "Daily Wellness Score", d: "Ring score 0–100 across Active, Sleep, Nutrition, Mind.", icon: I.chart, ac: C.violet },
      { t: "Today’s Plans", d: "Workout plan card + Nutrition plan card with open / start.", icon: I.dumbbell, ac: C.sky },
      { t: "Bottom navigation", d: "Home · Challenges · AI Buddy chat · Progress · Profile.", icon: I.home, ac: C.teal },
    ];
    cards.forEach((c, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 3.0 + col * 3.35;
      const y = 1.2 + row * 1.85;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y, w: 3.15, h: 1.7,
        fill: { color: C.white },
        rectRadius: 0.14,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.2, y: y + 0.25, w: 0.45, h: 0.45,
        fill: { color: C.soft },
        rectRadius: 0.1,
      });
      s.addImage({ data: c.icon, x: x + 0.28, y: y + 0.33, w: 0.28, h: 0.28 });
      s.addText(c.t, {
        x: x + 0.2, y: y + 0.85, w: 2.75, h: 0.3,
        fontSize: 14, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(c.d, {
        x: x + 0.2, y: y + 1.15, w: 2.75, h: 0.4,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 4, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 5. SOS
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.07, fill: { color: C.coral },
    });

    pill(s, "STEP 03A  ·  SAFETY", 0.5, 0.3, "FEE2E2", C.coral, pres);
    s.addText("SOS Emergency flow", {
      x: 0.5, y: 0.7, w: 5.5, h: 0.4,
      fontSize: 24, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Home → SOS tile → one-tap alert + services + contacts.", {
      x: 0.5, y: 1.15, w: 5.5, h: 0.3,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    const items = [
      { n: "1", t: "Large SOS button", d: "Tap to alert emergency contacts" },
      { n: "2", t: "Emergency services", d: "Police 100 · Ambulance 102 · Fire 101" },
      { n: "3", t: "Personal contacts", d: "Add / call saved emergency people" },
      { n: "4", t: "Confirm feedback", d: "Toast confirms numbers updated" },
    ];
    items.forEach((it, i) => {
      const y = 1.65 + i * 0.75;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 0.5, y, w: 5.4, h: 0.65,
        fill: { color: C.white },
        rectRadius: 0.1,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.OVAL, {
        x: 0.7, y: y + 0.14, w: 0.38, h: 0.38,
        fill: { color: C.coral },
      });
      s.addText(it.n, {
        x: 0.7, y: y + 0.14, w: 0.38, h: 0.38,
        fontSize: 12, fontFace: "Arial", color: C.white, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      s.addText(it.t, {
        x: 1.25, y: y + 0.08, w: 4.4, h: 0.28,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(it.d, {
        x: 1.25, y: y + 0.34, w: 4.4, h: 0.24,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });

    phone(s, 6.7, 0.55, 2.7, 4.85, img("03_sos.jpg"), pres);
    footer(s, 5, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 6. GYM CHECK-IN
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "03B  ·  Gym QR check-in & checkout",
      "Home → Gym → scan QR → live timer → log exercises → checkout.",
      pres
    );

    phone(s, 0.4, 1.2, 2.05, 3.75, img("04_gym.jpg"), pres);
    phone(s, 2.65, 1.2, 2.05, 3.75, img("16_gym_checkout.jpg"), pres);

    const flow = [
      { t: "Scan partner gym QR", d: "JSON preferred: name + place" },
      { t: "Active session timer", d: "Duration + gym name shown" },
      { t: "Home shows GYM ACTIVE", d: "Live countdown tile on dashboard" },
      { t: "Checkout & log", d: "Add exercises/sets → Checkout & Log" },
    ];
    flow.forEach((f, i) => {
      const y = 1.25 + i * 0.9;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 5.05, y, w: 4.5, h: 0.78,
        fill: { color: C.white },
        rectRadius: 0.12,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.OVAL, {
        x: 5.25, y: y + 0.18, w: 0.42, h: 0.42,
        fill: { color: C.sky },
      });
      s.addText(String(i + 1), {
        x: 5.25, y: y + 0.18, w: 0.42, h: 0.42,
        fontSize: 13, fontFace: "Arial", color: C.white, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      s.addText(f.t, {
        x: 5.85, y: y + 0.12, w: 3.5, h: 0.28,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(f.d, {
        x: 5.85, y: y + 0.4, w: 3.5, h: 0.28,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 6, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 7. WORKOUT PLAN
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "04A  ·  Create workout plan (AI)",
      "Home → Workout card → Create plan → 4-step wizard → generated Strength plan.",
      pres
    );

    phone(s, 0.4, 1.2, 2.1, 3.8, img("06_create_plan.jpg"), pres);
    phone(s, 2.7, 1.2, 2.1, 3.8, img("07_plan_detail.jpg"), pres);

    const steps = [
      { n: "1–2", t: "Goal & setup", d: "Primary goal e.g. Build muscle; intensity & duration." },
      { n: "3–4", t: "Final touches", d: "Plan title (e.g. Strength), notes, generate." },
      { n: "AI", t: "Crafting plan…", d: "Backend builds day-by-day workouts." },
      { n: "Done", t: "Strength plan", d: "Exercises, sets, muscle tags, instructions." },
    ];
    steps.forEach((st, i) => {
      const y = 1.2 + i * 0.9;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 5.15, y, w: 4.4, h: 0.8,
        fill: { color: C.white },
        rectRadius: 0.12,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 5.3, y: y + 0.18, w: 0.7, h: 0.44,
        fill: { color: "E0F2FE" },
        rectRadius: 0.08,
      });
      s.addText(st.n, {
        x: 5.3, y: y + 0.18, w: 0.7, h: 0.44,
        fontSize: 11, fontFace: "Arial", color: C.sky, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      s.addText(st.t, {
        x: 6.15, y: y + 0.12, w: 3.2, h: 0.28,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(st.d, {
        x: 6.15, y: y + 0.42, w: 3.2, h: 0.3,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 7, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 8. NUTRITION + WATER
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "04B–05  ·  Nutrition plans, food log & hydration",
      "Meals from AI plans, quick food logging, and water tracker with cup / bottle / flask.",
      pres
    );

    const trio = [
      { shot: "08_nutrition_plans.jpg", t: "Nutrition Plans", d: "AI Veg Plan, meal macros, create new plan" },
      { shot: "11_nutrition_log.jpg", t: "Food logging", d: "Quick-add foods + custom entries + trends" },
      { shot: "10_water.jpg", t: "Hydration", d: "Visual bottle, +250/+500/+750 ml, history" },
    ];
    trio.forEach((c, i) => {
      const x = 0.4 + i * 3.15;
      phone(s, x + 0.35, 1.15, 1.85, 3.35, img(c.shot), pres);
      s.addText(c.t, {
        x, y: 4.6, w: 3.0, h: 0.28,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, align: "center", margin: 0,
      });
      s.addText(c.d, {
        x, y: 4.88, w: 3.0, h: 0.28,
        fontSize: 11, fontFace: "Calibri", color: C.muted, align: "center", margin: 0,
      });
    });
    footer(s, 8, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 9. METRIC DETAIL
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.07, fill: { color: C.amber },
    });
    pill(s, "STEP 05  ·  INSIGHTS", 0.5, 0.3, "FEF3C7", "B45309", pres);
    s.addText("Metric deep-dives", {
      x: 0.5, y: 0.7, w: 5, h: 0.4,
      fontSize: 24, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText("Steps & calories open historical analysis with AI Wellness Buddy tips.", {
      x: 0.5, y: 1.15, w: 5.2, h: 0.4,
      fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
    });

    flowStepCard(s, 0.5, 1.7, 5.3, 1.0, "1", "Steps detail", "Daily history, below-target flags, AI walking advice.", C.teal, pres);
    flowStepCard(s, 0.5, 2.9, 5.3, 1.0, "2", "Calories detail", "Period + combined burn, activity trend chart.", C.orange, pres);
    flowStepCard(s, 0.5, 4.1, 5.3, 0.9, "3", "AI Buddy insight", "Inline card: personal tip based on averages.", C.violet, pres);

    phone(s, 6.5, 0.7, 2.75, 4.5, img("17_calories.jpg"), pres);
    footer(s, 9, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 10. AI BUDDY CHAT
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.07, fill: { color: C.violet },
    });

    pill(s, "STEP 06  ·  AI BUDDY", 0.45, 0.28, "EDE9FE", C.violet, pres);
    s.addText("Chat that acts on your health.", {
      x: 0.45, y: 0.68, w: 6.2, h: 0.4,
      fontSize: 24, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
    });
    s.addText(
      "Center tab loads AI Buddy chat — history restores on open. Users talk naturally to log data, get updates, or ask health questions.",
      {
        x: 0.45, y: 1.1, w: 6.2, h: 0.45,
        fontSize: 13, fontFace: "Calibri", color: C.muted, margin: 0,
      }
    );

    // Capability cards (2x2)
    const caps = [
      {
        t: "Chat loads instantly",
        d: "Opens last conversation (or a fresh greeting). “New chat” starts a clean thread.",
        icon: I.robot,
        ac: C.violet,
      },
      {
        t: "Log data via chat",
        d: "Say “log 500 ml water” or “add 2000 steps” — AI confirms and writes logged_actions.",
        icon: I.water,
        ac: C.sky,
      },
      {
        t: "Health updates",
        d: "Ask “assess my health score” — buddy reviews score, sleep, hydration, plans & goals.",
        icon: I.chart,
        ac: C.teal,
      },
      {
        t: "Any health query",
        d: "Sleep tips, burn 500 kcal, water targets, routines — free-form Q&A with context.",
        icon: I.heart,
        ac: C.coral,
      },
    ];
    caps.forEach((c, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 0.45 + col * 3.2;
      const y = 1.7 + row * 1.55;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y, w: 3.05, h: 1.4,
        fill: { color: C.white },
        rectRadius: 0.12,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.18, y: y + 0.2, w: 0.42, h: 0.42,
        fill: { color: C.soft },
        rectRadius: 0.1,
      });
      s.addImage({ data: c.icon, x: x + 0.25, y: y + 0.27, w: 0.28, h: 0.28 });
      s.addText(c.t, {
        x: x + 0.18, y: y + 0.72, w: 2.7, h: 0.26,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(c.d, {
        x: x + 0.18, y: y + 0.98, w: 2.7, h: 0.32,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });

    phone(s, 7.05, 0.55, 2.5, 4.55, img("18_ai_buddy.png"), pres);
    footer(s, 10, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 11. CHALLENGES
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.cream },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 4.3, h: 5.625, fill: { color: C.deep },
    });
    pill(s, "STEP 07  ·  ENGAGE", 0.4, 0.4, "134E4A", C.mint, pres);
    s.addText("Challenges &\nrewards.", {
      x: 0.4, y: 0.95, w: 3.6, h: 1.0,
      fontSize: 26, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });
    s.addText(
      "Tab: Challenges. Join a challenge, track progress on Home and Challenges, earn points.",
      {
        x: 0.4, y: 2.15, w: 3.5, h: 0.7,
        fontSize: 13, fontFace: "Calibri", color: "94A3B8", margin: 0,
      }
    );

    const ch = [
      "Overview: total points + active count",
      "Explore: Walk 5k / 10k, Drink 2L…",
      "Join Challenge → progress bar",
      "Points & rank shown on active card",
      "Active goal mirrored on Home",
    ];
    ch.forEach((t, i) => {
      const y = 3.0 + i * 0.4;
      s.addImage({ data: I.checkW, x: 0.45, y: y + 0.02, w: 0.18, h: 0.18 });
      s.addText(t, {
        x: 0.75, y, w: 3.3, h: 0.28,
        fontSize: 12, fontFace: "Calibri", color: "CBD5E1", margin: 0,
      });
    });

    phone(s, 5.5, 0.45, 2.55, 4.7, img("12_challenges.jpg"), pres);
    phone(s, 8.0, 1.0, 1.7, 3.15, img("05_home_gym_active.jpg"), pres);
    footer(s, 11, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 12. PROGRESS
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "07B  ·  Progress & trends",
      "Tab: Progress — Daily / Weekly / Monthly views for steps, calories, sleep, water.",
      pres
    );

    phone(s, 0.45, 1.15, 2.25, 4.05, img("13_progress.jpg"), pres);

    const boxes = [
      { t: "Summary cards", d: "Steps, kcal, sleep hours, hydration vs targets.", ac: C.teal },
      { t: "Trends graph", d: "Toggle Steps / Calories / Sleep / Water charts.", ac: C.sky },
      { t: "Day-by-day logs", d: "Last 7 days with per-day metric chips.", ac: C.violet },
      { t: "Range switch", d: "Daily, Weekly, Monthly aggregation.", ac: C.amber },
    ];
    boxes.forEach((b, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 3.05 + col * 3.3;
      const y = 1.25 + row * 1.75;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y, w: 3.1, h: 1.55,
        fill: { color: C.white },
        rectRadius: 0.14,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.RECTANGLE, {
        x, y, w: 0.1, h: 1.55,
        fill: { color: b.ac },
      });
      s.addText(b.t, {
        x: x + 0.3, y: y + 0.35, w: 2.6, h: 0.35,
        fontSize: 15, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(b.d, {
        x: x + 0.3, y: y + 0.8, w: 2.6, h: 0.5,
        fontSize: 12, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 12, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 13. PROFILE
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "08  ·  Profile & preferences",
      "Edit identity, body metrics, Health Connect, goals, and notification toggles.",
      pres
    );

    phone(s, 0.4, 1.15, 2.15, 3.9, img("14_profile_edit.jpg"), pres);
    phone(s, 2.75, 1.15, 2.15, 3.9, img("15_notifications.jpg"), pres);

    const list = [
      { t: "Edit Profile sheet", d: "Name, DOB, gender, height, weight → Save" },
      { t: "BMI card", d: "Auto BMI + Normal / other status" },
      { t: "Health goals", d: "Steps, water, sleep, calorie targets" },
      { t: "Health Connect", d: "Toggle auto-sync of wearable data" },
      { t: "Notifications", d: "AI tips, hydration, sleep, activity, challenges, daily digest" },
    ];
    list.forEach((item, i) => {
      const y = 1.2 + i * 0.7;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 5.2, y, w: 4.35, h: 0.6,
        fill: { color: C.white },
        rectRadius: 0.1,
        shadow: shadowSoft,
      });
      s.addText(`${i + 1}`, {
        x: 5.35, y: y + 0.12, w: 0.35, h: 0.35,
        fontSize: 14, fontFace: "Arial", color: C.teal, bold: true, margin: 0, valign: "middle",
      });
      s.addText(item.t, {
        x: 5.75, y: y + 0.05, w: 3.6, h: 0.28,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true, margin: 0,
      });
      s.addText(item.d, {
        x: 5.75, y: y + 0.32, w: 3.6, h: 0.24,
        fontSize: 11, fontFace: "Calibri", color: C.muted, margin: 0,
      });
    });
    footer(s, 13, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 14. FULL FLOW DIAGRAM
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    sectionHeader(
      s,
      "Complete navigation model",
      "Hub-and-spoke from Home + 5-tab shell. Center tab = AI Buddy chat (log, updates, Q&A).",
      pres
    );

    // Hub
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 3.7, y: 1.2, w: 2.6, h: 0.7,
      fill: { color: C.teal },
      rectRadius: 0.12,
      shadow: shadowSoft,
    });
    s.addText("HOME HUB", {
      x: 3.7, y: 1.2, w: 2.6, h: 0.7,
      fontSize: 14, fontFace: "Arial", color: C.white, bold: true,
      align: "center", valign: "middle", margin: 0,
    });

    const spokes = [
      { t: "SOS", x: 0.5, y: 1.2, c: C.coral },
      { t: "Gym QR", x: 0.5, y: 2.15, c: C.sky },
      { t: "Workout Plan", x: 0.5, y: 3.1, c: C.violet },
      { t: "Nutrition Plan", x: 0.5, y: 4.05, c: C.orange },
      { t: "Challenges", x: 7.1, y: 1.2, c: C.amber },
      { t: "Progress", x: 7.1, y: 2.15, c: C.teal },
      { t: "AI Buddy Chat", x: 7.1, y: 3.1, c: C.violet },
      { t: "Profile", x: 7.1, y: 4.05, c: C.slate },
    ];
    spokes.forEach((sp) => {
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: sp.x, y: sp.y, w: 2.4, h: 0.7,
        fill: { color: C.white },
        rectRadius: 0.1,
        shadow: shadowSoft,
      });
      s.addShape(pres.shapes.RECTANGLE, {
        x: sp.x, y: sp.y, w: 0.1, h: 0.7,
        fill: { color: sp.c },
      });
      s.addText(sp.t, {
        x: sp.x + 0.2, y: sp.y, w: 2.1, h: 0.7,
        fontSize: 13, fontFace: "Arial", color: C.ink, bold: true,
        valign: "middle", margin: 0,
      });
    });

    // Center note
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 3.5, y: 2.3, w: 3.0, h: 2.5,
      fill: { color: C.white },
      rectRadius: 0.14,
      shadow: shadowSoft,
    });
    s.addText("Bottom tabs", {
      x: 3.65, y: 2.5, w: 2.7, h: 0.3,
      fontSize: 12, fontFace: "Arial", color: C.muted, bold: true, align: "center", margin: 0,
    });
    ["Home", "Challenges", "AI Buddy", "Progress", "Profile"].forEach((t, i) => {
      const isAi = t === "AI Buddy";
      s.addText(`${i + 1}.  ${t}${isAi ? "  ★" : ""}`, {
        x: 3.9, y: 2.9 + i * 0.32, w: 2.4, h: 0.3,
        fontSize: 13, fontFace: "Calibri",
        color: isAi ? C.violet : C.ink,
        bold: isAi,
        margin: 0,
      });
    });
    footer(s, 14, TOTAL);
  }

  // ═══════════════════════════════════════════════════════
  // 15. SUMMARY
  // ═══════════════════════════════════════════════════════
  {
    const s = pres.addSlide();
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 5.625, fill: { color: C.ink },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 0.16, h: 5.625, fill: { color: C.teal },
    });
    s.addShape(pres.shapes.OVAL, {
      x: 7.5, y: -1, w: 4, h: 4,
      fill: { color: C.teal, transparency: 85 },
    });

    s.addText("Flow in one line", {
      x: 0.65, y: 0.55, w: 8, h: 0.4,
      fontSize: 14, fontFace: "Calibri", color: C.mint, bold: true, margin: 0, charSpacing: 1,
    });
    s.addText("From sign-up to daily habit loop.", {
      x: 0.65, y: 1.0, w: 8.5, h: 0.55,
      fontSize: 28, fontFace: "Arial", color: C.white, bold: true, margin: 0,
    });

    const line = [
      { t: "Auth", c: C.teal },
      { t: "Home", c: C.sky },
      { t: "Safety", c: C.coral },
      { t: "Plans", c: C.violet },
      { t: "Log", c: C.orange },
      { t: "AI Chat", c: "A78BFA" },
      { t: "Engage", c: C.amber },
      { t: "Profile", c: C.mint },
    ];
    line.forEach((item, i) => {
      const x = 0.4 + i * 1.18;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y: 2.0, w: 1.05, h: 0.55,
        fill: { color: item.c },
        rectRadius: 0.1,
      });
      s.addText(item.t, {
        x, y: 2.0, w: 1.05, h: 0.55,
        fontSize: 10, fontFace: "Arial", color: C.ink, bold: true,
        align: "center", valign: "middle", margin: 0,
      });
      if (i < line.length - 1) {
        s.addText("→", {
          x: x + 0.95, y: 2.05, w: 0.28, h: 0.45,
          fontSize: 14, fontFace: "Arial", color: "64748B",
          align: "center", valign: "middle", margin: 0,
        });
      }
    });

    const takeaways = [
      { t: "Hub-first design", d: "Home is the control center for score, plans, SOS, and gym." },
      { t: "AI Buddy chat", d: "Center tab chat: log water/steps, get score updates, ask any health question." },
      { t: "AI-assisted plans", d: "Workout & nutrition plans generated in a guided wizard." },
      { t: "Close the loop", d: "Chat or screens to log → Challenges → Progress → Profile." },
    ];
    takeaways.forEach((tk, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 0.55 + col * 4.6;
      const y = 2.9 + row * 1.05;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x, y, w: 4.35, h: 0.9,
        fill: { color: "132033" },
        rectRadius: 0.12,
      });
      s.addText(tk.t, {
        x: x + 0.25, y: y + 0.12, w: 3.9, h: 0.28,
        fontSize: 14, fontFace: "Arial", color: C.mint, bold: true, margin: 0,
      });
      s.addText(tk.d, {
        x: x + 0.25, y: y + 0.45, w: 3.9, h: 0.35,
        fontSize: 12, fontFace: "Calibri", color: "94A3B8", margin: 0,
      });
    });
  }

  const outPath = path.join(__dirname, "MediFit_User_Flow.pptx");
  await pres.writeFile({ fileName: outPath });
  console.log("Wrote", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
