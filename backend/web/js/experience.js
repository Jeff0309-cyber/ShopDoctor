// The shop-experience check on the web: guided photos → fix plan.
// iPhone LiDAR scans can't run in a browser, but rooms scanned in the iOS app (or the demo room)
// are drawn here as a top-down floor plan with pins and "move it here" ghosts.
import { html, useEffect, useState } from "../vendor/preact-htm.mjs";
import { t, sentenceCase } from "./i18n.js";
import { api, toJpeg, blobToDataUrl } from "./api.js";
import { C, Card, Icon, Pill, ScoreBar, ScoreRing, SectionTitle, Stat, Bullets, TopBar } from "./ui.js";
import { ThinkingScreen } from "./thinking.js";
import { state, set, useStore, back, switchTab } from "./store.js";

export const scanCapable = () => false;  // browsers have no RoomPlan; the iPhone app does the 3D scan

const SHOTS = [
  ["entrance", "Entrance from outside", "Stand across the street in daylight. Fit the whole frontage in.", "store"],
  ["door", "First view from the door", "Step just inside and shoot what a new customer sees first.", "door"],
  ["seating", "Seating area", "From a corner, wide, with the walkways visible.", "chair"],
  ["table", "A table set for service", "Chair height, with cutlery, sauces and menu as customers find them.", "fork"],
  ["ordering", "Ordering and payment point", "The counter or menu board, including any payment signs.", "card"],
  ["washroom", "Washroom", "A wide shot, if customers use it.", "toilet"],
  ["atmosphere", "Peak-hour atmosphere", "During your busiest hour, lights as normal. No faces.", "lightbulb"],
];
const required = (withRoom) => (withRoom ? ["entrance", "table"] : ["entrance", "door", "seating", "table"]);
const ANALYSE_STAGES = ["Measuring your layout", "Walking in as a customer", "Checking tables and counter", "Comparing with busy HK shops", "Writing your fix plan"];

// ---------- on-device bits: done fixes and photo thumbnails ----------
const doneKey = (a) => "doneIssues-" + a.generated_at;
export function doneFor(audit) { try { return new Set(JSON.parse(localStorage.getItem(doneKey(audit)) || "[]")); } catch { return new Set(); } }
function saveDone(audit, ids) { try { localStorage.setItem(doneKey(audit), JSON.stringify([...ids])); } catch {} }
const thumbKey = (shot) => "shot-" + shot;
const thumb = (shot) => { try { return localStorage.getItem(thumbKey(shot)); } catch { return null; } };

export function ExperiencePage() {
  const s = useStore();
  const [rechecking, setRechecking] = useState(false);
  const showResult = s.experience && !rechecking;
  return html`
    <div>
      <${TopBar} title=${t("Shop experience")} onBack=${back} />
      ${showResult ? html`<${Result} audit=${s.experience} onRecheck=${() => setRechecking(true)} />`
                   : html`<${Capture} onDone=${() => setRechecking(false)} />`}
    </div>`;
}

