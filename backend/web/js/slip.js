// The signed prescription slip that prints out of a slot (Kitchen: Receipt Printer + Animated Signature).
// A faithful copy of ios/ShopDoctor/Dashboard/PrescriptionSlip.swift.
import { html, useEffect, useLayoutEffect, useRef, useState } from "../vendor/preact-htm.mjs";
import { t, isZh } from "./i18n.js";
import { Icon, ScrambleText, Signature, bandFor, reducedMotion, sleep } from "./ui.js";

const TEETH = 28, DEPTH = 5;
function zigzag() {
  const pts = ["0 0", "100% 0", `100% calc(100% - ${DEPTH}px)`];
  for (let i = TEETH - 1; i >= 0; i--) {
    pts.push(`${((i + 0.5) / TEETH) * 100}% 100%`, `${(i / TEETH) * 100}% calc(100% - ${DEPTH}px)`);
  }
  return `polygon(${pts.join(",")})`;
}
const ZIGZAG = zigzag();

const printedKey = "printedDiagnosis";
export const alreadyPrinted = (d) => { try { return localStorage.getItem(printedKey) === d.generated_at; } catch { return false; } };

export function PrescriptionSlip({ shop, diagnosis: d, onPrinted }) {
  const instant = alreadyPrinted(d) || reducedMotion();
  const paper = useRef(null);
  const [height, setHeight] = useState(0);
  const [fed, setFed] = useState(instant ? 1 : 0);
  const [printing, setPrinting] = useState(false);
  const [signed, setSigned] = useState(instant);

  useLayoutEffect(() => {
    const el = paper.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setHeight(el.offsetHeight));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    if (instant) { onPrinted && onPrinted(); return; }
    let cancelled = false;
    (async () => {
      setPrinting(true);
      await sleep(400);
      // A thermal head advances line by line: 20 short steps with pauses between.
      for (let step = 1; step <= 20 && !cancelled; step++) {
        setFed(step / 20);
        await sleep(87);
      }
      if (cancelled) return;
      setPrinting(false);
      setSigned(true);
      navigator.vibrate && navigator.vibrate(15);
      try { localStorage.setItem(printedKey, d.generated_at); } catch {}
      onPrinted && onPrinted();
    })();
    return () => { cancelled = true; };
  }, [d.generated_at]);

  const date = new Date().toLocaleDateString("en-GB", { day: "2-digit", month: "2-digit", year: "2-digit" });
  const total = d.comparison.closed_count + d.comparison.survivor_count;
  const up = (s) => (isZh() ? s : s.toUpperCase());

  return html`
    <div>
      <div class="slip-slot">
        <span class=${"led" + (printing ? " printing" : "")} />
        <span class="spacer"><${ScrambleText} text=${printing ? t("PRINTING PRESCRIPTION") : t("PRESCRIPTION READY")} /></span>
        <span style=${{ color: "#0e9f5b" }}><${Icon} name="cross" size=${18} /></span>
      </div>
      <div class="slip-out" style=${{ height: height ? height * fed + "px" : "auto" }}>
        <article ref=${paper} class="slip-paper"
                 style=${{ "--zigzag": ZIGZAG, transform: `translateY(${-(1 - fed) * height}px)`, transition: "transform 0.05s linear", position: "absolute", left: 0, right: 0, bottom: 0 }}>
          <div class="row" style="align-items:baseline">
            <span class="rx">℞</span>
            <div class="spacer">
              <div class="b">${t("SHOPDOCTOR CLINIC")}</div>
              <div>${up(shop.name)}</div>
            </div>
            <div>${date}</div>
          </div>
          <div class="rule">${"- ".repeat(60)}</div>
          <div class="kv"><span>${t("HEALTH SCORE")}</span><span class="b">${Math.round(d.health.overall)}/100</span></div>
          <div class="kv"><span>${t("CONDITION")}</span><span class="b">${up(bandFor(d.health.overall).label)}</span></div>
          <div class="kv"><span>${t("CLOSED NEARBY")}</span><span class="b">${t("%lld OF %lld", d.comparison.closed_count, total)}</span></div>
          <div class="rule">${"- ".repeat(60)}</div>
          ${d.prescriptions.length === 0 && html`<div class="b">${t("NO URGENT TREATMENT NEEDED.")}</div>`}
          ${d.prescriptions.map((p, i) => html`
            <div class="item">
              <div class="row" style="align-items:baseline">
                <span class="b">${i + 1}.</span><span class="b spacer">${up(p.title)}</span>
                <span class="dots" aria-label=${t("%@ impact", t(p.impact))}>${p.impact === "high" ? "●●●" : p.impact === "medium" ? "●●○" : "●○○"}</span>
              </div>
              <div style="color:rgba(15,23,42,.85)">${p.detail}</div>
              <div class="small">${t("BASED ON: %@", p.evidence)}</div>
            </div>`)}
          <div class="rule">${"- ".repeat(60)}</div>
          <div class="row" style="align-items:flex-end">
            <div class="spacer small">${t("RE-CHECK IN 30 DAYS")}<br />${t("ESTIMATES, NOT GUARANTEES")}</div>
            <div class="center">
              <${Signature} draw=${signed} instant=${instant} />
              <div style="height:.5px;background:rgba(15,23,42,.3);width:120px" />
              <div style="font-size:9px;color:#5b6472">${t("DR. SHOPDOCTOR")}</div>
            </div>
          </div>
        </article>
      </div>
    </div>`;
}

/** Full-screen moment right after the thinking screen. */
export function PrescriptionReveal({ shop, diagnosis, onOpen, onAskDoctor }) {
  const [ready, setReady] = useState(alreadyPrinted(diagnosis) || reducedMotion());
  return html`
    <div class="screen no-tabs soft" style="min-height:100dvh">
      <div class="stack">
        <div>
          <div class="row caption" style="color:#0a7a45;font-weight:650"><${Icon} name="seal" size=${16} />${t("Diagnosis complete")}</div>
          <h1 class="title">${t("Your prescription")}</h1>
        </div>
        <${PrescriptionSlip} shop=${shop} diagnosis=${diagnosis} onPrinted=${() => setTimeout(() => setReady(true), 1900)} />
      </div>
      ${ready && html`
        <div class="footer-bar fade-in">
          <button class="btn-primary" onClick=${onOpen}>${t("See my full check-up")} <${Icon} name="arrowRight" /></button>
          <button class="btn-secondary" onClick=${onAskDoctor}><${Icon} name="stethoscope" /> ${t("Ask the Doctor about this")}</button>
        </div>`}
    </div>`;
}
