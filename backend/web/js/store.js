// App state: the web counterpart of App/AppState.swift. A tiny observable store.
import { useEffect, useState } from "../vendor/preact-htm.mjs";
import { api } from "./api.js";
import { setLang, getLang } from "./i18n.js";

const listeners = new Set();
let version = 0;
const ls = {
  get: (k) => { try { return localStorage.getItem(k); } catch { return null; } },
  set: (k, v) => { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch {} },
};

export const state = {
  phase: "loading",          // loading | intake | diagnosing | prescription | ready | failed
  error: "",
  shop: null,
  diagnosis: null,
  diagnosisReady: false,     // the loader resolves, then shows the prescription
  experience: null,
  chat: [],
  tab: "dashboard",          // dashboard | twins | doctor | shop
  pages: [],                 // pushed detail pages: [{ view, ...params }]
  demoMode: false,
  lang: "en",
};

export function set(patch) {
  Object.assign(state, patch);
  version++;
  listeners.forEach((l) => l());
}

export function useStore() {
  const [, force] = useState(0);
  const seen = version;
  useEffect(() => {
    const l = () => force((n) => n + 1);
    listeners.add(l);
    if (version !== seen) l();  // catch up on updates that landed before this effect subscribed
    return () => listeners.delete(l);
  }, []);
  return state;
}

// ---------- navigation (browser back pops detail pages) ----------
export function push(page) {
  history.pushState({ depth: state.pages.length + 1 }, "");
  set({ pages: [...state.pages, page] });
  window.scrollTo(0, 0);
}
export function back() { history.back(); }
window.addEventListener("popstate", () => {
  if (state.pages.length) set({ pages: state.pages.slice(0, -1) });
});
export function switchTab(tab) {
  if (state.pages.length) history.go(-state.pages.length);
  set({ tab, pages: [] });
  window.scrollTo(0, 0);
}

// ---------- lifecycle ----------
export async function start() {
  set({ lang: getLang() });
  try { set({ demoMode: !!(await api.health()).demo_mode }); } catch {}
  const id = ls.get("shopID");
  if (!id) return set({ phase: "intake" });
  let shop;
  try { shop = await api.shop(id); } catch { return set({ phase: "intake" }); }
  set({ shop });
  try { set({ experience: await api.experience(id) }); } catch {}
  try { set({ diagnosis: await api.diagnosis(id), phase: "ready" }); } catch { await rediagnose(); }
}

export async function submit(input, uploads) {
  set({ phase: "diagnosing", diagnosisReady: false, error: "" });
  try {
    const shop = await api.createShop(input, uploads);
    ls.set("shopID", shop.id);
    set({ shop, chat: [], experience: null });
    set({ diagnosis: await api.diagnose(shop.id), diagnosisReady: true });
  } catch (e) {
    set({ phase: "failed", error: e.message });
  }
}

export async function rediagnose() {
  if (!state.shop) return;
  set({ phase: "diagnosing", diagnosisReady: false, error: "", pages: [] });
  try {
    set({ diagnosis: await api.diagnose(state.shop.id), diagnosisReady: true });
  } catch (e) {
    set({ phase: "failed", error: e.message });
  }
}

export const finishDiagnosing = () => set({ phase: "prescription" });
export const openCheckup = (tab = "dashboard") => set({ phase: "ready", tab, pages: [] });

export async function updateShop(input) {
  try {
    set({ shop: await api.updateShop(state.shop.id, input) });
    await rediagnose();
  } catch (e) {
    set({ phase: "failed", error: e.message });
  }
}

export function reset() {
  ls.set("shopID", null);
  set({ shop: null, diagnosis: null, experience: null, chat: [], phase: "intake", tab: "dashboard", pages: [] });
}

export function changeLanguage(lang) {
  setLang(lang);
  set({ lang });
}