// ---------- capture ----------
function Capture({ onDone }) {
  const s = useStore();
  const [room, setRoom] = useState(null);
  const [photos, setPhotos] = useState({});
  const [analysing, setAnalysing] = useState(false);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState("");
  const need = required(!!room);
  const ok = need.every((k) => photos[k]);

  const analyse = async () => {
    setError(""); setReady(false); setAnalysing(true);
    try {
      const audit = await api.runExperience(state.shop.id, room, photos);
      for (const [shot, blob] of Object.entries(photos)) {
        try { localStorage.setItem(thumbKey(shot), await blobToDataUrl(await toJpeg(blob, 480, 0.7))); } catch {}
      }
      set({ experience: audit });
      setReady(true);
    } catch (e) {
      setAnalysing(false);
      setError(e.message);
    }
  };

  if (analysing) {
    return html`<div class="overlay"><${ThinkingScreen} ready=${ready} stages=${ANALYSE_STAGES} stageMs=${1500}
      title="Examining your shop" doneTitle="Fix plan ready" subtitle="Let the Doctor walk through your shop the way a customer does. It takes about 5 minutes."
      doneSubtitle="Fix plan ready" onDone=${() => { setAnalysing(false); onDone(); }} /></div>`;
  }

  return html`
    <div class="screen soft stack">
      <p class="secondary" style="margin:0">${t("Let the Doctor walk through your shop the way a customer does. It takes about 5 minutes.")}</p>
      ${error && html`<div class="error">${error}</div>`}
      <${Card}>
        <${SectionTitle} title=${t("3D scan")} subtitle=${t("Measures your layout: seats, aisles and doorways")} icon="cube" />
        ${room ? html`
          <div class="row"><span style="color:#0e9f5b"><${Icon} name="check" stroke=${3} /></span>
            <b>${t("%lld tables · %@ m² scanned", room.objects.filter((o) => o.category === "table").length, Math.round(area(room.floor)))}</b></div>
          <button class="btn-secondary" onClick=${() => setRoom(null)}>${t("Remove sample room")}</button>`
        : html`
          <div class="secondary">${t("3D scanning needs the ShopDoctor iPhone app on an iPhone Pro with LiDAR. Here we'll use photos instead.")}</div>
          ${s.demoMode && html`<button class="btn-secondary" onClick=${async () => setRoom(await api.demoRoom())}><${Icon} name="cube" /> ${t("Load sample room")}</button>`}`}
      </${Card}>
      <div class="notice"><span style="color:#0e9f5b"><${Icon} name="hand" /></span>
        <div><b>${t("Before you shoot")}</b><div class="caption">${t("No customers' or staff faces. Lights on, phone held sideways.")}</div></div></div>
      <h2 class="headline">${room ? t("Detail photos") : t("Photos")}</h2>
      ${SHOTS.filter(([k]) => !room || ["entrance", "table", "ordering", "washroom"].includes(k)).map(([k, title, tip, icon]) => html`
        <${ShotCard} title=${t(title)} tip=${t(tip)} icon=${icon} required=${need.includes(k)} blob=${photos[k]}
                     onChange=${(blob) => setPhotos((p) => { const n = { ...p }; blob ? (n[k] = blob) : delete n[k]; return n; })} />`)}
      <button class="btn-primary" disabled=${!ok} onClick=${analyse}>${t("Analyse my shop")} <${Icon} name="stethoscope" /></button>
      ${!ok && html`<div class="caption center">${t("Add the required photos to continue.")}</div>`}
    </div>`;
}

function ShotCard({ title, tip, icon, required: req, blob, onChange }) {
  const pick = async (e) => {
    const f = e.target.files[0];
    e.target.value = "";
    if (f) onChange(await toJpeg(f));
  };
  return html`
    <div class="card" style="flex-direction:row;align-items:flex-start;gap:14px;padding:14px">
      <div class="thumb">${blob ? html`<img src=${URL.createObjectURL(blob)} alt="" />` : html`<${Icon} name=${icon} size=${24} />`}</div>
      <div class="spacer stack-sm" style="gap:4px">
        <div class="row"><b class="spacer">${title}</b>
          ${blob ? html`<span style="color:#0e9f5b"><${Icon} name="check" stroke=${3} /></span>`
                 : html`<${Pill} text=${req ? t("Required") : t("Optional")} tint=${req ? C.primaryDark : C.ink2} />`}</div>
        <div class="caption">${tip}</div>
        <div class="row" style="gap:16px;margin-top:2px">
          <label class="link caption" style="cursor:pointer"><${Icon} name="camera" size=${14} />${blob ? t("Retake") : t("Take photo")}
            <input type="file" accept="image/*" capture="environment" hidden onChange=${pick} /></label>
          <label class="link caption" style="cursor:pointer"><${Icon} name="photo" size=${14} />${t("Choose from library")}
            <input type="file" accept="image/*" hidden onChange=${pick} /></label>
          ${blob && html`<button class="link caption" style="color:#dc2626" onClick=${() => onChange(null)}>${t("Remove")}</button>`}
        </div>
      </div>
    </div>`;
}

const area = (floor) => {
  if (!floor || floor.length < 3) return 0;
  let a = 0;
  floor.forEach((p, i) => { const q = floor[(i + 1) % floor.length]; a += p.x * q.z - q.x * p.z; });
  return Math.abs(a) / 2;
};

