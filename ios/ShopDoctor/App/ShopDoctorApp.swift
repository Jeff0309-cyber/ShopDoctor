import SwiftUI

@main
struct ShopDoctorApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .tint(Theme.primary)
                .preferredColorScheme(.light)  // the clinical white look is the brand
                .task { await state.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ProgressView().controlSize(.large)
            case .intake:
                IntakeFlow()
            case .diagnosing:
                DiagnosingView()
            case .prescription:
                PrescriptionRevealView()
            case .ready:
                MainTabs()
            case .failed(let message):
                FailureView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.25), value: state.phase)
        // A language switch redraws every view with the new strings and number/date formats.
        .id(state.language)
        .environment(\.locale, state.language.locale)
    }
}

struct MainTabs: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.selectedTab) {
            dashboard
                .tabItem { Label(L("Check-up"), systemImage: "waveform.path.ecg") }
                .tag(AppState.Tab.dashboard)
            TwinsView()
                .tabItem { Label(L("Twins"), systemImage: "building.2") }
                .tag(AppState.Tab.twins)
            DoctorChatView()
                .tabItem { Label(L("Doctor"), systemImage: "stethoscope") }
                .tag(AppState.Tab.doctor)
            ProfileView()
                .tabItem { Label(L("Shop"), systemImage: "storefront") }
                .tag(AppState.Tab.shop)
        }
    }
}

extension MainTabs {
    @ViewBuilder private var dashboard: some View {
        #if DEBUG
        // Screenshot helper: `-debugScreen experience|fixplan` opens the shop-experience check directly.
        if ["experience", "fixplan"].contains(UserDefaults.standard.string(forKey: "debugScreen")) {
            NavigationStack { ExperienceHubView() }
        } else {
            DashboardView()
        }
        #else
        DashboardView()
        #endif
    }
}

struct FailureView: View {
    @Environment(AppState.self) private var state
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bandage").font(.system(size: 44)).foregroundStyle(Theme.critical)
            Text(L("Something went wrong")).font(Theme.title(22)).foregroundStyle(Theme.ink)
            Text(message).font(Theme.body).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center)
            Button(L("Try again")) {
                Task { state.shop == nil ? state.reset() : await state.rediagnose() }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(L("Start over")) { state.reset() }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(32)
    }
}
