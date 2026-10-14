// The Twins, Doctor and Shop tabs.
import { html, useEffect, useRef, useState } from "../vendor/preact-htm.mjs";
import { t, Fmt, isZh } from "./i18n.js";
import { api } from "./api.js";
import { C, Card, HoldToConfirm, Icon, Marker, TopBar, UndoBar } from "./ui.js";
import { TwinMap } from "./map.js";
import { LanguageToggle } from "./intake.js";
import { state, set, useStore, rediagnose, updateShop, reset, changeLanguage } from "./store.js";

// ---------- Twins ----------
export function TwinsTab() {
  const { shop, diagnosis: d } = useStore();
  const [filter, setFilter] = useState("survivor");
  const [selected, setSelected] = useState(null);
  const rows = d.twins.filter((x) => x.status === filter).sort((a, b) => b.similarity - a.similarity);
  const select = (id) => {
    const tw = d.twins.find((x) => x.id === id);
    if (tw && tw.status !== filter && tw.status !== "temporarily_closed") setFilter(tw.status);
    setSelected(id);
    setTimeout(() => document.getElementById("twin-" + id)?.scrollIntoView({ behavior: "smooth", block: "center" }), 50);
  };
  return html`
    <div>
      <${TopBar} title=${t("Twin shops")} />
      <${TwinMap} shop=${shop} twins=${d.twins} selected=${selected} onSelect=${select} height=${240} />
      <div class="screen stack">
        <div class="segmented">
          <button class=${filter === "survivor" ? "on" : ""} onClick=${() => setFilter("survivor")}>${t("Survivors (%lld)", d.comparison.survivor_count)}</button>
          <button class=${filter === "closed" ? "on" : ""} onClick=${() => setFilter("closed")}>${t("Closed (%lld)", d.comparison.closed_count)}</button>
        </div>
        <div class="caption">${t("Most similar first")}</div>
        ${rows.length === 0 && html`<div class="secondary">${filter === "survivor" ? t("No open twins found.") : t("No closed twins found.")}</div>`}
        ${rows.map((tw) => html`
          <div id=${"twin-" + tw.id} class="stack-sm" style=${{ gap: "6px", padding: "10px", borderRadius: "12px", background: selected === tw.id ? C.primarySoft : "transparent" }}>
            <div class="row"><${Marker} kind=${tw.status === "survivor" ? "survivor" : "closed"} />
              <b class="spacer" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${tw.name}</b>
              <span class="caption" style="color:#0a7a45;font-weight:700">${t("%lld%% match", Math.round(tw.similarity * 100))}</span></div>
            <div class="row caption" style="flex-wrap:wrap;gap:12px">
              ${tw.rating != null && html`<span>★ ${tw.rating.toFixed(1)}</span>`}
              ${tw.review_count != null && html`<span>${tw.review_count} 💬</span>`}
              ${tw.price_level != null && html`<span>${"$".repeat(Math.max(1, tw.price_level))}</span>`}
              ${tw.distance_m != null && html`<span>${Fmt.meters(tw.distance_m)}</span>`}
              ${tw.weekly_hours != null && html`<span>${t("%lldh/wk", Math.round(tw.weekly_hours))}</span>`}
            </div>
            ${tw.closed_note && html`<div class="caption">${tw.closed_note}</div>`}
            ${tw.source_url && html`<a class="caption link" href=${tw.source_url} target="_blank" rel="noopener">${t("Source")}</a>`}
          </div>`)}
      </div>
    </div>`;
}

// ---------- Doctor ----------
const SUGGESTIONS = ["Why is my score this low?", "What did the survivors do differently?", "What if I raise prices 10%?",
  "Should I open longer hours?", "How can I ease my rent pressure?"];
const TOOL_STATUS = { get_diagnosis: "Reviewing your check-up…", list_twins: "Looking at your twin shops…",
  what_if: "Running the numbers…", get_shop_experience: "Looking at your shop check…" };

