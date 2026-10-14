// Leaflet + OpenStreetMap maps: the intake pin picker and the twin-shop map.
import { html, useEffect, useRef } from "../vendor/preact-htm.mjs";
import { t } from "./i18n.js";

export const HK = [22.3193, 114.1694];
const TILES = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';

const waitForLeaflet = () => new Promise((resolve) => {
  const check = () => (window.L ? resolve(window.L) : setTimeout(check, 50));
  check();
});

function baseMap(L, el, center, zoom, interactive = true) {
  const map = L.map(el, { zoomControl: false, attributionControl: true, dragging: interactive, scrollWheelZoom: interactive, tap: interactive });
  L.tileLayer(TILES, { maxZoom: 19, attribution: ATTRIBUTION }).addTo(map);
  map.setView(center, zoom);
  return map;
}

const markerHtml = (kind, size = 14) => {
  if (kind === "survivor") return `<span style="display:block;width:${size}px;height:${size}px;border-radius:50%;background:#0e9f5b;box-shadow:0 0 0 2px #fff,0 1px 3px rgba(0,0,0,.3)"></span>`;
  if (kind === "closed") return `<span style="display:block;width:${size}px;height:${size}px;border-radius:50%;background:#fff;border:3px solid #8a94a0;box-sizing:border-box;box-shadow:0 1px 3px rgba(0,0,0,.25)"></span>`;
  return `<span style="display:block;width:${size}px;height:${size}px;border-radius:3px;background:#0f172a;transform:rotate(45deg);box-shadow:0 0 0 2px #fff,0 1px 3px rgba(0,0,0,.3)"></span>`;
};
const divIcon = (L, kind, size) => L.divIcon({ className: "mk-pin", html: markerHtml(kind, size), iconSize: [size, size], iconAnchor: [size / 2, size / 2] });

/** Tap to drop the shop's pin; shows the ~1.5 km twin-search radius. */
export function PinPicker({ value, onChange, focus }) {
  const el = useRef(null), map = useRef(null), marker = useRef(null), circle = useRef(null);

  useEffect(() => {
    let alive = true;
    waitForLeaflet().then((L) => {
      if (!alive || !el.current) return;
      map.current = baseMap(L, el.current, value || HK, value ? 16 : 13);
      map.current.on("click", (e) => onChange({ lat: e.latlng.lat, lng: e.latlng.lng }));
      draw(L);
    });
    return () => { alive = false; map.current && map.current.remove(); };
  }, []);

  const draw = (L) => {
    if (!map.current || !value) return;
    const at = [value.lat, value.lng];
    if (!marker.current) {
      marker.current = L.marker(at, { icon: divIcon(L, "you", 18) }).addTo(map.current);
      circle.current = L.circle(at, { radius: 1500, color: "#0e9f5b", weight: 1, opacity: 0.5, fillOpacity: 0.06 }).addTo(map.current);
    } else {
      marker.current.setLatLng(at);
      circle.current.setLatLng(at);
    }
  };

  useEffect(() => { window.L && draw(window.L); }, [value && value.lat, value && value.lng]);
  useEffect(() => { if (focus && map.current) map.current.setView([focus.lat, focus.lng], 16, { animate: true }); }, [focus]);

  return html`<div ref=${el} class="map tall" style="border-radius:20px" aria-label=${t("Your shop")} />`;
}

/** Twin shops around the owner's pin; tap a marker to select it. */
export function TwinMap({ shop, twins, selected, onSelect, height = 260, interactive = true }) {
  const el = useRef(null), map = useRef(null), layer = useRef(null);

  useEffect(() => {
    let alive = true;
    waitForLeaflet().then((L) => {
      if (!alive || !el.current) return;
      map.current = baseMap(L, el.current, [shop.lat, shop.lng], 14, interactive);
      layer.current = L.layerGroup().addTo(map.current);
      render(L);
    });
    return () => { alive = false; map.current && map.current.remove(); };
  }, []);

  const render = (L) => {
    if (!layer.current) return;
    layer.current.clearLayers();
    for (const tw of twins) {
      if (tw.lat == null || tw.lng == null || tw.status === "temporarily_closed") continue;
      const size = tw.id === selected ? 20 : 14;
      const m = L.marker([tw.lat, tw.lng], { icon: divIcon(L, tw.status === "survivor" ? "survivor" : "closed", size), title: tw.name });
      if (onSelect) m.on("click", () => onSelect(tw.id));
      m.addTo(layer.current);
    }
    L.marker([shop.lat, shop.lng], { icon: divIcon(L, "you", 18), title: t("You"), zIndexOffset: 1000 }).addTo(layer.current);
  };

  useEffect(() => { window.L && render(window.L); }, [selected, twins]);

  return html`<div ref=${el} class="map" style=${{ height: height + "px" }} />`;
}

/** Address search via OpenStreetMap Nominatim (light use, Hong Kong only). */
export async function searchAddress(query, lang) {
  const url = `https://nominatim.openstreetmap.org/search?format=json&limit=4&countrycodes=hk&accept-language=${lang === "zh-HK" ? "zh-HK,zh" : "en"}&q=${encodeURIComponent(query)}`;
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) return [];
  return (await res.json()).map((r) => ({ name: r.display_name.split(",")[0], address: r.display_name, lat: +r.lat, lng: +r.lon }));
}
