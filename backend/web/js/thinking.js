// "The Doctor is thinking" — paced stages, then the cross fills in and the prescription prints.
import { html, useEffect, useState } from "../vendor/preact-htm.mjs";
import { t } from "./i18n.js";
import { CrossLoader, Icon, ScrambleText } from "./ui.js";

export const DIAGNOSIS_STAGES = ["Reading your menu and records", "Finding twin shops nearby", "Sorting survivors from closures",
  "Taking your shop's vital signs", "Writing your prescription"];

/** Holds until every stage has had its moment AND `ready` is true, so even an instant answer gets a considered pause. */
export function ThinkingScreen({ ready, onDone, stages = DIAGNOSIS_STAGES, stageMs = 1800,
                                 title = "Examining your shop", doneTitle = "Diagnosis ready",
                                 subtitle = "The Doctor is thinking it through.", doneSubtitle = "Printing your prescription…" }) {
  const [stage, setStage] = useState(0);
  const [thoughtThrough, setThoughtThrough] = useState(false);
  const finished = ready && thoughtThrough;

  useEffect(() => {
    let i = 0;
    const id = setInterval(() => {
      i++;
      if (i < stages.length) setStage(i);
      else { setThoughtThrough(true); clearInterval(id); }
    }, stageMs);
    return () => clearInterval(id);
  }, []);

  return html`
    <div class="screen no-tabs" style="min-height:100dvh;display:flex;flex-direction:column;justify-content:center;gap:28px">
      <div class="center"><div style="display:inline-block"><${CrossLoader} complete=${finished} onDone=${onDone} /></div></div>
      <div class="center stack-sm" style="gap:6px">
        <h1 class="title-sm">${finished ? t(doneTitle) : t(title)}</h1>
        <div class="secondary">${finished ? t(doneSubtitle) : t(subtitle)}</div>
      </div>
      <div class="stage-list">
        ${stages.map((s, i) => {
          const done = i < stage || finished, current = i === stage && !finished;
          return html`
            <div class=${"stage" + (done ? " done" : current ? " on" : "")}>
              <span class="dot">${done ? html`<span style="color:#0e9f5b"><${Icon} name="check" size=${18} stroke=${3} /></span>`
                : current ? html`<span class="spinner" />` : html`<span style="width:8px;height:8px;border-radius:50%;background:#e4ebe7" />`}</span>
              <span>${current ? html`<${ScrambleText} text=${t(s)} />` : t(s)}</span>
            </div>`;
        })}
      </div>
    </div>`;
}

export function FailureScreen({ message, onRetry, onStartOver }) {
  return html`
    <div class="screen no-tabs center" style="min-height:100dvh;display:flex;flex-direction:column;justify-content:center;gap:16px">
      <div style="color:#dc2626;display:flex;justify-content:center"><${Icon} name="warning" size=${44} /></div>
      <h1 class="title-sm">${t("Something went wrong")}</h1>
      <p class="secondary" style="margin:0">${message}</p>
      <button class="btn-primary" onClick=${onRetry}>${t("Try again")}</button>
      <button class="btn-secondary" onClick=${onStartOver}>${t("Start over")}</button>
    </div>`;
}
