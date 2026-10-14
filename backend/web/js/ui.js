// Shared UI: the web counterparts of Design/*.swift and the Kitchen elements.
import { html, useEffect, useRef, useState } from "../vendor/preact-htm.mjs";
import { t } from "./i18n.js";

export const C = {
  primary: "#0e9f5b", primaryDark: "#0a7a45", primarySoft: "#e7f6ee", ink: "#0f172a",
  ink2: "#5b6472", muted: "#8a94a0", hairline: "#e4ebe7", warning: "#d97706", critical: "#dc2626", closed: "#8a94a0",
};

export const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function bandFor(score) {
  if (score >= 75) return { key: "healthy", label: t("Healthy"), color: C.primary, icon: "seal" };
  if (score >= 55) return { key: "watch", label: t("Needs attention"), color: C.warning, icon: "warning" };
  return { key: "at_risk", label: t("At risk"), color: C.critical, icon: "cross" };
}

// ---------- icons (24×24 stroke) ----------
const P = {
  arrowRight: "M5 12h14M13 6l6 6-6 6",
  chevronRight: "M9 6l6 6-6 6",
  chevronLeft: "M15 6l-6 6 6 6",
  check: "M5 12.5l4.5 4.5L19 7.5",
  x: "M6 6l12 12M18 6L6 18",
  stethoscope: "M6 3v6a4 4 0 008 0V3M10 13v2a5 5 0 0010 0v-2M20 11a2 2 0 100-4 2 2 0 000 4z",
  camera: "M4 8h3l2-3h6l2 3h3v11H4zM12 17a4 4 0 100-8 4 4 0 000 8z",
  photo: "M4 5h16v14H4zM4 15l4-4 4 4 3-3 5 5M15 9.5a1.5 1.5 0 100-3 1.5 1.5 0 000 3z",
  pin: "M12 21s7-6.2 7-12a7 7 0 10-14 0c0 5.8 7 12 7 12zM12 11.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z",
  building: "M5 21V4h9v17M14 9h5v12M8 8h3M8 12h3M8 16h3M17 13h0M17 17h0",
  pills: "M10.5 3.5a5 5 0 017 7l-7 7a5 5 0 01-7-7zM7 7l7 7",
  heart: "M12 20s-7-4.4-7-10a4 4 0 017-2.6A4 4 0 0119 10c0 5.6-7 10-7 10zM3 12h4l2-3 3 6 2-3h7",
  banknote: "M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6zM6 10v4M18 10v4",
  chart: "M4 19h16M5 15l4-5 4 3 6-7",
  eye: "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 15a3 3 0 100-6 3 3 0 000 6z",
  cube: "M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5",
  info: "M12 21a9 9 0 100-18 9 9 0 000 18zM12 11v6M12 7.5h0",
  locate: "M12 2v3M12 19v3M2 12h3M19 12h3M12 18a6 6 0 100-12 6 6 0 000 12zM12 14a2 2 0 100-4 2 2 0 000 4z",
  send: "M12 19V5M6 11l6-6 6 6",
  clock: "M12 21a9 9 0 100-18 9 9 0 000 18zM12 7v5l3 2",
  trash: "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3",
  refresh: "M20 11a8 8 0 10-2.3 5.7M20 4v7h-7",
  warning: "M12 3l10 18H2zM12 10v5M12 18h0",
  seal: "M12 2l2.4 2.1 3.2-.3.8 3.1 2.8 1.6-1.2 3 1.2 3-2.8 1.6-.8 3.1-3.2-.3L12 22l-2.4-2.1-3.2.3-.8-3.1L2.8 15.5l1.2-3-1.2-3 2.8-1.6.8-3.1 3.2.3zM8.5 12l2.5 2.5 4.5-5",
  cross: "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
  scope: "M12 20a8 8 0 100-16 8 8 0 000 16zM12 2v4M12 18v4M2 12h4M18 12h4",
  wrench: "M14.5 6.5a4 4 0 005 5L13 18l-3 3-4-4 3-3 6.5-6.5zM4 4l5 5",
  users: "M9 11a3.5 3.5 0 100-7 3.5 3.5 0 000 7zM2.5 20a6.5 6.5 0 0113 0M16 4.5a3.5 3.5 0 010 6.5M18 14a6.5 6.5 0 013.5 6",
  list: "M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01",
  menu: "M5 3h11l3 3v15H5zM8 9h8M8 13h8M8 17h5",
  store: "M3 9l2-5h14l2 5M3 9h18v2a3 3 0 01-6 0 3 3 0 01-6 0 3 3 0 01-6 0zM5 13v8h14v-8M10 21v-5h4v5",
  card: "M3 6h18v12H3zM3 10h18",
  hand: "M8 13V5.5a1.5 1.5 0 013 0V12M11 11V4.5a1.5 1.5 0 013 0V12M14 11.5V6a1.5 1.5 0 013 0v8a7 7 0 01-7 7h-.5A6.5 6.5 0 014 15.6L2.8 13a1.6 1.6 0 012.8-1.5L8 15",
  doc: "M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6",
  plus: "M12 5v14M5 12h14",
  lightbulb: "M9 18h6M10 21h4M12 3a6 6 0 00-3.5 10.9V16h7v-2.1A6 6 0 0012 3z",
  chair: "M6 3h12v8H6zM5 11h14v3H5zM7 14v7M17 14v7",
  fork: "M7 3v8a2 2 0 002 2v8M11 3v8M17 3c-2 2-2 6 0 8v10",
  door: "M5 21V3h11v18M16 5h3v16M12 12h.01",
  toilet: "M6 3h5v7H6zM4 10h16a6 6 0 01-6 6v5H9v-5a5 5 0 01-5-6z",
};

