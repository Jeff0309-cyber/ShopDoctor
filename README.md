# ShopDoctor

An AI business consultant for Hong Kong small businesses. The owner uploads menu, shopfront and revenue/cost information and drops a pin on their location. ShopDoctor then:

1. Finds "twin" shops nearby (same category, within about 1.5 km) using Google Places, plus a web search for twins that have closed.
2. Splits the twins into **survivors** and **closed** shops.
3. Shows where the owner's shop looks like the closed group and what the survivors do differently.
4. Gives a **Health Score** out of 100, with six sub-scores.
5. Forecasts the next 12 months of revenue as a range.
6. Lets the owner chat with an **AI Doctor**. The Doctor reads the diagnosis through tools and can run what-if scenarios (price changes, hours, rent).

```
iOS app (SwiftUI) ──HTTP──> backend (FastAPI) ──> Claude (photo reading, closed-shop web search, prescriptions, Doctor)
                                              └──> Google Places API (New): twins and MTR stations
```

## Languages

The app switches between English and Traditional Chinese (書面語, Hong Kong usage) from **Shop → Language** or the `EN | 中` toggle at the start of intake. The switch is instant. Every request sends `Accept-Language`, so the backend and Claude write the diagnosis, prescriptions, shop check and Doctor replies in that language. Text Python writes itself lives in `backend/app/i18n.py`; iOS strings are in `ios/ShopDoctor/Localizable.xcstrings`.

## Shop experience check (3D)

The **Shop experience** card on the Check-up tab opens a separate check:

- **Pro iPhones with LiDAR** scan the room with Apple's RoomPlan. The app uploads only a small measured floor plan (`RoomSummary`), never camera images, plus 2–4 detail photos.
- **Other iPhones** take 7 guided photos instead.
- **Measurements:** `backend/app/layout.py` computes seats, space per seat, the narrowest aisle, blocked doorways and dead zones.
- **Analysis:** Claude reviews the measurements and photos and writes a fix plan. Every target and suggested furniture move is checked against the scan before it reaches the app.
- **In the app:** a clean 3D model with numbered pins and green "move it here" ghosts, then a step-by-step fix plan with Mark-as-done.
- **Demo mode:** "Load sample room" shows a fictional cha chaan teng, so the 3D view works in the Simulator.

To test the real scan, run the app on a LiDAR iPhone. Connect it by cable, choose your Apple ID under *Signing & Capabilities*, then set **Shop → Server** to your Mac's LAN IP, e.g. `http://192.168.1.20:8000`.

## Backend

```bash
cd backend
python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt

# Demo mode: fictional sample data, no API keys needed
SHOPDOCTOR_DEMO=1 .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Real mode: put your keys in backend/.env (see .env.example; git-ignored)
#   GEMINI_API_KEY=...       → Gemini does the AI work (or ANTHROPIC_API_KEY for Claude)
#   GOOGLE_MAPS_API_KEY=...  → real twin shops (without it, twins are labelled sample data)
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

.venv/bin/python -m pytest -q      # tests run offline
```

| Endpoint | What it does |
|---|---|
| `POST /v1/shops` | Multipart request: a `shop` field (JSON matching `ShopInput`) plus `menu_photos`, `shopfront_photos` and `financial_docs`. Claude reads the photos. |
| `POST /v1/shops/{id}/diagnose` | Finds twins, compares them, scores the shop, forecasts revenue and writes prescriptions. |
| `GET /v1/shops/{id}/diagnosis` | Returns the last diagnosis. |
| `PUT /v1/shops/{id}` | Updates the shop's numbers. |
| `POST /v1/shops/{id}/doctor` | Doctor chat, streamed as server-sent events (`text` / `tool` / `error` / `done`). |
| `POST /v1/shops/{id}/experience` | Shop check. Multipart with an optional `room` part (RoomSummary JSON) and `shot_<name>` photos. |
| `GET /v1/shops/{id}/experience` | Returns the last shop check. |

Tunable assumptions all live in [`backend/app/config.py`](backend/app/config.py): Health Score weights, HK cost-ratio benchmarks, the seasonality curve and price elasticity.

## iOS app

Requires Xcode 16 or newer (iOS 17+). Open `ios/ShopDoctor.xcodeproj`, choose an iPhone simulator and run.

- The app defaults to `http://localhost:8000`, which works from the Simulator. On a real iPhone, change the backend URL in **Shop → Server** to your Mac's LAN IP, e.g. `http://192.168.1.20:8000`.
- All design tokens (colours, radii, fonts) are in [`ios/ShopDoctor/Design/Theme.swift`](ios/ShopDoctor/Design/Theme.swift).

## How the scoring works

- **Similarity**: 1 minus the mean difference across normalised features (rating, reviews, price level, weekly hours, MTR distance, photo count), weighted slightly by how close the twin is.
- **Findings**: for each feature, the survivor average is compared with the closed average. If the owner's value is closer to the closed average, the finding is flagged "like closed shops".
- **Health Score**: Location 15%, Pricing 15%, Menu 15%, Visibility 15%, Financials 25%, Market 15%. Bands: 75 and above is healthy, 55–74 needs attention, below 55 is at risk.
- **Forecast**: a de-seasonalised log-linear trend, plus a drift of ±1% per month driven by the Health Score, with a band covering about 80% of outcomes that widens over time. With fewer than 3 months of history the trend is assumed flat.

## Known limits

- Google Places omits many closed shops, so the closed group partly depends on web search. Each diagnosis reports how many closed twins it found.
- "Survivor" means open today. Places doesn't give opening dates, so review count stands in for how long a shop has been open.
- Shops are stored as JSON files in `backend/data/`. There are no user accounts yet.
