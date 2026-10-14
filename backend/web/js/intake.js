// The four-step check-up form (web counterpart of Onboarding/IntakeFlow.swift).
import { html, useState } from "../vendor/preact-htm.mjs";
import { t, Fmt, getLang } from "./i18n.js";
import { toJpeg } from "./api.js";
import { Card, Icon, Pill, SectionTitle } from "./ui.js";
import { PinPicker, searchAddress } from "./map.js";
import { submit, changeLanguage, useStore } from "./store.js";

const CATEGORIES = ["Cha chaan teng", "Noodle shop", "Café", "Bakery", "Bubble tea", "Dessert shop",
  "Restaurant", "Hair salon", "Nail salon", "Convenience store", "Boutique", "Pharmacy"];
const DISTRICTS = ["Central", "Sheung Wan", "Wan Chai", "Causeway Bay", "North Point", "Quarry Bay", "Aberdeen",
  "Tsim Sha Tsui", "Jordan", "Yau Ma Tei", "Mong Kok", "Prince Edward", "Sham Shui Po", "Kowloon City", "To Kwa Wan",
  "Kwun Tong", "Wong Tai Sin", "Tsuen Wan", "Kwai Chung", "Sha Tin", "Tai Po", "Tuen Mun", "Yuen Long",
  "Tseung Kwan O", "Tung Chung"];
const STEPS = ["Your shop", "Photos", "Money", "Location"];

/** The last six complete months, oldest first ("YYYY-MM"). */
function recentMonths() {
  const out = [], now = new Date();
  for (let i = 6; i >= 1; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    out.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
  }
  return out;
}

export function LanguageToggle() {
  const s = useStore();
  return html`
    <div class="lang-toggle" role="group" aria-label=${t("Language")}>
      ${[["en", "EN", "English"], ["zh-HK", "中", "中文"]].map(([code, short, name]) => html`
        <button class=${s.lang === code ? "on" : ""} onClick=${() => changeLanguage(code)} aria-label=${name}>${short}</button>`)}
    </div>`;
}

export function Intake() {
  useStore();
  const [step, setStep] = useState(0);
  const [d, setD] = useState({
    name: "", category: "", district: "Mong Kok", openedYear: new Date().getFullYear() - 3, weeklyHours: 70,
    menu: [], front: [], records: [], revenue: {}, costs: { rent: 0, staff: 0, ingredients: 0, utilities: 0, other: 0 },
    coord: null, address: null,
  });
  const up = (patch) => setD((x) => ({ ...x, ...patch }));
  const canContinue = step === 0 ? d.name.trim() && d.category : step === 3 ? !!d.coord : true;
  const last = step === STEPS.length - 1;

  const run = () => {
    const months = recentMonths();
    const input = {
      name: d.name.trim(), category: d.category, district: d.district, address: d.address,
      lat: d.coord.lat, lng: d.coord.lng, opened_year: d.openedYear, weekly_hours: d.weeklyHours,
      monthly_revenue: months.filter((m) => d.revenue[m] > 0).map((m) => ({ month: m, amount: d.revenue[m] })),
      costs: d.costs,
    };
    const uploads = [
      ...d.menu.map((blob, i) => ({ kind: "menu_photos", blob, name: `menu-${i}.jpg` })),
      ...d.front.map((blob, i) => ({ kind: "shopfront_photos", blob, name: `front-${i}.jpg` })),
      ...d.records.map((blob, i) => ({ kind: "financial_docs", blob, name: blob.type === "application/pdf" ? `records-${i}.pdf` : `records-${i}.jpg` })),
    ];
    submit(input, uploads);
  };

  return html`
    <div>
      <div class="screen no-tabs">
        <div class="stack-sm" style="margin-bottom:20px">
          <div class="row">
            <span style="color:#0e9f5b"><${Icon} name="cross" /></span>
            <b class="spacer">ShopDoctor</b>
            <span class="caption">${t("Step %lld of %lld", step + 1, STEPS.length)}</span>
            <${LanguageToggle} />
          </div>
          <h1 class="title">${t(STEPS[step])}</h1>
          <div class="steps-bar">${STEPS.map((_, i) => html`<span class=${i <= step ? "on" : ""} />`)}</div>
        </div>
        <div class="stack fade-in" key=${step}>
          ${step === 0 && html`<${Basics} d=${d} up=${up} />`}
          ${step === 1 && html`<${Photos} d=${d} up=${up} />`}
          ${step === 2 && html`<${Money} d=${d} up=${up} />`}
          ${step === 3 && html`<${Location} d=${d} up=${up} />`}
        </div>
      </div>
      <div class="footer-bar">
        <div class="row">
          ${step > 0 && html`<button class="btn-secondary" style="flex:0 0 110px" onClick=${() => setStep(step - 1)}>${t("Back")}</button>`}
          <button class="btn-primary" disabled=${!canContinue} onClick=${() => (last ? run() : setStep(step + 1))}>
            ${last ? t("Run diagnosis") : t("Continue")} <${Icon} name=${last ? "stethoscope" : "arrowRight"} />
          </button>
        </div>
      </div>
    </div>`;
}