export const Icon = ({ name, size = 18, stroke = 2, color = "currentColor" }) => html`
  <svg width=${size} height=${size} viewBox="0 0 24 24" fill="none" stroke=${color} stroke-width=${stroke}
       stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d=${P[name] || P.info} /></svg>`;

// ---------- layout pieces ----------
export const Card = ({ children, flush, style }) => html`<div class=${"card" + (flush ? " flush" : "")} style=${style}>${children}</div>`;

export const SectionTitle = ({ title, subtitle, icon }) => html`
  <div class="section-title">
    <div class="t">${icon && html`<span class="ico"><${Icon} name=${icon} /></span>`}${title}</div>
    ${subtitle && html`<div class="caption">${subtitle}</div>`}
  </div>`;

export const Pill = ({ text, icon, tint = C.primary }) => html`
  <span class="pill" style=${{ "--tint": tint }}>${icon && html`<${Icon} name=${icon} size=${13} stroke=${2.4} />`}${text}</span>`;

export const StatusPill = ({ score }) => { const b = bandFor(score); return html`<${Pill} text=${b.label} icon=${b.icon} tint=${b.color} />`; };

export const Stat = ({ label, value, detail, tint }) => html`
  <div class="stat">
    <div class="caption">${label}</div>
    <div class="v">${value}</div>
    ${detail && html`<div class="caption" style=${{ color: tint || C.ink2 }}>${detail}</div>`}
  </div>`;

export const Bullets = ({ items }) => html`<ul class="bullets">${items.map((i) => html`<li>${i}</li>`)}</ul>`;

export function TopBar({ title, onBack, right }) {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 4);
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);
  return html`
    <div class=${"topbar" + (scrolled ? " scrolled" : "")}>
      ${onBack ? html`<button class="icon-btn" onClick=${onBack} aria-label=${t("Back")}><${Icon} name="chevronLeft" /></button>` : html`<span style="width:36px" />`}
      <h1>${title}</h1>
      ${right || html`<span style="width:36px" />`}
    </div>`;
}

