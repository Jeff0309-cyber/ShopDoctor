"""English → HK Traditional Chinese (書面語) for ShopDoctor's iPhone app and website.

Edit TR, then run:  python3 tools/translations.py
It rewrites ios/ShopDoctor/Localizable.xcstrings and backend/web/i18n/zh-HK.json.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TR = {
    # app shell
    "Check-up": "健康檢查", "Twins": "同類店舖", "Doctor": "醫生", "Shop": "店舖",
    "Something went wrong": "出現問題", "Try again": "再試一次", "Start over": "重新開始",
    # bands, score
    "Healthy": "健康", "Needs attention": "需要留意", "At risk": "有風險",
    "of 100": "／100", "Health Score %lld out of 100, %@": "健康評分%lld分（滿分100），%@",
    "Health Score": "健康評分",
    # kitchen
    "Press and hold to confirm": "按住以確認", "Confirmed": "已確認", "Keep holding…": "請繼續按住…",
    "Undo": "復原", "Diagnosis ready": "診斷完成", "Diagnosing": "診斷中", "Signed, Dr. ShopDoctor": "由店舖醫生簽署",
    # doctor
    "Why is my score this low?": "為何我的評分這麼低？",
    "What did the survivors do differently?": "仍營業的店舖做對了甚麼？",
    "What if I raise prices 10%?": "如果加價一成會怎樣？",
    "Should I open longer hours?": "我應該延長營業時間嗎？",
    "How can I ease my rent pressure?": "如何減輕租金壓力？",
    "I've read your check-up. Ask me about your score, your twins, or try a what-if.":
        "我已看過您的健康檢查報告。歡迎問我有關評分及同類店舖的問題，或試試「如果……會怎樣」。",
    "Ask the Doctor…": "向醫生提問…", "Send": "傳送", "Thinking…": "思考中…",
    "I couldn't reach the server: %@": "無法連接伺服器：%@",
    "Reviewing your check-up…": "正在查看您的健康檢查報告…", "Looking at your twin shops…": "正在查看同類店舖…",
    "Running the numbers…": "正在計算數字…", "Working…": "處理中…",
    # twins
    "Group": "組別", "Survivors (%lld)": "仍營業（%lld）", "Closed (%lld)": "已結業（%lld）",
    "No open twins found.": "找不到仍營業的同類店舖。", "No closed twins found.": "找不到已結業的同類店舖。",
    "Most similar first": "最相似的排先", "Twin shops": "同類店舖", "%lld%% match": "相似度%lld%%",
    "%lldh/wk": "每週%lld小時", "Source": "來源",
    "Still open": "仍營業", "Closed": "已結業", "Temporarily closed": "暫停營業",
    # slip (labels only)
    "PRINTING PRESCRIPTION": "列印處方中", "PRESCRIPTION READY": "處方已備妥", "SHOPDOCTOR CLINIC": "店舖醫生診所",
    "HEALTH SCORE": "健康評分", "CONDITION": "狀況", "CLOSED NEARBY": "附近已結業", "%lld OF %lld": "%lld／%lld",
    "NO URGENT TREATMENT NEEDED.": "暫無需要緊急處理的問題。", "BASED ON: %@": "根據：%@",
    "RE-CHECK IN 30 DAYS": "三十日後覆診", "ESTIMATES, NOT GUARANTEES": "僅屬估算，並非保證", "DR. SHOPDOCTOR": "店舖醫生",
    "%@ impact": "影響程度：%@", "high": "高", "medium": "中", "low": "低",
    # charts
    "Revenue forecast": "收入預測", "Monthly, HKD · shaded band ≈ 80% of outcomes": "每月（港幣）· 陰影範圍約涵蓋八成結果",
    "Forecast assumptions": "預測假設", "Month": "月份", "Low": "低", "High": "高", "Expected": "預期", "Actual": "實際",
    "Forecast": "預測", "Break-even": "收支平衡", "Likely range": "可能範圍",
    "Survivors vs closed": "存活與結業對比",
    "%lld still open · %lld closed nearby (%@ closure rate)": "%lld間仍營業 · 附近%lld間已結業（結業率%@）",
    "Survivors avg": "仍營業平均", "Closed avg": "已結業平均", "You": "貴店",
    "Not enough twin data to compare yet.": "同類店舖數據不足，暫未能比較。",
    "Like closed shops": "似已結業店舖", "Like survivors": "似仍營業店舖",
    "Where the money goes": "錢花在哪裏", "Monthly costs as a share of revenue": "每月成本佔收入比例",
    "Add your monthly costs to see this.": "輸入每月成本後即可查看。", "Amount": "金額", "Category": "類別",
    "Total %@ vs revenue %@": "總成本%@，收入%@",
    "Your twins on the map": "同類店舖地圖", "Similar shops within ~1.5 km": "約1.5公里內的同類店舖",
    # profile
    "Name": "名稱", "Type": "類型", "District": "地區", "Address": "地址", "Open hours": "營業時間",
    "%lld h/week": "每週%lld小時", "Monthly costs": "每月成本", "Rent": "租金", "Staff": "人手",
    "Ingredients & stock": "食材及存貨", "Utilities": "水電雜費", "Other": "其他", "Update numbers": "更新數字",
    "What we read from your menu": "我們從餐牌讀到的資料", "Items": "項目", "Average price": "平均價錢",
    "Clarity": "清晰度", "What we saw at your shopfront": "我們在門面看到的", "Signage": "招牌",
    "Visibility": "能見度", "Condition": "狀況", "Walk-in appeal": "吸引力", "Re-run diagnosis": "重新診斷",
    "Hold to start a new shop": "按住以建立新店舖", "Clears this shop's check-up from this phone.": "會從此手機清除這間店舖的健康檢查。",
    "Server": "伺服器", "Backend URL": "後端網址", "My shop": "我的店舖", "Starting a new shop…": "正在建立新店舖…",
    "Monthly revenue": "每月收入", "Add this month": "加入本月", "Cancel": "取消", "Save & re-check": "儲存並重新檢查",
    "Language": "語言",
    "Generated text switches language the next time the check-up runs. Pull down on the Check-up tab to refresh now.":
        "診斷內容會在下次檢查時轉換語言。在「健康檢查」頁面向下拉即可立即更新。",
    # dashboard
    "%@ · %@": "%@ · %@", "Your check-up": "您的健康檢查", "Ask the Doctor what to do next": "問醫生下一步怎樣做",
    "About this data": "關於這些數據",
    "Where these numbers come from and how far to trust them.": "這些數字的來源及可信程度。",
    "In good shape. Keep doing what works.": "狀況良好，繼續保持。",
    "Doing OK, but a few areas need attention.": "大致正常，但有幾方面需要留意。",
    "Showing warning signs seen in shops that closed.": "出現與已結業店舖相似的警號。",
    "Today's focus": "今日重點", "View full prescription": "查看完整處方", "Prescription": "處方",
    "1 step": "1項建議", "%lld steps": "%lld項建議", "Signed by the Doctor": "醫生已簽署",
    "Score breakdown": "評分細項", "Weakest: %@": "最弱：%@",
    "Six vital signs, weighted into your Health Score. Lowest first.": "六項指標加權計算出健康評分，由低至高排列。",
    "Money": "財務", "Net margin · profitable": "淨利潤率 · 有盈利", "Net margin · losing money": "淨利潤率 · 虧損中",
    "Next 12 months · %@/mo": "未來12個月 · 每月%@",
    "Where revenue is likely heading if nothing changes. Tap the chart to read a month.":
        "如不作改變，收入的可能走勢。點按圖表查看個別月份。",
    "of similar shops nearby closed": "附近同類店舖已結業", "What we saw": "我們看到的",
    "menu items read": "已讀取的餐牌項目", "Add menu photos": "加入餐牌相片",
    "What the Doctor read from your photos.": "醫生從您的相片讀到的資料。",
    "You keep %@ of every dollar of revenue. Here's where the rest goes.": "每一元收入您可保留%@。以下是其餘支出的去向。",
    "Costs are above revenue by %@ a month. Here's where it goes.": "每月成本比收入多%@。以下是支出的去向。",
    "On every measure we could compare, you look like the shops that survived.": "在所有可比較的指標上，貴店都與仍營業的店舖相似。",
    "On 1 measure, you look more like the shops that closed.": "在1項指標上，貴店較似已結業的店舖。",
    "On %lld measures, you look more like the shops that closed.": "在%lld項指標上，貴店較似已結業的店舖。",
    "The Doctor's top changes, most important first.": "醫生建議的主要改變，按重要性排列。",
    "Ask the Doctor about these": "就這些建議問醫生",
    "No photos analysed yet. Add menu and shopfront photos in a new check-up.": "尚未分析任何相片。請在新的健康檢查中加入餐牌及門面相片。",
    "Menu": "餐牌", "%lld items · clarity %lld/10": "%lld項 · 清晰度%lld/10", "Average price %@": "平均價錢%@",
    "Shopfront": "門面", "As a passer-by sees it": "路人眼中的樣子",
    "Break-even %@": "收支平衡點%@", "Net margin": "淨利潤率", "%@ profit": "盈利%@", "%@ loss": "虧損%@",
    "Rent / revenue": "租金／收入", "Within HK norm": "符合香港常見水平", "Above 20% norm": "高於20%常見水平",
    "Next 12 months": "未來12個月", "Trend %@/mo": "趨勢每月%@", "How the score is built": "評分如何計算",
    "Weighted sub-scores, 0–100": "加權分項，0至100", "%lld · %lld%% weight": "%lld分 · 佔%lld%%",
    # errors
    "Server error %lld: %@": "伺服器錯誤%lld：%@", "Unexpected response from the server.": "伺服器回應異常。",
    # diagnosing + reveal
    "Reading your menu and records": "正在讀取餐牌及紀錄", "Finding twin shops nearby": "正在尋找附近的同類店舖",
    "Sorting survivors from closures": "正在區分存活與結業的店舖", "Taking your shop's vital signs": "正在量度店舖的各項指標",
    "Writing your prescription": "正在撰寫處方", "Examining your shop": "正在檢查您的店舖",
    "Printing your prescription…": "正在列印處方…", "The Doctor is thinking it through.": "醫生正在仔細分析。",
    "Diagnosis complete": "診斷完成", "Your prescription": "您的處方", "See my full check-up": "查看完整健康檢查",
    "Ask the Doctor about this": "就此問醫生",
    # intake
    "Your shop": "您的店舖", "Photos": "相片", "Location": "位置", "Step %lld of %lld": "第%lld步，共%lld步",
    "Back": "返回", "Run diagnosis": "開始診斷", "Continue": "繼續",
    "Cha chaan teng": "茶餐廳", "Noodle shop": "粉麵店", "Café": "咖啡店", "Bakery": "麵包店", "Bubble tea": "珍珠奶茶店",
    "Dessert shop": "甜品店", "Restaurant": "餐廳", "Hair salon": "髮型屋", "Nail salon": "美甲店",
    "Convenience store": "便利店", "Boutique": "時裝店", "Pharmacy": "藥房",
    "Central": "中環", "Sheung Wan": "上環", "Wan Chai": "灣仔", "Causeway Bay": "銅鑼灣", "North Point": "北角",
    "Quarry Bay": "鰂魚涌", "Aberdeen": "香港仔", "Tsim Sha Tsui": "尖沙咀", "Jordan": "佐敦", "Yau Ma Tei": "油麻地",
    "Mong Kok": "旺角", "Prince Edward": "太子", "Sham Shui Po": "深水埗", "Kowloon City": "九龍城", "To Kwa Wan": "土瓜灣",
    "Kwun Tong": "觀塘", "Wong Tai Sin": "黃大仙", "Tsuen Wan": "荃灣", "Kwai Chung": "葵涌", "Sha Tin": "沙田",
    "Tai Po": "大埔", "Tuen Mun": "屯門", "Yuen Long": "元朗", "Tseung Kwan O": "將軍澳", "Tung Chung": "東涌",
    "Tell us the basics. We'll use them to find shops like yours nearby.": "先告訴我們基本資料，我們會用來尋找附近與您相似的店舖。",
    "Shop name": "店舖名稱", "e.g. Wing Kee Café": "例如：永記冰室", "What kind of shop?": "店舖類型",
    "Opened in": "開業年份", "Open hours per week: %lld": "每週營業時數：%lld",
    "Photos help the Doctor read your menu prices and see your shop the way a passer-by does. All optional.":
        "相片可幫助醫生讀取餐牌價錢，並以路人的角度觀察您的店舖。全部均為選填。",
    "Every page, straight on": "每一頁，正面拍攝", "From across the street, in daylight": "日間在對面街拍攝",
    "Revenue & cost records": "收支紀錄", "A P&L, ledger page or POS report. Photo or PDF.": "損益表、帳簿或收銀機報表，相片或PDF均可。",
    "%lld attached": "已附上%lld份", "PDF": "PDF", "Add": "加入",
    "Rough numbers are fine. If you attached records, leave these blank and we'll read them.":
        "大約數字即可。如已附上紀錄，可留空，我們會自動讀取。",
    "Takings for each month, HKD": "每月營業額（港幣）", "A typical month, HKD": "一般月份（港幣）",
    "Staff wages & MPF": "員工薪金及強積金",
    "Drop the pin on your door. Twins are searched within about 1.5 km.": "將圖釘放在您的店門位置。我們會在約1.5公里範圍內尋找同類店舖。",
    "Search address or building": "搜尋地址或大廈", "Result": "結果", "Use my current location": "使用我目前的位置",
}



TR.update({
    "Shop experience": "店舖體驗",
    "%lld/100 · %lld of %lld fixes done": "%lld/100 · 已完成%lld／%lld項改善",
    "Scan your shop in 3D and get a step-by-step fix plan": "以3D掃描店舖，取得逐步改善方案",
    "Photograph your shop and get a step-by-step fix plan": "為店舖拍照，取得逐步改善方案",
    "Looking at your shop check…": "正在查看店舖體驗檢查…",
    "Entrance from outside": "店外入口", "First view from the door": "進門第一眼", "Seating area": "座位區",
    "A table set for service": "擺好的餐枱", "Ordering and payment point": "點餐及付款處", "Washroom": "洗手間",
    "Peak-hour atmosphere": "繁忙時段氣氛",
    "Stand across the street in daylight. Fit the whole frontage in.": "日間站在對面街，拍下整個門面。",
    "Step just inside and shoot what a new customer sees first.": "剛進門的位置，拍下新客人第一眼看到的景象。",
    "From a corner, wide, with the walkways visible.": "在角落以廣角拍攝，要拍到通道。",
    "Chair height, with cutlery, sauces and menu as customers find them.": "以坐下的高度拍攝，保留餐具、醬料及餐牌的原狀。",
    "The counter or menu board, including any payment signs.": "收銀處或餐牌板，包括付款標示。",
    "A wide shot, if customers use it.": "如客人會使用，請以廣角拍攝。",
    "During your busiest hour, lights as normal. No faces.": "在最繁忙的時段拍攝，燈光照常，不要拍到人臉。",
    "Let the Doctor walk through your shop the way a customer does. It takes about 5 minutes.":
        "讓醫生以客人的角度走一遍您的店舖，約需5分鐘。",
    "Detail photos": "細節相片", "Analyse my shop": "分析我的店舖", "Add the required photos to continue.": "請加入必須的相片以繼續。",
    "3D scan": "3D掃描", "Measures your layout: seats, aisles and doorways": "量度店舖格局：座位、通道及出入口",
    "%lld tables · %@ m² scanned": "已掃描%lld張枱 · %@平方米", "Scan again": "重新掃描", "Remove sample room": "移除示例店舖",
    "Turn all the lights on. Empty is best, before opening.": "開啟所有燈光。最好在開店前、店內無人時掃描。",
    "Start at the door and walk slowly along the walls.": "由門口開始，沿牆慢慢行走。",
    "Point the camera at every table, the counter and the doorway.": "將鏡頭對準每張餐枱、收銀處及門口。",
    "Start 3D scan": "開始3D掃描",
    "3D scanning needs an iPhone Pro with LiDAR. We'll use photos instead.": "3D掃描需要配備光學雷達的iPhone Pro。我們會改用相片分析。",
    "Load sample room": "載入示例店舖", "Before you shoot": "拍攝前注意",
    "No customers' or staff faces. Lights on, phone held sideways.": "不要拍到客人或員工的面孔。開燈，並橫向拿手機。",
    "Required": "必須", "Optional": "選填", "Take photo": "拍照", "Choose from library": "從相簿選擇", "Remove": "移除",
    "Add photo": "加入相片", "Retake": "重拍",
    "Measuring your layout": "正在量度店舖格局", "Walking in as a customer": "正在以客人角度走進店舖",
    "Checking tables and counter": "正在檢查餐枱及收銀處", "Comparing with busy HK shops": "正在與香港旺舖比較",
    "Writing your fix plan": "正在撰寫改善方案", "Fix plan ready": "改善方案已備妥",
    "Building your 3D model…": "正在建立3D模型…",
    "Walk slowly along the walls. Point at every table and the counter.": "沿牆慢慢行走，將鏡頭對準每張餐枱及收銀處。",
    "Done scanning": "完成掃描",
    "Seats": "座位", "%lld tables": "%lld張枱", "Space per seat": "每座位面積", "Narrowest aisle": "最窄通道",
    "Below 0.9 m": "少於0.9米", "Comfortable": "舒適",
    "Drag to turn · pinch to zoom · tap a pin": "拖動旋轉 · 雙指縮放 · 點按圖釘",
    "Your fix plan": "您的改善方案", "%lld of %lld fixed": "已完成%lld／%lld項", "Start fixing": "開始改善",
    "Continue fixing": "繼續改善", "How the shop scores": "店舖各方面得分", "Out of 10, from a customer's point of view": "以客人角度評分，滿分10分",
    "About this check": "關於這次檢查", "Ask the Doctor": "問醫生", "Check again": "再檢查一次", "%@ cost": "成本：%@",
    "Fix %lld of %lld": "第%lld項，共%lld項", "Close": "關閉", "All fixes done": "全部改善已完成",
    "Check again to see how your score changed.": "再檢查一次，看看分數有何改變。", "Mark as not done": "標記為未完成",
    "Mark as done": "標記為已完成", "Next": "下一項", "Done": "已完成", "What we noticed": "我們留意到",
    "Why it matters": "為何重要", "How to fix it": "改善方法",
    "The green shape on the model shows where it should go.": "模型上的綠色位置顯示應移到哪裏。",
})

TR.update({
    "3D scanning needs the ShopDoctor iPhone app on an iPhone Pro with LiDAR. Here we'll use photos instead.":
        "3D掃描需要在配備光學雷達的iPhone Pro上使用ShopDoctor iPhone應用程式。這裏會改用相片分析。",
    "Can't reach ShopDoctor. Check your connection and try again.": "無法連接ShopDoctor，請檢查網絡連線後再試。",
    "Generated text switches language the next time the check-up runs.": "診斷內容會在下次檢查時轉換語言。",
    "The green shape on the plan shows where it should go.": "平面圖上的綠色位置顯示應移到哪裏。",
    "Top-down plan, entrance at the bottom · tap a pin": "俯視平面圖，入口在下方 · 點按圖釘",
})


def build() -> None:
    table = dict(sorted(TR.items()))
    catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {
        en: {"extractionState": "manual", "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "zh-HK": {"stringUnit": {"state": "translated", "value": zh}}}}
        for en, zh in table.items()}}
    (ROOT / "ios/ShopDoctor/Localizable.xcstrings").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    (ROOT / "backend/web/i18n/zh-HK.json").write_text(json.dumps(table, ensure_ascii=False, indent=0) + "\n")
    print(f"{len(table)} strings written")


if __name__ == "__main__":
    build()
