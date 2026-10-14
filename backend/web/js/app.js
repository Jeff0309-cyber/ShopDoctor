// ShopDoctor web: root view and tab bar (web counterpart of App/ShopDoctorApp.swift).
import { html, render } from "../vendor/preact-htm.mjs";
import { loadLanguage, t } from "./i18n.js";
import { Icon } from "./ui.js";
import { Intake } from "./intake.js";
import { ThinkingScreen, FailureScreen } from "./thinking.js";
import { PrescriptionReveal } from "./slip.js";
import { Dashboard, DashboardPage } from "./dashboard.js";
import { TwinsTab, DoctorTab, ShopTab } from "./tabs.js";
import { ExperiencePage } from "./experience.js";
import { useStore, start, finishDiagnosing, openCheckup, rediagnose, reset, switchTab } from "./store.js";

const TABS = [["dashboard", "Check-up", "heart"], ["twins", "Twins", "building"], ["doctor", "Doctor", "stethoscope"], ["shop", "Shop", "store"]];

function TabBar({ tab }) {
  return html`
    <nav class="tabbar">
      ${TABS.map(([key, label, icon]) => html`
        <button class=${tab === key ? "on" : ""} onClick=${() => switchTab(key)} aria-current=${tab === key ? "page" : null}>
          <${Icon} name=${icon} size=${22} />${t(label)}
        </button>`)}
    </nav>`;
}

function Main() {
  const s = useStore();
  const page = s.pages[s.pages.length - 1];
  let body;
  if (page) body = page.view === "experience" ? html`<${ExperiencePage} />` : html`<${DashboardPage} page=${page} />`;
  else if (s.tab === "twins") body = html`<${TwinsTab} />`;
  else if (s.tab === "doctor") body = html`<${DoctorTab} />`;
  else if (s.tab === "shop") body = html`<${ShopTab} />`;
  else body = html`<${Dashboard} />`;
  return html`<div key=${s.tab + s.pages.length}>${body}<${TabBar} tab=${s.tab} /></div>`;
}

function App() {
  const s = useStore();
  let screen;
  switch (s.phase) {
    case "loading": screen = html`<div class="boot"><div class="boot-cross" /></div>`; break;
    case "intake": screen = html`<${Intake} />`; break;
    case "diagnosing": screen = html`<${ThinkingScreen} ready=${s.diagnosisReady} onDone=${finishDiagnosing} />`; break;
    case "prescription": screen = html`<${PrescriptionReveal} shop=${s.shop} diagnosis=${s.diagnosis}
                                         onOpen=${() => openCheckup()} onAskDoctor=${() => openCheckup("doctor")} />`; break;
    case "failed": screen = html`<${FailureScreen} message=${s.error} onRetry=${() => (s.shop ? rediagnose() : reset())} onStartOver=${reset} />`; break;
    default: screen = html`<${Main} />`;
  }
  // The store re-renders the whole tree on a language switch, so nothing is remounted and form input survives.
  return html`<div class="app">${screen}</div>`;
}

(async () => {
  let saved = null;
  try { saved = localStorage.getItem("language"); } catch {}
  const lang = await loadLanguage(saved);
  document.documentElement.lang = lang === "zh-HK" ? "zh-Hant-HK" : "en";
  render(html`<${App} />`, document.getElementById("root"));
  start();
})();
