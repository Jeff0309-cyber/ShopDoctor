// Dashboard cards and charts (web counterpart of Dashboard/ChartCards.swift).
import { html, useState } from "../vendor/preact-htm.mjs";
import { t, Fmt, lowered } from "./i18n.js";
import { C, Card, Icon, LegendItem, Pill, ScoreBar, ScoreRing, SectionTitle, Stat, StatusPill, Bullets, bandFor } from "./ui.js";
import { TwinMap } from "./map.js";

const ICON = { location: "pin", pricing: "card", menu: "menu", visibility: "eye", financials: "banknote", market: "chart" };

export function HealthCard({ health }) {
  const weakest = [...health.subscores].sort((a, b) => a.score - b.score)[0];
  return html`
    <${Card}>
      <div class="row" style="gap:20px">
        <${ScoreRing} score=${health.overall} />
        <div class="stack-sm">
          <div class="caption">${t("Health Score")}</div>
          <${StatusPill} score=${health.overall} />
          ${weakest && html`<div>${t("Weakest: %@", lowered(weakest.label))}</div>`}
        </div>
      </div>
      <hr class="divider" />
      <div class="grid2" style="gap:14px">
        ${health.subscores.map((s) => html`
          <div class="stack-sm" style="gap:6px">
            <div class="row caption" style="gap:6px"><${Icon} name=${ICON[s.key] || "info"} size=${14} /><span class="spacer">${s.label}</span>
              <b class="num" style="color:#0f172a">${Math.round(s.score)}</b></div>
            <${ScoreBar} score=${s.score} />
          </div>`)}
      </div>
    </${Card}>`;
}

export function SubscoreDetailCard({ health }) {
  return html`
    <${Card}>
      <${SectionTitle} title=${t("How the score is built")} subtitle=${t("Weighted sub-scores, 0–100")} icon="list" />
      ${[...health.subscores].sort((a, b) => a.score - b.score).map((s) => html`
        <div class="stack-sm" style="gap:4px">
          <div class="row"><b class="spacer row" style="gap:6px"><${Icon} name=${ICON[s.key] || "info"} size=${15} />${s.label}</b>
            <span class="caption">${t("%lld · %lld%% weight", Math.round(s.score), Math.round(s.weight * 100))}</span></div>
          <div class="caption">${s.explanation}</div>
        </div>`)}
    </${Card}>`;
}

export function KPIRow({ financials: f, forecast: fc }) {
  return html`
    <div class="grid2">
      <${Stat} label=${t("Monthly revenue")} value=${Fmt.hkd(f.revenue)} detail=${t("Break-even %@", Fmt.hkd(fc.break_even_revenue))} />
      <${Stat} label=${t("Net margin")} value=${Fmt.pct(f.net_margin)}
               detail=${f.net_profit >= 0 ? t("%@ profit", Fmt.hkd(f.net_profit)) : t("%@ loss", Fmt.hkd(-f.net_profit))}
               tint=${f.net_profit >= 0 ? C.primaryDark : C.critical} />
      <${Stat} label=${t("Rent / revenue")} value=${Fmt.pct(f.rent_ratio)}
               detail=${f.rent_ratio <= 0.2 ? t("Within HK norm") : t("Above 20% norm")} tint=${f.rent_ratio <= 0.2 ? C.primaryDark : C.warning} />
      <${Stat} label=${t("Next 12 months")} value=${Fmt.hkd(fc.annual_expected)}
               detail=${t("Trend %@/mo", Fmt.pct(fc.trend_pct_monthly, true))} tint=${fc.trend_pct_monthly >= 0 ? C.primaryDark : C.critical} />
    </div>`;
}