/** Escape, then allow **bold** — enough for the Doctor's short replies. */
const rich = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");

export function DoctorTab() {
  const s = useStore();
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [activity, setActivity] = useState(null);
  const end = useRef(null);
  useEffect(() => { end.current?.scrollIntoView({ block: "end" }); }, [s.chat.length, s.chat[s.chat.length - 1]?.content, activity]);

  const send = async (text) => {
    text = text.trim();
    if (!text || busy) return;
    setDraft("");
    const history = [...state.chat, { role: "user", content: text }];
    set({ chat: [...history, { role: "assistant", content: "" }] });
    setBusy(true);
    setActivity(t("Thinking…"));
    const append = (piece) => {
      const chat = [...state.chat];
      chat[chat.length - 1] = { ...chat[chat.length - 1], content: chat[chat.length - 1].content + piece };
      set({ chat });
    };
    try {
      await api.askDoctor(state.shop.id, history, (ev) => {
        if (ev.type === "text") { setActivity(null); append(ev.text); }
        else if (ev.type === "tool") setActivity(t(TOOL_STATUS[ev.name] || "Working…"));
        else if (ev.type === "error") append((state.chat[state.chat.length - 1].content ? "\n\n" : "") + ev.message);
      });
    } catch (e) {
      append(e.message);
    }
    if (!state.chat[state.chat.length - 1].content) set({ chat: state.chat.slice(0, -1) });
    setBusy(false);
    setActivity(null);
  };

  return html`
    <div>
      <${TopBar} title=${t("Doctor")} />
      <div class="chat">
        <div class="row-top">
          <span style="width:36px;height:36px;border-radius:50%;background:#0e9f5b;color:#fff;display:grid;place-items:center;flex:none"><${Icon} name="stethoscope" /></span>
          <div><b>ShopDoctor</b><div class="secondary">${t("I've read your check-up. Ask me about your score, your twins, or try a what-if.")}</div></div>
        </div>
        ${s.chat.map((m) => html`<div class=${"bubble " + m.role} dangerouslySetInnerHTML=${{ __html: rich(m.content) }} />`)}
        ${activity && html`<div class="row caption"><span class="spinner" />${activity}</div>`}
        ${s.chat.length === 0 && html`<div class="chips">${SUGGESTIONS.map((q) => html`<button class="chip" onClick=${() => send(t(q))}>${t(q)}</button>`)}</div>`}
        <div ref=${end} />
      </div>
      <form class="composer" onSubmit=${(e) => { e.preventDefault(); send(draft); }}>
        <textarea class="field" rows="1" placeholder=${t("Ask the Doctor…")} value=${draft}
                  onInput=${(e) => setDraft(e.target.value)}
                  onKeyDown=${(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(draft); } }} />
        <button class="send" type="submit" disabled=${busy || !draft.trim()} aria-label=${t("Send")}><${Icon} name="send" stroke=${2.6} /></button>
      </form>
    </div>`;
}