// ---------- result ----------
function Result({ audit, onRecheck }) {
  const [done, setDone] = useState(() => doneFor(audit));
  const [plan, setPlan] = useState(null);  // index of the fix being shown
  useEffect(() => saveDone(audit, done), [done]);
  const m = audit.layout;
  const firstOpen = Math.max(0, audit.issues.findIndex((i) => !done.has(i.id)));

  return html`
    <div class="screen soft stack">
      <${Card}>
        <div class="row" style="gap:18px"><${ScoreRing} score=${audit.overall} size=${104} width=${10} /><div>${audit.verdict}</div></div>
        ${m && html`<div class="grid3">
          <${Stat} label=${t("Seats")} value=${m.seats} detail=${t("%lld tables", m.tables)} />
          <${Stat} label=${t("Space per seat")} value=${m.m2_per_seat != null ? m.m2_per_seat.toFixed(1) + " m²" : "–"} />
          <${Stat} label=${t("Narrowest aisle")} value=${m.narrowest_aisle_m != null ? m.narrowest_aisle_m.toFixed(2) + " m" : "–"}
                   detail=${(m.narrowest_aisle_m ?? 1) < 0.9 ? t("Below 0.9 m") : t("Comfortable")} tint=${(m.narrowest_aisle_m ?? 1) < 0.9 ? C.critical : C.primaryDark} />
        </div>`}
      </${Card}>
      ${audit.room && html`
        <${Card} flush>
          <${PlanView} room=${audit.room} issues=${audit.issues} done=${done} onSelect=${(id) => setPlan(audit.issues.findIndex((i) => i.id === id))} />
          <div class="caption" style="padding:0 14px 12px">${t("Top-down plan, entrance at the bottom · tap a pin")}</div>
        </${Card}>`}
      <${Card}>
        <${SectionTitle} title=${t("Your fix plan")} subtitle=${t("%lld of %lld fixed", done.size, audit.issues.length)} icon="list" />
        <div class="score-bar"><i style=${{ width: (audit.issues.length ? (done.size / audit.issues.length) * 100 : 100) + "%", background: C.primary }} /></div>
        ${audit.issues.length > 0 && html`<button class="btn-primary" onClick=${() => setPlan(firstOpen)}>${done.size ? t("Continue fixing") : t("Start fixing")} <${Icon} name="arrowRight" /></button>`}
        ${audit.issues.map((issue, i) => html`
          <button class="row-top" style="text-align:left;padding:6px 0" onClick=${() => setPlan(i)}>
            <span class="num-badge" style=${{ background: done.has(issue.id) ? C.primary : issue.impact === "high" ? C.critical : C.warning }}>
              ${done.has(issue.id) ? html`<${Icon} name="check" size=${14} stroke=${3} />` : i + 1}</span>
            <span class="spacer stack-sm" style="gap:4px">
              <b style=${{ textDecoration: done.has(issue.id) ? "line-through" : "none", color: done.has(issue.id) ? C.muted : C.ink }}>${issue.title}</b>
              <${Chips} issue=${issue} />
            </span>
            <span class="muted" style="margin-top:4px"><${Icon} name="chevronRight" size=${14} stroke=${3} /></span>
          </button>`)}
      </${Card}>
      <${Card}>
        <${SectionTitle} title=${t("How the shop scores")} subtitle=${t("Out of 10, from a customer's point of view")} icon="users" />
        ${[...audit.areas].sort((a, b) => a.score - b.score).map((a) => html`
          <div class="stack-sm" style="gap:4px"><div class="row caption"><span class="spacer">${a.label}</span><b class="num" style="color:#0f172a">${Math.round(a.score)}/10</b></div><${ScoreBar} score=${a.score * 10} /></div>`)}
      </${Card}>
      ${audit.notes.length > 0 && html`<${Card}><${SectionTitle} title=${t("About this check")} icon="info" /><${Bullets} items=${audit.notes} /></${Card}>`}
      <div class="row">
        <button class="btn-secondary" onClick=${() => switchTab("doctor")}><${Icon} name="stethoscope" /> ${t("Ask the Doctor")}</button>
        <button class="btn-secondary" onClick=${onRecheck}><${Icon} name="refresh" /> ${t("Check again")}</button>
      </div>
      ${plan != null && plan >= 0 && html`<${FixPlan} audit=${audit} start=${plan} done=${done} setDone=${setDone}
                                                       onClose=${() => setPlan(null)} onRecheck=${() => { setPlan(null); onRecheck(); }} />`}
    </div>`;
}

const Chips = ({ issue }) => html`
  <span class="row" style="gap:6px;flex-wrap:wrap">
    <${Pill} text=${sentenceCase(t("%@ impact", t(issue.impact)))} tint=${issue.impact === "high" ? C.critical : C.ink2} />
    <${Pill} text=${sentenceCase(t("%@ cost", t(issue.cost)))} tint=${C.ink2} />
    <${Pill} text=${issue.effort} icon="clock" tint=${C.ink2} />
  </span>`;