// ---------- forecast ----------
export function ForecastCard({ forecast }) {
  const [sel, setSel] = useState(null);
  const [showAssumptions, setShowAssumptions] = useState(false);
  const pts = forecast.points;
  if (!pts.length) return null;
  const W = 340, H = 210, L = 52, R = 8, T = 22, B = 24;
  const lastActual = pts.map((p) => p.is_actual).lastIndexOf(true);
  const band = pts.filter((p, i) => !p.is_actual || i === lastActual);
  const values = pts.flatMap((p) => [p.low, p.high]).concat(forecast.break_even_revenue ? [forecast.break_even_revenue] : []);
  let lo = Math.min(...values), hi = Math.max(...values);
  const pad = (hi - lo) * 0.08 || hi * 0.1 || 1; lo = Math.max(0, lo - pad); hi += pad;
  const x = (i) => L + (i / Math.max(1, pts.length - 1)) * (W - L - R);
  const y = (v) => T + (1 - (v - lo) / (hi - lo)) * (H - T - B);
  const idx = (p) => pts.indexOf(p);
  const line = (arr, key) => arr.map((p, i) => `${i ? "L" : "M"}${x(idx(p)).toFixed(1)},${y(p[key]).toFixed(1)}`).join(" ");
  const area = band.length ? line(band, "high") + " " + [...band].reverse().map((p) => `L${x(idx(p)).toFixed(1)},${y(p.low).toFixed(1)}`).join(" ") + " Z" : "";
  const ticks = [0, 1, 2, 3].map((k) => lo + ((hi - lo) * k) / 3);
  const actual = pts.filter((p) => p.is_actual);

  const pick = (e) => {
    const box = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - box.left) / box.width) * W;
    const i = Math.round(((px - L) / (W - L - R)) * (pts.length - 1));
    setSel(Math.max(0, Math.min(pts.length - 1, i)));
  };
  const s = sel != null ? pts[sel] : null;

  return html`
    <${Card}>
      <div class="row-top">
        <div class="spacer"><${SectionTitle} title=${t("Revenue forecast")} subtitle=${t("Monthly, HKD · shaded band ≈ 80% of outcomes")} icon="chart" /></div>
        <button class="icon-btn" onClick=${() => setShowAssumptions(!showAssumptions)} aria-label=${t("Forecast assumptions")}><${Icon} name="info" /></button>
      </div>
      <div class="chart" style="position:relative">
        <svg viewBox=${`0 0 ${W} ${H}`} onPointerMove=${pick} onPointerDown=${pick} onPointerLeave=${() => setSel(null)}
             role="img" aria-label=${t("Revenue forecast")}>
          ${ticks.map((v) => html`
            <line x1=${L} x2=${W - R} y1=${y(v)} y2=${y(v)} stroke=${C.hairline} />
            <text x=${L - 6} y=${y(v) + 4} text-anchor="end" font-size="10" fill=${C.ink2}>${Fmt.hkd(v)}</text>`)}
          ${pts.map((p, i) => i % 3 === 0 && html`<text x=${x(i)} y=${H - 6} text-anchor="middle" font-size="10" fill=${C.ink2}>${Fmt.month(p.month)}</text>`)}
          <path d=${area} fill=${C.primary} opacity="0.14" />
          <path d=${line(band, "expected")} fill="none" stroke=${C.primary} stroke-width="2" stroke-dasharray="5 3" />
          ${actual.length > 1 && html`<path d=${line(actual, "expected")} fill="none" stroke=${C.ink} stroke-width="2" />`}
          ${actual.map((p) => html`<circle cx=${x(idx(p))} cy=${y(p.expected)} r="4" fill=${C.ink} stroke="#fff" stroke-width="2" />`)}
          ${forecast.break_even_revenue > 0 && html`
            <line x1=${L} x2=${W - R} y1=${y(forecast.break_even_revenue)} y2=${y(forecast.break_even_revenue)} stroke=${C.muted} stroke-dasharray="2 3" />
            <text x=${W - R - 2} y=${y(forecast.break_even_revenue) - 5} text-anchor="end" font-size="10" fill=${C.ink2}
                  stroke="#fff" stroke-width="3" paint-order="stroke">${t("Break-even")}</text>`}
          ${s && html`<line x1=${x(sel)} x2=${x(sel)} y1=${T} y2=${H - B} stroke=${C.hairline} stroke-width="1.5" />
                     <circle cx=${x(sel)} cy=${y(s.expected)} r="5" fill=${s.is_actual ? C.ink : C.primary} stroke="#fff" stroke-width="2" />`}
        </svg>
        ${s && html`
          <div class="tip" style=${{ left: Math.min(80, Math.max(20, (x(sel) / W) * 100)) + "%", top: "0" }}>
            <div class="caption">${Fmt.month(s.month, true)}</div>
            <b class="num">${Fmt.hkd(s.expected, false)}</b>
            <div class="caption">${s.is_actual ? t("Actual") : `${Fmt.hkd(s.low)} – ${Fmt.hkd(s.high)}`}</div>
          </div>`}
      </div>
      <div class="legend">
        <span><svg width="16" height="10"><line x1="0" x2="16" y1="5" y2="5" stroke=${C.ink} stroke-width="2" /></svg>${t("Actual")}</span>
        <span><svg width="16" height="10"><line x1="0" x2="16" y1="5" y2="5" stroke=${C.primary} stroke-width="2" stroke-dasharray="4 2" /></svg>${t("Expected")}</span>
        <span><span style="display:inline-block;width:14px;height:10px;border-radius:2px;background:rgba(14,159,91,.25)" />${t("Likely range")}</span>
      </div>
      ${showAssumptions && html`<${Bullets} items=${forecast.assumptions} />`}
    </${Card}>`;
}

