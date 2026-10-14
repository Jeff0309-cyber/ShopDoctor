// Summary-first dashboard with tap-through detail pages (web counterpart of Dashboard/DashboardView.swift).
import { html } from "../vendor/preact-htm.mjs";
import { t, Fmt, lowered } from "./i18n.js";
import { C, Card, Icon, ScoreBar, ScoreRing, SectionTitle, StatusPill, Bullets, TopBar } from "./ui.js";
import { HealthCard, SubscoreDetailCard, KPIRow, ForecastCard, SurvivorsVsClosedCard, TwinMapCard, CostCard } from "./charts.js";
import { PrescriptionSlip } from "./slip.js";
import { state, push, back, switchTab, rediagnose, useStore } from "./store.js";
import { doneFor, scanCapable } from "./experience.js";

export function Dashboard() {
  const s = useStore();
  const { shop, diagnosis: d } = s;
  if (!shop || !d) return null;
  const top = d.prescriptions[0];
  return html`
    <div>
      <${TopBar} title=${t("Check-up")} right=${html`<button class="icon-btn" onClick=${rediagnose} aria-label=${t("Re-run diagnosis")}><${Icon} name="refresh" /></button>`} />
      <div class="screen soft stack">
        <div>
          <h1 class="title">${shop.name}</h1>
          <div class="secondary">${t("%@ · %@", t(shop.category), t(shop.district))}</div>
        </div>
        <${Card}>
          <div class="row" style="gap:18px">
            <${ScoreRing} score=${d.health.overall} size=${112} width=${11} />
            <div class="stack-sm">
              <${StatusPill} score=${d.health.overall} />
              <div>${verdict(d.health.overall)}</div>
            </div>
          </div>
        </${Card}>
        ${top && html`
          <${Card}>
            <div class="row caption" style="color:#0a7a45;font-weight:650"><${Icon} name="scope" size=${15} />${t("Today's focus")}</div>
            <h2 class="headline">${top.title}</h2>
            <div class="secondary" style="display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden">${top.detail}</div>
            <button class="link" onClick=${() => push({ view: "prescription" })}>${t("View full prescription")} <${Icon} name="chevronRight" size=${14} stroke=${3} /></button>
          </${Card}>`}
        <h2 class="headline" style="margin-top:4px">${t("Your check-up")}</h2>
        <${Tiles} shop=${shop} d=${d} />
        <${ExperienceEntry} audit=${s.experience} />
        <button class="btn-secondary" onClick=${() => switchTab("doctor")}><${Icon} name="stethoscope" /> ${t("Ask the Doctor what to do next")}</button>
        ${d.data_notes.length > 0 && html`
          <button class="caption row" style="justify-content:center" onClick=${() => push({ view: "about" })}><${Icon} name="info" size=${14} />${t("About this data")}</button>`}
      </div>
    </div>`;
}

const verdict = (score) => score >= 75 ? t("In good shape. Keep doing what works.")
  : score >= 55 ? t("Doing OK, but a few areas need attention.") : t("Showing warning signs seen in shops that closed.");

function Tile({ icon, title, value, caption, tint, onClick }) {
  return html`
    <button class="tile" onClick=${onClick}>
      <div class="row"><span class="ico"><${Icon} name=${icon} size=${16} /></span><span class="spacer" /><span class="muted"><${Icon} name="chevronRight" size=${14} stroke=${3} /></span></div>
      <div class="caption" style="font-weight:650">${title}</div>
      <div class="v">${value}</div>
      <div class="c" style=${{ color: tint }}>${caption}</div>
    </button>`;
}

function Tiles({ shop, d }) {
  const weakest = [...d.health.subscores].sort((a, b) => a.score - b.score)[0];
  const n = d.prescriptions.length;
  return html`
    <div class="grid2">
      <${Tile} icon="pills" title=${t("Prescription")} value=${n === 1 ? t("1 step") : t("%lld steps", n)}
               caption=${t("Signed by the Doctor")} tint=${C.primaryDark} onClick=${() => push({ view: "prescription" })} />
      <${Tile} icon="heart" title=${t("Score breakdown")} value=${weakest ? Math.round(weakest.score) : "–"}
               caption=${weakest ? t("Weakest: %@", lowered(weakest.label)) : ""} tint=${weakest && weakest.score < 55 ? C.critical : weakest && weakest.score < 75 ? C.warning : C.primaryDark}
               onClick=${() => push({ view: "breakdown" })} />
      <${Tile} icon="banknote" title=${t("Money")} value=${Fmt.pct(d.financials.net_margin)}
               caption=${d.financials.net_profit >= 0 ? t("Net margin · profitable") : t("Net margin · losing money")}
               tint=${d.financials.net_profit >= 0 ? C.primaryDark : C.critical} onClick=${() => push({ view: "money" })} />
      <${Tile} icon="chart" title=${t("Forecast")} value=${Fmt.hkd(d.forecast.annual_expected)}
               caption=${t("Next 12 months · %@/mo", Fmt.pct(d.forecast.trend_pct_monthly, true))}
               tint=${d.forecast.trend_pct_monthly >= 0 ? C.primaryDark : C.critical} onClick=${() => push({ view: "forecast" })} />
      <${Tile} icon="building" title=${t("Survivors vs closed")} value=${Fmt.pct(d.comparison.closure_rate)}
               caption=${t("of similar shops nearby closed")} tint=${d.comparison.closure_rate > 0.3 ? C.warning : C.primaryDark}
               onClick=${() => push({ view: "compare" })} />
      <${Tile} icon="eye" title=${t("What we saw")} value=${shop.menu ? shop.menu.item_count : "–"}
               caption=${shop.menu ? t("menu items read") : t("Add menu photos")} tint=${C.ink2} onClick=${() => push({ view: "saw" })} />
    </div>`;
}

