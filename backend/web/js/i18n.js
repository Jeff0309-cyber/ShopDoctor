// English source strings are the keys (same table as the iOS app's Localizable.xcstrings).
let lang = "en";
let zh = {};

export async function loadLanguage(saved) {
  const res = await fetch("i18n/zh-HK.json");
  zh = res.ok ? await res.json() : {};
  // First visit: follow the phone's language.
  lang = saved || ((navigator.language || "").toLowerCase().startsWith("zh") ? "zh-HK" : "en");
  return lang;
}

export function setLang(next) {
  lang = next;
  try { localStorage.setItem("language", next); } catch {}
  document.documentElement.lang = next === "zh-HK" ? "zh-Hant-HK" : "en";
}

export const getLang = () => lang;
export const isZh = () => lang === "zh-HK";
export const acceptLanguage = () => (isZh() ? "zh-Hant-HK" : "en");

/** t("Step %lld of %lld", 2, 4) — iOS-style %lld / %@ placeholders, %% for a literal percent. */
export function t(key, ...args) {
  let s = isZh() ? zh[key] ?? key : key;
  if (!args.length) return s;
  let i = 0;
  return s.replace(/%%|%lld|%@/g, (m) => (m === "%%" ? "%" : String(args[i++])));
}

export const lowered = (s) => (isZh() ? s : s.toLowerCase());
export const sentenceCase = (s) => s.charAt(0).toUpperCase() + s.slice(1);

const n0 = (v, d = 0) => v.toLocaleString(isZh() ? "zh-HK" : "en-HK", { maximumFractionDigits: d, minimumFractionDigits: 0 });

export const Fmt = {
  hkd(v, compact = true) {
    if (compact && isZh() && Math.abs(v) >= 10000) {
      const wan = v / 10000;
      return "HK$" + n0(wan, Math.abs(wan) < 100 ? 1 : 0) + "萬";
    }
    if (compact && Math.abs(v) >= 1e6) return "HK$" + (v / 1e6).toFixed(1) + "M";
    if (compact && Math.abs(v) >= 1e4) return "HK$" + Math.round(v / 1e3) + "K";
    return "HK$" + n0(Math.round(v));
  },
  pct(v, signed = false) {
    const s = Math.round(v * 100) + "%";
    return signed && v > 0 ? "+" + s : s;
  },
  meters(v) {
    if (isZh()) return v >= 1000 ? (v / 1000).toFixed(1) + "公里" : Math.round(v) + "米";
    return v >= 1000 ? (v / 1000).toFixed(1) + " km" : Math.round(v) + " m";
  },
  month(ym, long = false) {
    const [y, m] = ym.split("-").map(Number);
    return new Date(y, m - 1, 1).toLocaleDateString(isZh() ? "zh-HK" : "en-HK",
      long ? { month: "long", year: "numeric" } : { month: "short" });
  },
};
