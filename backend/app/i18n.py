"""Text the backend writes itself (not Claude), in English and HK Traditional Chinese (書面語)."""

from typing import Optional

EN, ZH = "en", "zh-HK"

_T = {
    # ---- feature labels and value formats (scoring.FEATURES) ----
    "feat.rating": ("Google rating", "Google評分"),
    "feat.review_count": ("Number of reviews", "評論數目"),
    "feat.price_level": ("Price level", "價格水平"),
    "feat.weekly_hours": ("Opening hours", "營業時間"),
    "feat.mtr_distance_m": ("Distance to MTR", "與港鐵站距離"),
    "feat.photo_count": ("Online photos", "網上相片"),
    "fmt.reviews": ("{n} reviews", "{n}則評論"),
    "fmt.hours": ("{n} h/week", "每週{n}小時"),
    "fmt.meters": ("{n} m", "{n}米"),
    "fmt.photos": ("{n} photos", "{n}張相片"),

    # ---- cost categories ----
    "cost.rent": ("Rent", "租金"),
    "cost.staff": ("Staff", "人手"),
    "cost.ingredients": ("Ingredients & stock", "食材及存貨"),
    "cost.utilities": ("Utilities", "水電雜費"),
    "cost.other": ("Other", "其他"),

    # ---- survivor vs closed findings ----
    "finding.base": ("{label}: survivors average {s}, closed shops {c}.",
                     "{label}：仍營業店舖平均{s}，已結業店舖平均{c}。"),
    "finding.unknown": (" We don't have this figure for your shop yet.", "我們尚未取得貴店此項數據。"),
    "finding.like_closed": (" You're at {m} — closer to the shops that closed.", "貴店為{m}，較接近已結業的店舖。"),
    "finding.like_survivors": (" You're at {m} — in line with the survivors.", "貴店為{m}，與仍營業的店舖相若。"),
    "finding.neutral": (" You're at {m}; this doesn't separate survivors from closures here.",
                        "貴店為{m}；此項在本區未能區分存活與結業的店舖。"),

    # ---- health sub-scores ----
    "sub.location": ("Location", "地點"),
    "sub.pricing": ("Pricing", "定價"),
    "sub.menu": ("Menu", "餐牌"),
    "sub.visibility": ("Visibility", "曝光度"),
    "sub.financials": ("Financials", "財務"),
    "sub.market": ("Market", "市場"),
    "loc.mtr": ("{d} m from the nearest MTR station.", "距離最近的港鐵站{d}米。"),
    "loc.unknown": ("MTR distance unknown; scored as average.", "未知與港鐵站的距離，以平均分計算。"),
    "price.compare": ("Your price level is {mine}; surviving twins sit around {target}.",
                      "貴店價格水平為{mine}；仍營業的同類店舖約為{target}。"),
    "price.unknown": ("Not enough price data to compare with twins.", "價格數據不足，未能與同類店舖比較。"),
    "menu.summary": ("Menu clarity {c}/10 across {n} items.", "餐牌清晰度{c}/10，共{n}項。"),
    "menu.long": (" A very long menu raises stock cost and slows ordering.", "餐牌過長會增加存貨成本並拖慢點餐。"),
    "menu.short": (" A very short menu limits repeat visits.", "餐牌過短，難以吸引回頭客。"),
    "menu.none": ("No menu photo analysed yet.", "尚未分析餐牌相片。"),
    "vis.front": ("Shopfront signage {s}/10, visibility {v}/10.", "門面招牌{s}/10，能見度{v}/10。"),
    "vis.reviews": ("{n} Google reviews.", "Google評論{n}則。"),
    "vis.experience": ("Shop experience check {n}/100.", "店舖體驗檢查{n}/100。"),
    "vis.none": ("No shopfront photo or Google listing found yet.", "尚未取得門面相片或Google商戶資料。"),
    "fin.summary": ("Net margin {m}, rent {r} of revenue. Weakest area: {w}.",
                    "淨利潤率{m}，租金佔收入{r}。最弱一環：{w}。"),
    "fin.net margin": ("net margin", "淨利潤率"),
    "fin.rent": ("rent", "租金"),
    "fin.staff": ("staff", "人手"),
    "fin.ingredients": ("ingredients", "食材"),
    "fin.none": ("No revenue figures yet.", "尚未提供收入數字。"),
    "mkt.summary": ("{rate} of similar shops nearby have closed; your profile leans toward the {leaning}.",
                    "附近{rate}的同類店舖已結業；貴店的特徵較接近{leaning}。"),
    "mkt.survivors": ("survivors", "仍營業的店舖"),
    "mkt.closed": ("closed shops", "已結業的店舖"),
    "mkt.none": ("No twin shops found to compare against.", "找不到可比較的同類店舖。"),

    # ---- forecast ----
    "fc.history": ("Based on {n} month(s) of revenue you provided.", "根據您提供的{n}個月收入計算。"),
    "fc.no_history": ("No revenue history provided.", "未有提供收入紀錄。"),
    "fc.trend": ("Underlying trend {t}/month, adjusted {h}/month for your Health Score.",
                 "基本趨勢為每月{t}，並按健康評分每月調整{h}。"),
    "fc.season": ("Hong Kong seasonal pattern assumed (Lunar New Year and December peaks, summer dip).",
                  "已套用香港季節性規律（農曆新年及十二月為旺季，夏季較淡）。"),
    "fc.band": ("The band covers roughly 80% of likely outcomes; it widens further out.",
                "陰影範圍涵蓋約八成可能結果；時間越遠，範圍越闊。"),
    "fc.short": ("With fewer than 3 months of history the trend is assumed flat and the band is wide.",
                 "收入紀錄少於三個月，因此假設趨勢持平，預測範圍亦較闊。"),

    # ---- diagnosis notes ----
    "note.demo": ("Demo mode: twin shops are fictional sample data.", "示範模式：同類店舖為虛構示例數據。"),
    "note.no_maps_key": ("No Google Maps key yet, so the twin shops are fictional sample data. Treat the comparison as a demo.",
                         "尚未設定Google地圖金鑰，同類店舖為虛構示例數據，比較結果只供示範。"),
    "note.places_failed": ("Couldn't reach Google Places; twin comparison is unavailable.",
                           "未能連接Google地點服務，暫時無法比較同類店舖。"),
    "note.web_failed": ("Web search for closed shops failed; the closed group may be undercounted.",
                        "搜尋已結業店舖時出錯，已結業店舖數目或被低估。"),
    "note.not_listed": ("We couldn't find your shop on Google Maps, so rating and reviews aren't scored.",
                        "未能在Google地圖找到貴店，因此評分及評論未有計算在內。"),
    "note.few_closed": ("Only {n} closed twin(s) found; treat the comparison as indicative.",
                        "只找到{n}間已結業的同類店舖，比較結果僅供參考。"),

    # ---- rule-based prescriptions ----
    "rx.gap.title": ("Close the gap on {label}", "改善{label}"),
    "rx.gap.detail": ("{message} Move this toward the survivors' level.", "{message}請向仍營業店舖的水平看齊。"),
    "rx.gap.evidence": ("Survivors {s} vs closed {c}", "仍營業 {s}，已結業 {c}"),
    "rx.sub.title": ("Strengthen {label}", "加強{label}"),
    "rx.sub.evidence": ("{label} score {n}/100", "{label}得分 {n}/100"),

    # ---- demo text ----
    "demo.sample": ("(sample)", "（示例）"),
    "demo.closed": ("Closed {year} (sample data)", "{year}年結業（示例數據）"),
    "demo.street": ("{n} Sample Street, {district}", "{district}示例街{n}號"),
    "demo.menu_note": ("86 items across 11 sections makes the menu hard to scan (sample data).",
                       "餐牌共11個分類、86項，難以快速閱讀（示例數據）。"),
    "demo.front_note": ("Sign is Chinese-only and unlit (sample data).", "招牌只有中文且沒有燈光（示例數據）。"),
    "demo.doctor_intro": ("(Demo mode — connect an Anthropic API key for real answers.)",
                          "（示範模式：連接Anthropic API金鑰後即可獲得真實回答。）"),
    "demo.doctor_score": ("Your Health Score is {n}/100. ", "貴店的健康評分為{n}/100。"),
    "demo.doctor_weakest": ("The weakest area is {label} ({n}/100): {why}",
                            "最弱的一環是{label}（{n}/100）：{why}"),
}


def norm(accept_language: Optional[str]) -> str:
    """Map an Accept-Language header to one of the two supported languages."""
    return ZH if (accept_language or "").strip().lower().startswith("zh") else EN


def t(lang: str, key: str, **kw) -> str:
    en, zh = _T[key]
    return (zh if lang == ZH else en).format(**kw)


def write_in(lang: str) -> str:
    """Instruction appended to Claude prompts so generated text matches the app language."""
    if lang == ZH:
        return ("Write every piece of text for the owner in Traditional Chinese, standard written style "
                "(書面語) as used in Hong Kong: HK$ for money, 港鐵 for MTR. Keep shop names as they are.")
    return "Write every piece of text for the owner in English."