function ExperienceEntry({ audit }) {
  return html`
    <button class="entry-card" onClick=${() => push({ view: "experience" })}>
      <span class="ico"><${Icon} name="cube" size=${24} /></span>
      <span class="spacer">
        <div class="headline">${t("Shop experience")}</div>
        <div class="caption">${audit
          ? t("%lld/100 · %lld of %lld fixes done", Math.round(audit.overall), doneFor(audit).size, audit.issues.length)
          : scanCapable() ? t("Scan your shop in 3D and get a step-by-step fix plan") : t("Photograph your shop and get a step-by-step fix plan")}</div>
      </span>
      <span class="muted"><${Icon} name="chevronRight" size=${14} stroke=${3} /></span>
    </button>`;
}

// ---------- detail pages ----------
export function DetailPage({ title, summary, children }) {
  return html`
    <div>
      <${TopBar} title=${title} onBack=${back} />
      <div class="screen soft stack fade-in">
        ${summary && html`<p class="secondary" style="margin:0">${summary}</p>`}
        ${children}
      </div>
    </div>`;
}

export function DashboardPage({ page }) {
  const { shop, diagnosis: d } = state;
  const f = d.financials;
  switch (page.view) {
    case "prescription":
      return html`<${DetailPage} title=${t("Prescription")} summary=${t("The Doctor's top changes, most important first.")}>
        <${PrescriptionSlip} shop=${shop} diagnosis=${d} />
        <button class="btn-secondary" onClick=${() => switchTab("doctor")}><${Icon} name="stethoscope" /> ${t("Ask the Doctor about these")}</button>
      </${DetailPage}>`;
    case "breakdown":
      return html`<${DetailPage} title=${t("Score breakdown")} summary=${t("Six vital signs, weighted into your Health Score. Lowest first.")}>
        <${HealthCard} health=${d.health} /><${SubscoreDetailCard} health=${d.health} />
      </${DetailPage}>`;
    case "money":
      return html`<${DetailPage} title=${t("Money")} summary=${f.net_profit >= 0
          ? t("You keep %@ of every dollar of revenue. Here's where the rest goes.", Fmt.pct(f.net_margin))
          : t("Costs are above revenue by %@ a month. Here's where it goes.", Fmt.hkd(-f.net_profit))}>
        <${KPIRow} financials=${f} forecast=${d.forecast} /><${CostCard} financials=${f} />
      </${DetailPage}>`;
    case "forecast":
      return html`<${DetailPage} title=${t("Forecast")} summary=${t("Where revenue is likely heading if nothing changes. Tap the chart to read a month.")}>
        <${ForecastCard} forecast=${d.forecast} />
      </${DetailPage}>`;
    case "compare": {
      const flagged = d.comparison.findings.filter((x) => x.verdict === "like_closed").length;
      const summary = flagged === 0 ? t("On every measure we could compare, you look like the shops that survived.")
        : flagged === 1 ? t("On 1 measure, you look more like the shops that closed.")
        : t("On %lld measures, you look more like the shops that closed.", flagged);
      return html`<${DetailPage} title=${t("Survivors vs closed")} summary=${summary}>
        <${SurvivorsVsClosedCard} comparison=${d.comparison} /><${TwinMapCard} shop=${shop} diagnosis=${d} />
      </${DetailPage}>`;
    }
    case "saw":
      return html`<${DetailPage} title=${t("What we saw")} summary=${t("What the Doctor read from your photos.")}>
        <${PhotoFindings} shop=${shop} />
      </${DetailPage}>`;
    case "about":
      return html`<${DetailPage} title=${t("About this data")} summary=${t("Where these numbers come from and how far to trust them.")}>
        <${Card}><${Bullets} items=${d.data_notes} /></${Card}>
      </${DetailPage}>`;
    default:
      return null;
  }
}

function PhotoFindings({ shop }) {
  const m = shop.menu, f = shop.shopfront;
  if (!m && !f) return html`<${Card}><div class="secondary">${t("No photos analysed yet. Add menu and shopfront photos in a new check-up.")}</div></${Card}>`;
  return html`
    ${m && html`<${Card}>
      <${SectionTitle} title=${t("Menu")} subtitle=${t("%lld items · clarity %lld/10", m.item_count, Math.round(m.clarity_score))} icon="menu" />
      ${m.avg_price != null && html`<div>${t("Average price %@", Fmt.hkd(m.avg_price, false))}</div>`}
      <${Bullets} items=${m.notes} />
    </${Card}>`}
    ${f && html`<${Card}>
      <${SectionTitle} title=${t("Shopfront")} subtitle=${t("As a passer-by sees it")} icon="store" />
      ${[[t("Signage"), f.signage_score], [t("Visibility"), f.visibility_score], [t("Condition"), f.condition_score], [t("Walk-in appeal"), f.appeal_score]].map(([n, v]) => html`
        <div class="stack-sm" style="gap:4px"><div class="row caption"><span class="spacer">${n}</span><b class="num" style="color:#0f172a">${Math.round(v)}/10</b></div><${ScoreBar} score=${v * 10} /></div>`)}
      <${Bullets} items=${f.observations} />
    </${Card}>`}`;
}