// ---------- score ring & bar ----------
export function ScoreRing({ score, size = 148, width = 14 }) {
  const [shown, setShown] = useState(0);
  useEffect(() => { const id = requestAnimationFrame(() => setShown(score)); return () => cancelAnimationFrame(id); }, [score]);
  const r = (size - width) / 2, circ = 2 * Math.PI * r;
  const b = bandFor(score);
  return html`
    <div class="ring" style=${{ width: size + "px", height: size + "px" }} role="img"
         aria-label=${t("Health Score %lld out of 100, %@", Math.round(score), b.label)}>
      <svg width=${size} height=${size}>
        <circle cx=${size / 2} cy=${size / 2} r=${r} stroke=${C.primarySoft} stroke-width=${width} />
        <circle class="fg" cx=${size / 2} cy=${size / 2} r=${r} stroke=${b.color} stroke-width=${width} stroke-linecap="round"
                stroke-dasharray=${circ} stroke-dashoffset=${circ * (1 - shown / 100)} />
      </svg>
      <div class="lbl"><b style=${{ fontSize: size * 0.32 + "px" }}>${Math.round(score)}</b><span class="caption">${t("of 100")}</span></div>
    </div>`;
}

export function ScoreBar({ score }) {
  const [w, setW] = useState(0);
  useEffect(() => { const id = requestAnimationFrame(() => setW(score)); return () => cancelAnimationFrame(id); }, [score]);
  return html`<div class="score-bar"><i style=${{ width: Math.max(4, w) + "%", background: bandFor(score).color }} /></div>`;
}

// ---------- Kitchen: Scramble Text ----------
const SYMBOLS = "-_~`!@#$%^&*()+=[]{}|;:,.<>?";
export function ScrambleText({ text, interval = 32 }) {
  const [shown, setShown] = useState(text);
  useEffect(() => {
    if (reducedMotion()) { setShown(text); return; }
    const chars = [...text];
    const steps = Math.min(48, chars.length);
    let step = 0;
    const id = setInterval(() => {
      step++;
      const revealed = Math.ceil((step / steps) * chars.length);
      setShown(chars.map((c, i) => (i < revealed || /\s/.test(c) ? c : SYMBOLS[(Math.random() * SYMBOLS.length) | 0])).join(""));
      if (step >= steps) clearInterval(id);
    }, interval);
    return () => clearInterval(id);
  }, [text]);
  return html`<span aria-label=${text}>${shown}</span>`;
}

// ---------- Kitchen: Logo Trace Loader (medical cross) ----------
const CROSS = "M41.5 6 H58.5 Q66 6 66 13.5 V34 H86.5 Q94 34 94 41.5 V58.5 Q94 66 86.5 66 H66 V86.5 Q66 94 58.5 94 H41.5 Q34 94 34 86.5 V66 H13.5 Q6 66 6 58.5 V41.5 Q6 34 13.5 34 H34 V13.5 Q34 6 41.5 6 Z";
export function CrossLoader({ complete, size = 104, onDone }) {
  const [phase, setPhase] = useState("loop");
  const fired = useRef(false);
  useEffect(() => {
    if (!complete || fired.current) return;
    fired.current = true;
    if (reducedMotion()) { setPhase("filled"); onDone && onDone(); return; }
    setPhase("done");
    const a = setTimeout(() => setPhase("filled"), 450);
    const b = setTimeout(() => onDone && onDone(), 1000);
    return () => { clearTimeout(a); clearTimeout(b); };
  }, [complete]);
  const cls = "cross-loader" + (phase !== "loop" ? " done" : "") + (phase === "filled" ? " filled" : "");
  return html`
    <svg class=${cls} width=${size} height=${size} viewBox="0 0 100 100" role="status" aria-label=${complete ? t("Diagnosis ready") : t("Diagnosing")}>
      <path class="track" d=${CROSS} pathLength="1" />
      <path class="seg" d=${CROSS} pathLength="1" />
      <path class="close" d=${CROSS} pathLength="1" />
      <path class="fill" d=${CROSS} />
    </svg>`;
}

