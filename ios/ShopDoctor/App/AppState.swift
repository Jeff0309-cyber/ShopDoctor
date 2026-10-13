import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable { case loading, intake, diagnosing, prescription, ready, failed(String) }
    enum Tab: Hashable { case dashboard, twins, doctor, shop }

    var phase: Phase = .loading
    var shop: ShopProfile?
    var diagnosis: Diagnosis?
    var chat: [ChatMessage] = []
    var experience: ExperienceAudit?
    /// The backend is running on sample data (no API keys); unlocks "Load sample room".
    var demoMode = false
    /// Set when a diagnosis arrives; the loader plays its resolve animation, then calls `finishDiagnosing()`.
    var diagnosisReady = false
    var selectedTab: Tab = .dashboard

    var language: AppLanguage = .saved {
        didSet {
            Localization.current = language
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    private var shopID: String? {
        get { UserDefaults.standard.string(forKey: "shopID") }
        set { UserDefaults.standard.set(newValue, forKey: "shopID") }
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:8000"
    }

    var api: APIClient {
        APIClient(baseURL: URL(string: serverURL) ?? URL(string: "http://localhost:8000")!, language: language)
    }

    func start() async {
        demoMode = (try? await api.health().demoMode) ?? false
        guard let id = shopID else { phase = .intake; return }
        do {
            shop = try await api.shop(id: id)
        } catch {
            phase = .intake  // server was reset or is unreachable: start a fresh intake
            return
        }
        experience = try? await api.experience(shopID: id)
        do {
            diagnosis = try await api.diagnosis(shopID: id)
            phase = .ready
        } catch {
            await rediagnose()
        }
    }

    func submit(_ input: ShopInput, uploads: [Upload]) async {
        diagnosisReady = false
        phase = .diagnosing
        do {
            let created = try await api.createShop(input, uploads: uploads)
            shop = created
            shopID = created.id
            diagnosis = try await api.diagnose(shopID: created.id)
            chat = []
            diagnosisReady = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func rediagnose() async {
        guard let id = shop?.id else { return }
        diagnosisReady = false
        phase = .diagnosing
        do {
            diagnosis = try await api.diagnose(shopID: id)
            diagnosisReady = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// The thinking animation has resolved: show the freshly printed prescription.
    func finishDiagnosing() {
        phase = .prescription  // diagnosisReady is cleared when the next diagnosis starts
    }

    /// Leave the prescription for the main app, optionally on a specific tab.
    func openCheckup(on tab: Tab = .dashboard) {
        selectedTab = tab
        phase = .ready
    }

    func updateShop(_ input: ShopInput) async {
        guard let id = shop?.id else { return }
        do {
            shop = try await api.updateShop(id: id, input)
            await rediagnose()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        shopID = nil
        shop = nil
        diagnosis = nil
        experience = nil
        chat = []
        phase = .intake
    }
}