// ---------- Shop ----------
export function ShopTab() {
  const s = useStore();
  const shop = s.shop;
  const [editing, setEditing] = useState(false);
  const [pendingReset, setPendingReset] = useState(false);
  const c = shop.costs;
  const row = (k, v) => html`<div class="row" style="justify-content:space-between;padding:6px 0"><span class="secondary">${k}</span><b>${v}</b></div>`;
  return html`
    <div>
      <${TopBar} title=${t("My shop")} />
      <div class="screen soft stack">
        <${Card}>
          <h2 class="headline">${t("Shop")}</h2>
          ${row(t("Name"), shop.name)}${row(t("Type"), t(shop.category))}${row(t("District"), t(shop.district))}
          ${shop.address && row(t("Address"), shop.address)}
          ${shop.weekly_hours != null && row(t("Open hours"), t("%lld h/week", Math.round(shop.weekly_hours)))}
        </${Card}>
        <${Card}>
          <h2 class="headline">${t("Monthly costs")}</h2>
          ${row(t("Rent"), Fmt.hkd(c.rent, false))}${row(t("Staff"), Fmt.hkd(c.staff, false))}${row(t("Ingredients & stock"), Fmt.hkd(c.ingredients, false))}
          ${row(t("Utilities"), Fmt.hkd(c.utilities, false))}${row(t("Other"), Fmt.hkd(c.other, false))}
          <button class="btn-secondary" onClick=${() => setEditing(true)}>${t("Update numbers")}</button>
        </${Card}>
        <${Card}>
          <h2 class="headline">${t("Language")}</h2>
          <div class="segmented">
            <button class=${s.lang === "en" ? "on" : ""} onClick=${() => changeLanguage("en")}>English</button>
            <button class=${s.lang === "zh-HK" ? "on" : ""} onClick=${() => changeLanguage("zh-HK")}>中文</button>
          </div>
          <div class="caption">${t("Generated text switches language the next time the check-up runs.")}</div>
          <button class="btn-secondary" onClick=${rediagnose}><${Icon} name="refresh" /> ${t("Re-run diagnosis")}</button>
        </${Card}>
        <${HoldToConfirm} label=${t("Hold to start a new shop")} onConfirm=${() => setPendingReset(true)} />
        <div class="caption center">${t("Clears this shop's check-up from this phone.")}</div>
      </div>
      ${editing && html`<${EditNumbers} shop=${shop} onClose=${() => setEditing(false)} />`}
      ${pendingReset && html`<${UndoBar} message=${t("Starting a new shop…")} onUndo=${() => setPendingReset(false)} onCommit=${() => { setPendingReset(false); reset(); }} />`}
    </div>`;
}

function EditNumbers({ shop, onClose }) {
  const [input, setInput] = useState(() => ({
    name: shop.name, category: shop.category, district: shop.district, address: shop.address, lat: shop.lat, lng: shop.lng,
    opened_year: shop.opened_year, weekly_hours: shop.weekly_hours, monthly_revenue: shop.monthly_revenue.map((m) => ({ ...m })), costs: { ...shop.costs },
  }));
  const num = (v) => +String(v).replace(/[^\d.]/g, "") || 0;
  const field = (label, value, onChange) => html`
    <div class="money-row"><span class="lbl">${label}</span><input class="field" inputmode="numeric" value=${value || ""} onInput=${(e) => onChange(num(e.target.value))} /></div>`;
  const thisMonth = new Date().toISOString().slice(0, 7);
  return html`
    <div class="sheet-backdrop" onClick=${(e) => e.target === e.currentTarget && onClose()}>
      <div class="sheet stack">
        <div class="row"><button class="link" onClick=${onClose}>${t("Cancel")}</button><b class="spacer center">${t("Update numbers")}</b>
          <button class="link" onClick=${() => { onClose(); updateShop(input); }}>${t("Save & re-check")}</button></div>
        <h3 class="headline">${t("Monthly revenue")}</h3>
        ${input.monthly_revenue.map((m, i) => field(Fmt.month(m.month, true), m.amount, (v) => {
          const mr = [...input.monthly_revenue]; mr[i] = { ...m, amount: v }; setInput({ ...input, monthly_revenue: mr });
        }))}
        ${!input.monthly_revenue.some((m) => m.month === thisMonth) && html`
          <button class="btn-secondary" onClick=${() => setInput({ ...input, monthly_revenue: [...input.monthly_revenue, { month: thisMonth, amount: 0 }] })}>${t("Add this month")}</button>`}
        <h3 class="headline">${t("Monthly costs")}</h3>
        ${[["rent", t("Rent")], ["staff", t("Staff")], ["ingredients", t("Ingredients & stock")], ["utilities", t("Utilities")], ["other", t("Other")]].map(([k, label]) =>
          field(label, input.costs[k], (v) => setInput({ ...input, costs: { ...input.costs, [k]: v } })))}
      </div>
    </div>`;
}