// ---------- guided fix plan ----------
function FixPlan({ audit, start, done, setDone, onClose, onRecheck }) {
  const [i, setI] = useState(start);
  const issue = audit.issues[i];
  const allDone = audit.issues.every((x) => done.has(x.id));
  const isDone = done.has(issue.id);
  const shot = issue.target && issue.target.startsWith("photo:") ? issue.target.slice(6) : null;
  const photo = shot && thumb(shot);

  const toggle = () => {
    const next = new Set(done);
    if (isDone) { next.delete(issue.id); setDone(next); return; }
    next.add(issue.id);
    setDone(next);
    navigator.vibrate && navigator.vibrate(15);
    // Move on to the next open fix after a beat, so the tick lands first.
    setTimeout(() => {
      const after = audit.issues.findIndex((x, j) => j > i && !next.has(x.id));
      const any = audit.issues.findIndex((x) => !next.has(x.id));
      if (after >= 0) setI(after); else if (any >= 0) setI(any);
    }, 600);
  };

  return html`
    <div class="overlay">
      <div class="stack-sm" style="padding:calc(14px + env(safe-area-inset-top)) var(--gutter) 10px">
        <div class="row"><b class="spacer headline">${t("Fix %lld of %lld", i + 1, audit.issues.length)}</b>
          <button class="icon-btn" onClick=${onClose} aria-label=${t("Close")}><${Icon} name="x" /></button></div>
        <div class="row" style="gap:4px">${audit.issues.map((x, j) => html`
          <span style=${{ flex: 1, height: "4px", borderRadius: "4px", background: done.has(x.id) ? C.primary : j === i ? C.ink : C.hairline }} />`)}</div>
      </div>
      ${audit.room && !shot ? html`<${PlanView} room=${audit.room} issues=${audit.issues} done=${done} focus=${issue.id} onSelect=${(id) => setI(audit.issues.findIndex((x) => x.id === id))} />`
        : photo ? html`<img src=${photo} alt=${shot} style="width:100%;height:240px;object-fit:cover" />`
        : html`<div style="height:160px;background:#e7f6ee;display:grid;place-items:center;color:#0e9f5b"><${Icon} name="store" size=${54} /></div>`}
      <div class="screen no-tabs stack fade-in" key=${issue.id}>
        ${isDone && html`<div class="row caption" style="color:#0a7a45;font-weight:650"><${Icon} name="check" size=${14} stroke=${3} />${t("Done")}</div>`}
        <h2 class="title-sm">${issue.title}</h2>
        <${Chips} issue=${issue} />
        <div><div class="row caption"><${Icon} name="eye" size=${14} />${t("What we noticed")}</div><div>${issue.observation}</div></div>
        <div><div class="row caption"><${Icon} name="users" size=${14} />${t("Why it matters")}</div><div>${issue.why_it_matters}</div></div>
        <div class="notice" style="flex-direction:column">
          <div class="row caption" style="color:#0a7a45;font-weight:650"><${Icon} name="wrench" size=${14} />${t("How to fix it")}</div>
          <ol class="steps-ol">${issue.steps.map((st, k) => html`<li><span class="n">${k + 1}</span><span>${st}</span></li>`)}</ol>
          ${issue.suggested_move && audit.room && html`<div class="caption">${t("The green shape on the plan shows where it should go.")}</div>`}
        </div>
      </div>
      <div class="footer-bar">
        ${allDone ? html`
          <div class="center"><b style="color:#0a7a45">${t("All fixes done")}</b><div class="caption">${t("Check again to see how your score changed.")}</div></div>
          <button class="btn-primary" onClick=${onRecheck}>${t("Check again")} <${Icon} name="refresh" /></button>` : html`
          <button class="btn-primary" onClick=${toggle}><${Icon} name=${isDone ? "refresh" : "check"} stroke=${2.6} /> ${isDone ? t("Mark as not done") : t("Mark as done")}</button>
          <div class="row">
            <button class="btn-secondary" disabled=${i === 0} onClick=${() => setI(i - 1)}>${t("Back")}</button>
            <button class="btn-secondary" disabled=${i === audit.issues.length - 1} onClick=${() => setI(i + 1)}>${t("Next")}</button>
          </div>`}
      </div>
    </div>`;
}

