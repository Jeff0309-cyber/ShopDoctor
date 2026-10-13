import Foundation

/// The two languages ShopDoctor speaks. Chinese is standard written Traditional Chinese (書面語), HK usage.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-HK"

    var id: String { rawValue }

    /// Shown in the picker in its own language.
    var nativeName: String { self == .english ? "English" : "中文" }
    var shortName: String { self == .english ? "EN" : "中" }

    /// Sent to the backend so generated text matches.
    var acceptLanguage: String { self == .english ? "en" : "zh-Hant-HK" }

    var locale: Locale { Locale(identifier: self == .english ? "en_HK" : "zh_Hant_HK") }

    static var saved: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "language"), let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        // First launch: follow the phone if it is set to Chinese.
        return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
    }
}

/// Looks strings up in the chosen language's table, independent of the phone's language,
/// so the in-app switch takes effect immediately.
enum Localization {
    nonisolated(unsafe) static var current: AppLanguage = .saved {
        didSet { bundle = Self.bundle(for: current) }
    }
    nonisolated(unsafe) private static var bundle: Bundle = bundle(for: .saved)

    private static func bundle(for lang: AppLanguage) -> Bundle {
        Bundle.main.path(forResource: lang.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// Localized text for `key` (the English source string).
func L(_ key: String) -> String {
    Localization.string(key)
}

/// Localized format string, e.g. `L("Step %lld of %lld", 2, 4)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localization.string(key), locale: Localization.current.locale, arguments: args)
}

/// Lower-cases a label mid-sentence in English; Chinese has no case.
func lowered(_ s: String) -> String {
    Localization.current == .english ? s.lowercased() : s
}

/// "high impact" → "High impact"; no effect on Chinese.
func sentenceCase(_ s: String) -> String {
    s.prefix(1).uppercased() + s.dropFirst()
}