function Basics({ d, up }) {
  return html`
    <p class="secondary" style="margin:0">${t("Tell us the basics. We'll use them to find shops like yours nearby.")}</p>
    <div class="stack-sm">
      <label class="label" for="name">${t("Shop name")}</label>
      <input id="name" class="field" placeholder=${t("e.g. Wing Kee Café")} value=${d.name} onInput=${(e) => up({ name: e.target.value })} />
      <div class="label">${t("What kind of shop?")}</div>
      <div class="chips">${CATEGORIES.map((c) => html`
        <button class=${"chip" + (d.category === c ? " on" : "")} onClick=${() => up({ category: c })}>${t(c)}</button>`)}</div>
      <label class="label" for="district">${t("District")}</label>
      <select id="district" class="field" value=${d.district} onChange=${(e) => up({ district: e.target.value })}>
        ${DISTRICTS.map((x) => html`<option value=${x}>${t(x)}</option>`)}
      </select>
      <label class="label" for="opened">${t("Opened in")}</label>
      <input id="opened" class="field" type="number" min="1950" max=${new Date().getFullYear()} value=${d.openedYear}
             onInput=${(e) => up({ openedYear: +e.target.value })} />
      <label class="label" for="hours">${t("Open hours per week: %lld", d.weeklyHours)}</label>
      <input id="hours" type="range" min="20" max="168" value=${d.weeklyHours} onInput=${(e) => up({ weeklyHours: +e.target.value })} />
    </div>`;
}

function PhotoSlot({ title, subtitle, icon, photos, onChange, max, accept = "image/*" }) {
  const add = async (e) => {
    const files = [...e.target.files].slice(0, max);
    e.target.value = "";
    const blobs = [];
    for (const f of files) { const b = await toJpeg(f); if (b) blobs.push(b); }
    onChange([...photos, ...blobs].slice(0, max));
  };
  return html`
    <${Card}>
      <div class="row">
        <div class="spacer"><${SectionTitle} title=${title} subtitle=${subtitle} icon=${icon} /></div>
        ${photos.length > 0 && html`<${Pill} text=${String(photos.length)} icon="check" />`}
      </div>
      <div class="row" style="overflow-x:auto">
        <label class="thumb" style="cursor:pointer">
          <div class="center"><${Icon} name="plus" /><div class="caption" style="color:inherit">${t("Add")}</div></div>
          <input type="file" accept=${accept} multiple hidden onChange=${add} />
        </label>
        ${photos.map((b, i) => html`
          <div class="thumb" style="position:relative">
            ${b.type === "application/pdf" ? html`<${Icon} name="doc" size=${28} />` : html`<img src=${URL.createObjectURL(b)} alt="" />`}
            <button class="icon-btn" style="position:absolute;top:4px;right:4px;width:22px;height:22px;background:rgba(255,255,255,.9)"
                    onClick=${() => onChange(photos.filter((_, j) => j !== i))} aria-label=${t("Remove")}><${Icon} name="x" size=${12} /></button>
          </div>`)}
      </div>
    </${Card}>`;
}

