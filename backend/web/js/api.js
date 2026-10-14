import { acceptLanguage, t } from "./i18n.js";

async function request(path, opts = {}) {
  const headers = { "Accept-Language": acceptLanguage(), ...(opts.headers || {}) };
  let res;
  try {
    res = await fetch(path, { ...opts, headers });
  } catch {
    throw new Error(t("Can't reach ShopDoctor. Check your connection and try again."));
  }
  if (!res.ok) {
    let detail = "";
    try { detail = (await res.json()).detail; } catch {}
    const msg = typeof detail === "string" ? detail : detail?.missing_shots ? t("Add the required photos to continue.") : "";
    const err = new Error(msg || t("Server error %lld: %@", res.status, res.statusText || "Request failed"));
    err.status = res.status;
    throw err;
  }
  return res.json();
}

const json = (body) => ({ method: "POST", body: JSON.stringify(body), headers: { "Content-Type": "application/json" } });

export const api = {
  health: () => request("/health"),
  shop: (id) => request(`/v1/shops/${id}`),
  diagnosis: (id) => request(`/v1/shops/${id}/diagnosis`),
  experience: (id) => request(`/v1/shops/${id}/experience`),
  diagnose: (id) => request(`/v1/shops/${id}/diagnose`, { method: "POST" }),
  updateShop: (id, input) => request(`/v1/shops/${id}`, { ...json(input), method: "PUT" }),
  demoRoom: () => request("/v1/demo/room"),

  createShop(input, uploads) {
    const form = new FormData();
    form.append("shop", JSON.stringify(input));
    for (const u of uploads) form.append(u.kind, u.blob, u.name);
    return request("/v1/shops", { method: "POST", body: form });
  },

  runExperience(id, room, photos) {
    const form = new FormData();
    if (room) form.append("room", JSON.stringify(room));
    for (const [shot, blob] of Object.entries(photos)) form.append(`shot_${shot}`, blob, `${shot}.jpg`);
    return request(`/v1/shops/${id}/experience`, { method: "POST", body: form });
  },

  /** Streams the Doctor's reply; calls onEvent({type: "text"|"tool"|"error"|"done", ...}). */
  async askDoctor(id, messages, onEvent) {
    const res = await fetch(`/v1/shops/${id}/doctor`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "text/event-stream", "Accept-Language": acceptLanguage() },
      body: JSON.stringify({ messages }),
    });
    if (!res.ok || !res.body) {
      let detail = "";
      try { detail = (await res.json()).detail; } catch {}
      throw new Error(typeof detail === "string" && detail ? detail : t("I couldn't reach the server: %@", res.status));
    }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let cut;
      while ((cut = buffer.indexOf("\n\n")) >= 0) {
        const line = buffer.slice(0, cut).trim();
        buffer = buffer.slice(cut + 2);
        if (line.startsWith("data: ")) onEvent(JSON.parse(line.slice(6)));
      }
    }
  },
};

/** Phone photos can be huge (and HEIC); shrink to a JPEG under the server's 8 MB limit. */
export async function toJpeg(file, maxDim = 2000, quality = 0.8) {
  if (file.type === "application/pdf") return file;
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise((resolve, reject) => {
      const i = new Image();
      i.onload = () => resolve(i);
      i.onerror = reject;
      i.src = url;
    });
    const scale = Math.min(1, maxDim / Math.max(img.naturalWidth, img.naturalHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.naturalWidth * scale);
    canvas.height = Math.round(img.naturalHeight * scale);
    canvas.getContext("2d").drawImage(img, 0, 0, canvas.width, canvas.height);
    return await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
  } finally {
    URL.revokeObjectURL(url);
  }
}

export const blobToDataUrl = (blob) =>
  new Promise((resolve) => { const r = new FileReader(); r.onload = () => resolve(r.result); r.readAsDataURL(blob); });