// ---------- survivors vs closed ----------
function FindingTrack({ f }) {
  const vals = [f.survivors_avg, f.closed_avg, f.owner].filter((v) => v != null);
  const lo0 = Math.min(...vals), hi0 = Math.max(...vals);
  const pad = Math.max((hi0 - lo0) * 0.25, Math.abs(hi0) * 0.05, 0.0001);
  const pos = (v) => ((v - (lo0 - pad)) / (hi0 + pad - (lo0 - pad))) * 100 + "%";
  return html`
    <div class="stack-sm" style="gap:8px" aria-label=${f.message}>
      <div class="row"><b class="spacer">${f.label}</b>
        ${f.verdict === "like_closed" && html`<${Pill} text=${t("Like closed shops")} icon="warning" tint=${C.warning} />`}
        ${f.verdict === "like_survivors" && html`<${Pill} text=${t("Like survivors")} icon="check" tint=${C.primaryDark} />`}
      </div>
      <div class="track">
        ${f.closed_avg != null && html`<span class="mk closed" style=${{ left: pos(f.closed_avg) }} />`}
        ${f.survivors_avg != null && html`<span class="mk survivor" style=${{ left: pos(f.survivors_avg) }} />`}
        ${f.owner != null && html`<span class="mk you" style=${{ left: pos(f.owner) }} />`}
      </div>
      <div class="caption">${f.message}</div>
    </div>`;
}

export function SurvivorsVsClosedCard({ comparison: c }) {
  return html`
    <${Card}>
      <${SectionTitle} title=${t("Survivors vs closed")} icon="building"
        subtitle=${t("%lld still open · %lld closed nearby (%@ closure rate)", c.survivor_count, c.closed_count, Fmt.pct(c.closure_rate))} />
      <div class="legend"><${LegendItem} kind="survivor" label=${t("Survivors avg")} /><${LegendItem} kind="closed" label=${t("Closed avg")} /><${LegendItem} kind="you" label=${t("You")} /></div>
      ${c.findings.length === 0 && html`<div class="secondary">${t("Not enough twin data to compare yet.")}</div>`}
      ${c.findings.map((f) => html`<${FindingTrack} f=${f} />`)}
    </${Card}>`;
}

export function TwinMapCard({ shop, diagnosis }) {
  return html`
    <${Card} flush>
      <div class="stack-sm" style="padding:18px 18px 0">
        <${SectionTitle} title=${t("Your twins on the map")} subtitle=${t("Similar shops within ~1.5 km")} icon="pin" />
        <div class="legend"><${LegendItem} kind="survivor" label=${t("Still open")} /><${LegendItem} kind="closed" label=${t("Closed")} /><${LegendItem} kind="you" label=${t("You")} /></div>
      </div>
      <${TwinMap} shop=${shop} twins=${diagnosis.twins} interactive=${false} />
    </${Card}>`;
}

// ---------- costs ----------
export function CostCard({ financials: f }) {
  const slices = [...f.cost_breakdown].sort((a, b) => b.amount - a.amount);
  const max = slices[0]?.amount || 1;
  return html`
    <${Card}>
      <${SectionTitle} title=${t("Where the money goes")} subtitle=${t("Monthly costs as a share of revenue")} icon="banknote" />
      ${slices.length === 0 ? html`<div class="secondary">${t("Add your monthly costs to see this.")}</div>` : html`
        <div class="bars">
          ${slices.map((s) => html`
            <div class="bar-row">
              <span>${s.category}</span>
              <div class="row" style="gap:8px">
                <div class="bar" style=${{ width: (s.amount / max) * 62 + "%" }} />
                <span class="val">${Fmt.hkd(s.amount)}${f.revenue > 0 ? " · " + Fmt.pct(s.amount / f.revenue) : ""}</span>
              </div>
            </div>`)}
        </div>
        <div class="caption">${t("Total %@ vs revenue %@", Fmt.hkd(f.total_costs), Fmt.hkd(f.revenue))}</div>`}
    </${Card}>`;
}