function Photos({ d, up }) {
  return html`
    <p class="secondary" style="margin:0">${t("Photos help the Doctor read your menu prices and see your shop the way a passer-by does. All optional.")}</p>
    <${PhotoSlot} title=${t("Menu")} subtitle=${t("Every page, straight on")} icon="menu" max=${6} photos=${d.menu} onChange=${(menu) => up({ menu })} />
    <${PhotoSlot} title=${t("Shopfront")} subtitle=${t("From across the street, in daylight")} icon="store" max=${3} photos=${d.front} onChange=${(front) => up({ front })} />
    <${PhotoSlot} title=${t("Revenue & cost records")} subtitle=${t("A P&L, ledger page or POS report. Photo or PDF.")} icon="doc" max=${4}
                  accept="image/*,application/pdf" photos=${d.records} onChange=${(records) => up({ records })} />`;
}

function MoneyRow({ label, value, onChange }) {
  return html`
    <div class="money-row">
      <span class="lbl">${label}</span>
      <span class="caption muted">HK$</span>
      <input class="field" inputmode="numeric" placeholder="0" value=${value || ""}
             onInput=${(e) => onChange(+e.target.value.replace(/[^\d.]/g, "") || 0)} aria-label=${label} />
    </div>`;
}

function Money({ d, up }) {
  const setCost = (k) => (v) => up({ costs: { ...d.costs, [k]: v } });
  return html`
    <p class="secondary" style="margin:0">${t("Rough numbers are fine. If you attached records, leave these blank and we'll read them.")}</p>
    <${Card}>
      <${SectionTitle} title=${t("Monthly revenue")} subtitle=${t("Takings for each month, HKD")} icon="chart" />
      ${recentMonths().map((m) => html`<${MoneyRow} label=${Fmt.month(m, true)} value=${d.revenue[m]} onChange=${(v) => up({ revenue: { ...d.revenue, [m]: v } })} />`)}
    </${Card}>
    <${Card}>
      <${SectionTitle} title=${t("Monthly costs")} subtitle=${t("A typical month, HKD")} icon="card" />
      <${MoneyRow} label=${t("Rent")} value=${d.costs.rent} onChange=${setCost("rent")} />
      <${MoneyRow} label=${t("Staff wages & MPF")} value=${d.costs.staff} onChange=${setCost("staff")} />
      <${MoneyRow} label=${t("Ingredients & stock")} value=${d.costs.ingredients} onChange=${setCost("ingredients")} />
      <${MoneyRow} label=${t("Utilities")} value=${d.costs.utilities} onChange=${setCost("utilities")} />
      <${MoneyRow} label=${t("Other")} value=${d.costs.other} onChange=${setCost("other")} />
    </${Card}>`;
}

function Location({ d, up }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [focus, setFocus] = useState(null);
  const [locating, setLocating] = useState(false);

  const search = async (e) => {
    e.preventDefault();
    if (query.trim()) setResults(await searchAddress(query, getLang()).catch(() => []));
  };
  const pick = (r) => { up({ coord: { lat: r.lat, lng: r.lng }, address: r.address }); setFocus({ lat: r.lat, lng: r.lng }); setResults([]); };
  const locate = () => {
    if (!navigator.geolocation) return;
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (p) => { setLocating(false); pick({ lat: p.coords.latitude, lng: p.coords.longitude, address: d.address }); },
      () => setLocating(false), { enableHighAccuracy: true, timeout: 10000 });
  };

  return html`
    <p class="secondary" style="margin:0">${t("Drop the pin on your door. Twins are searched within about 1.5 km.")}</p>
    <form class="row" onSubmit=${search}>
      <input class="field" type="search" placeholder=${t("Search address or building")} value=${query} onInput=${(e) => setQuery(e.target.value)} />
    </form>
    ${results.map((r) => html`
      <button style="text-align:left" onClick=${() => pick(r)}>
        <div style="font-weight:650">${r.name}</div><div class="caption" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${r.address}</div>
      </button>`)}
    <${PinPicker} value=${d.coord} focus=${focus} onChange=${(coord) => up({ coord })} />
    <button class="btn-secondary" onClick=${locate} disabled=${locating}><${Icon} name="locate" /> ${t("Use my current location")}</button>
    ${d.address && html`<div class="row caption"><${Icon} name="pin" size=${14} />${d.address}</div>`}`;
}