// ---------- Kitchen: Animated Signature ----------
const SIGNATURE = "M18 62 C6 40 26 14 46 18 C70 24 58 70 30 72 C14 74 40 50 62 52 C72 50 76 66 84 60 C92 54 96 40 104 44 C112 48 104 66 116 62 C128 58 130 30 138 30 C146 32 134 64 140 64 C150 64 158 44 170 46 C182 48 166 64 176 62 C188 60 194 44 204 44 C214 44 212 62 222 60 C232 58 238 40 248 40 C262 42 150 96 40 84 C120 78 220 70 282 76";
export function Signature({ draw, instant }) {
  const [on, setOn] = useState(false);
  useEffect(() => { if (draw) { const id = requestAnimationFrame(() => setOn(true)); return () => cancelAnimationFrame(id); } }, [draw]);
  return html`
    <svg class=${"signature" + (instant ? " drawn" : on ? " draw" : "")} viewBox="0 0 300 100" width="120" height="40" role="img" aria-label=${t("Signed, Dr. ShopDoctor")}>
      <path d=${SIGNATURE} pathLength="1" />
    </svg>`;
}

// ---------- Kitchen: Hold to Confirm ----------
export function HoldToConfirm({ label, duration = 1600, onConfirm }) {
  const [p, setP] = useState(0);
  const [holding, setHolding] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const timer = useRef(null), start = useRef(0), raf = useRef(0);

  const tick = () => {
    const prog = Math.min(1, (performance.now() - start.current) / duration);
    setP(prog);
    if (prog < 1) raf.current = requestAnimationFrame(tick);
  };
  const begin = (e) => {
    if (confirmed) return;
    e.currentTarget.setPointerCapture?.(e.pointerId);
    setHolding(true);
    start.current = performance.now();
    raf.current = requestAnimationFrame(tick);
    timer.current = setTimeout(complete, duration);
  };
  const cancel = () => {
    if (!holding) return;
    setHolding(false);
    clearTimeout(timer.current);
    cancelAnimationFrame(raf.current);
    setP(0);
  };
  const complete = () => {
    cancelAnimationFrame(raf.current);
    setHolding(false);
    setP(1);
    setConfirmed(true);
    navigator.vibrate && navigator.vibrate(20);
    onConfirm();
    setTimeout(() => { setConfirmed(false); setP(0); }, 1800);
  };
  const content = html`<${Icon} name=${confirmed ? "check" : "hand"} size=${16} /> ${confirmed ? t("Confirmed") : holding ? t("Keep holding…") : label}`;
  return html`
    <button class=${"hold" + (holding ? " holding" : "")} style=${{ "--p": p * 100 + "%" }}
            onPointerDown=${begin} onPointerUp=${cancel} onPointerCancel=${cancel} onPointerLeave=${cancel}
            onKeyDown=${(e) => (e.key === "Enter" || e.key === " ") && complete()}
            aria-label=${label} title=${t("Press and hold to confirm")}>
      <span class="lbl">${content}</span>
      <span class="fill"><span class="lbl">${content}</span></span>
    </button>`;
}

export function UndoBar({ message, seconds = 4, onUndo, onCommit }) {
  const [left, setLeft] = useState(1);
  useEffect(() => {
    const t0 = performance.now();
    const id = setInterval(() => setLeft(Math.max(0, 1 - (performance.now() - t0) / (seconds * 1000))), 50);
    const done = setTimeout(onCommit, seconds * 1000);
    return () => { clearInterval(id); clearTimeout(done); };
  }, []);
  const r = 8, circ = 2 * Math.PI * r;
  return html`
    <div class="undo-bar fade-in">
      <svg width="20" height="20" viewBox="0 0 20 20" style="transform:rotate(-90deg)">
        <circle cx="10" cy="10" r=${r} fill="none" stroke="rgba(255,255,255,.25)" stroke-width="2.5" />
        <circle cx="10" cy="10" r=${r} fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round"
                stroke-dasharray=${circ} stroke-dashoffset=${circ * (1 - left)} />
      </svg>
      <span class="spacer">${message}</span>
      <button onClick=${onUndo}>${t("Undo")}</button>
    </div>`;
}

/** Markers shared by charts, tracks and maps: filled dot (survivor), ring (closed), diamond (you). */
export const Marker = ({ kind }) => html`<span class=${"mk " + kind} style="position:relative;display:inline-block;top:0;transform:${kind === "you" ? "rotate(45deg)" : "none"}" />`;
export const LegendItem = ({ kind, label }) => html`<span><${Marker} kind=${kind} />${label}</span>`;