// ---------- top-down floor plan ----------
function PlanView({ room, issues, done, focus, onSelect }) {
  const doors = room.elements.filter((e) => e.kind === "door");
  const xs = room.floor.map((p) => p.x), zs = room.floor.map((p) => p.z);
  const minX = Math.min(...xs), maxX = Math.max(...xs), minZ = Math.min(...zs), maxZ = Math.max(...zs);
  const cz = (minZ + maxZ) / 2;
  // Turn the plan so the entrance is at the bottom (a 180° turn when doors sit at low z).
  const flip = doors.length && doors.reduce((s, d) => s + d.z, 0) / doors.length <= cz;
  const W = 340, pad = 18;
  const scale = (W - pad * 2) / Math.max(maxX - minX, 0.1);
  const H = (maxZ - minZ) * scale + pad * 2;
  const px = (x) => pad + (flip ? maxX - x : x - minX) * scale;
  const pz = (z) => pad + (flip ? maxZ - z : z - minZ) * scale;
  const rot = (deg) => deg;  // a 180° turn leaves rectangle angles unchanged

  const pinned = issues.map((iss, n) => ({ iss, n })).filter(({ iss }) => iss.target && !iss.target.startsWith("photo:"));
  const byId = Object.fromEntries([...room.objects, ...room.elements].map((o) => [o.id, o]));
  const tint = (o) => {
    const hit = pinned.find(({ iss }) => iss.target === o.id && !done.has(iss.id));
    if (!hit) return o.category === "table" ? "#e8e3db" : o.category === "chair" || o.category === "sofa" ? "#f4f4f2" : "#c7ccd1";
    return hit.iss.impact === "high" ? "#f3a5a5" : "#f6c98a";
  };
  const dim = (id) => (focus && focus !== id ? 0.35 : 1);

  return html`
    <div class="plan">
      <svg viewBox=${`0 0 ${W} ${H}`} role="img" aria-label=${t("Top-down plan, entrance at the bottom · tap a pin")}>
        <polygon points=${room.floor.map((p) => `${px(p.x)},${pz(p.z)}`).join(" ")} fill="#fbfbfa" stroke="#d5dbd7" stroke-width="3" />
        ${room.elements.filter((e) => e.kind === "window").map((e) => html`
          <rect x=${-e.width * scale / 2} y="-2.5" width=${e.width * scale} height="5" fill="#bcdbf4" transform=${`translate(${px(e.x)},${pz(e.z)}) rotate(${rot(e.angle_deg)})`} />`)}
        ${doors.map((e) => html`
          <rect x=${-e.width * scale / 2} y="-6" width=${e.width * scale} height="12" rx="3" fill=${C.primarySoft} stroke=${C.primary} stroke-width="1" transform=${`translate(${px(e.x)},${pz(e.z)}) rotate(${rot(e.angle_deg)})`} />`)}
        ${room.objects.map((o) => html`
          <rect x=${-o.width * scale / 2} y=${-o.depth * scale / 2} width=${o.width * scale} height=${o.depth * scale} rx="3"
                fill=${tint(o)} stroke="#b9c0c6" stroke-width="0.8" transform=${`translate(${px(o.x)},${pz(o.z)}) rotate(${rot(o.angle_deg)})`} />`)}
        ${pinned.map(({ iss }) => {
          const mv = iss.suggested_move, o = mv && byId[mv.object_id];
          if (!o || done.has(iss.id)) return null;
          const x0 = px(o.x), z0 = pz(o.z), x1 = px(o.x + mv.dx_m), z1 = pz(o.z + mv.dz_m);
          return html`<g opacity=${dim(iss.id)}>
            <rect x=${-o.width * scale / 2} y=${-o.depth * scale / 2} width=${o.width * scale} height=${o.depth * scale} rx="3"
                  fill="rgba(14,159,91,.35)" stroke=${C.primary} stroke-width="1.5" stroke-dasharray="4 3"
                  transform=${`translate(${x1},${z1}) rotate(${rot(o.angle_deg + (mv.rotate_deg || 0))})`} />
            <line x1=${x0} y1=${z0} x2=${x1} y2=${z1} stroke=${C.primaryDark} stroke-width="2" stroke-dasharray="5 4" marker-end="url(#arrow)" />
          </g>`;
        })}
        <defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M0 0 L10 5 L0 10 z" fill=${C.primaryDark} /></marker></defs>
        ${pinned.map(({ iss, n }) => {
          const o = byId[iss.target];
          if (!o) return null;
          const isDone = done.has(iss.id);
          const fill = isDone ? C.primary : iss.impact === "high" ? C.critical : C.warning;
          return html`<g style="cursor:pointer" opacity=${dim(iss.id)} onClick=${() => onSelect && onSelect(iss.id)}>
            <circle cx=${px(o.x)} cy=${pz(o.z)} r="11" fill=${fill} stroke="#fff" stroke-width="2.5" />
            <text x=${px(o.x)} y=${pz(o.z) + 4} text-anchor="middle" font-size="11" font-weight="800" fill="#fff">${isDone ? "✓" : n + 1}</text>
          </g>`;
        })}
      </svg>
    </div>`;
}
