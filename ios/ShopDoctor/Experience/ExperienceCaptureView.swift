import SwiftUI
import PhotosUI

/// Entry point from the dashboard tile: the latest result, or the capture flow if there isn't one.
struct ExperienceHubView: View {
    @Environment(AppState.self) private var state
    @State private var rechecking = false

    var body: some View {
        Group {
            if let audit = state.experience, !rechecking {
                ExperienceResultView(audit: audit) { rechecking = true }
            } else {
                ExperienceCaptureView { rechecking = false }
            }
        }
        .navigationTitle(L("Shop experience"))
        .largeNavigationTitle()
    }
}

/// Scan (LiDAR) or sample room, then the guided photos, then analysis.
struct ExperienceCaptureView: View {
    @Environment(AppState.self) private var state
    let onDone: () -> Void

    @State private var room: RoomSummary?
    @State private var photos: [Shot: Data] = [:]
    @State private var scanning = false
    @State private var analysing = false
    @State private var resultReady = false
    @State private var error: String?

    private var required: [Shot] { Shot.required(withScan: room != nil) }
    private var ready: Bool { required.allSatisfy { photos[$0] != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("Let the Doctor walk through your shop the way a customer does. It takes about 5 minutes."))
                    .font(Theme.body).foregroundStyle(Theme.inkSecondary)
                scanCard
                rulesCard
                Text(room == nil ? L("Photos") : L("Detail photos"))
                    .font(Theme.headline()).foregroundStyle(Theme.ink).padding(.top, 4)
                ForEach(Shot.shown(withScan: room != nil)) { shot in
                    ShotCard(shot: shot, required: required.contains(shot), data: $photos[shot])
                }
                Button { analyse() } label: {
                    HStack(spacing: 8) { Text(L("Analyse my shop")); Image(systemName: "stethoscope") }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: ready))
                .disabled(!ready)
                if !ready {
                    Text(L("Add the required photos to continue."))
                        .font(Theme.caption).foregroundStyle(Theme.inkSecondary).frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.gutter)
        }
        .background(Theme.surface.opacity(0.5))
        #if canImport(RoomPlan) && os(iOS)
        .fullScreenCover(isPresented: $scanning) {
            RoomScanView(onFinish: { summary in
                room = summary
                scanning = false
            }, onCancel: { scanning = false })
        }
        #endif
        .fullScreenCover(isPresented: $analysing) {
            ExperienceAnalysingView(resultReady: resultReady) {
                analysing = false
                onDone()
            }
        }
        .alert(L("Something went wrong"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(L("Try again")) { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: Scan card

    private var scanCard: some View {
        Card {
            SectionTitle(title: L("3D scan"), subtitle: L("Measures your layout: seats, aisles and doorways"), icon: "cube.transparent")
            if let room {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                    Text(L("%lld tables · %@ m² scanned", room.tableCount, room.floorArea.formatted(.number.precision(.fractionLength(0)))))
                        .font(Theme.body.weight(.semibold)).foregroundStyle(Theme.ink)
                }
                Button(RoomScanner.isSupported ? L("Scan again") : L("Remove sample room")) {
                    if RoomScanner.isSupported { scanning = true } else { self.room = nil }
                }
                .buttonStyle(SecondaryButtonStyle())
            } else if RoomScanner.isSupported {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([L("Turn all the lights on. Empty is best, before opening."),
                             L("Start at the door and walk slowly along the walls."),
                             L("Point the camera at every table, the counter and the doorway.")], id: \.self) {
                        Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                    }
                }
                Button { scanning = true } label: {
                    HStack(spacing: 8) { Text(L("Start 3D scan")); Image(systemName: "viewfinder") }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Text(L("3D scanning needs an iPhone Pro with LiDAR. We'll use photos instead."))
                    .font(Theme.body).foregroundStyle(Theme.inkSecondary)
                if state.demoMode {
                    Button {
                        Task { room = try? await state.api.demoRoom() }
                    } label: {
                        Label(L("Load sample room"), systemImage: "cube")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var rulesCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill").foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Before you shoot")).font(Theme.headline(15)).foregroundStyle(Theme.ink)
                Text(L("No customers' or staff faces. Lights on, phone held sideways."))
                    .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    // MARK: Analyse

    private func analyse() {
        guard let shopID = state.shop?.id else { return }
        resultReady = false
        analysing = true
        Task {
            do {
                let audit = try await state.api.runExperience(shopID: shopID, room: room, photos: photos)
                ExperienceStore.savePhotos(photos)
                state.experience = audit
                resultReady = true
            } catch {
                analysing = false
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - One guided shot

private struct ShotCard: View {
    let shot: Shot
    let required: Bool
    @Binding var data: Data?
    @State private var pick: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Theme.primarySoft
                    Image(systemName: shot.icon).font(.title3).foregroundStyle(Theme.primaryDark)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shot.title).font(Theme.headline(15)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 4)
                    if data != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                    } else {
                        Pill(text: required ? L("Required") : L("Optional"), tint: required ? Theme.primaryDark : Theme.inkSecondary)
                    }
                }
                Text(shot.guideline).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                Menu {
                    if CameraPicker.isAvailable {
                        Button { showCamera = true } label: { Label(L("Take photo"), systemImage: "camera") }
                    }
                    Button { showLibrary = true } label: { Label(L("Choose from library"), systemImage: "photo") }
                    if data != nil {
                        Button(role: .destructive) { data = nil } label: { Label(L("Remove"), systemImage: "trash") }
                    }
                } label: {
                    Text(data == nil ? L("Add photo") : L("Retake"))
                        .font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primaryDark)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
        .photosPicker(isPresented: $showLibrary, selection: $pick, matching: .images)
        .onChange(of: pick) { _, item in
            Task {
                if let raw = try? await item?.loadTransferable(type: Data.self) { data = ImageEncoding.jpeg(from: raw) }
                pick = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { raw in data = ImageEncoding.jpeg(from: raw) }.ignoresSafeArea()
        }
    }
}

/// The system camera, for taking the shots on the spot.
struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    let onPhoto: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onPhoto(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: - Analysing

/// Same visual language as the diagnosis loader; holds until the steps have played out and the result is in.
private struct ExperienceAnalysingView: View {
    let resultReady: Bool
    let onFinished: () -> Void
    @State private var stage = 0
    @State private var thoughtThrough = false

    private let stages = ["Measuring your layout", "Walking in as a customer", "Checking tables and counter",
                          "Comparing with busy HK shops", "Writing your fix plan"]
    private var finished: Bool { resultReady && thoughtThrough }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            CrossTraceLoader(complete: finished, size: 96, onDone: onFinished)
            Text(finished ? L("Fix plan ready") : L("Examining your shop"))
                .font(Theme.title(24)).foregroundStyle(Theme.ink).contentTransition(.interpolate)
                .animation(.snappy, value: finished)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(stages.indices, id: \.self) { i in
                    let done = i < stage || finished, current = i == stage && !finished
                    HStack(spacing: 12) {
                        Group {
                            if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary) }
                            else if current { ProgressView().controlSize(.small) }
                            else { Image(systemName: "circle").foregroundStyle(Theme.inkMuted) }
                        }
                        .frame(width: 22)
                        Group { if current { ScrambleText(text: L(stages[i])) } else { Text(L(stages[i])) } }
                            .font(Theme.body.weight(current ? .semibold : .regular))
                            .foregroundStyle(done || current ? Theme.ink : Theme.inkMuted)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            Spacer()
        }
        .padding(Theme.gutter)
        .background(Theme.background)
        .task {
            for i in 1..<stages.count {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { stage = i }
            }
            try? await Task.sleep(for: .seconds(1.5))
            thoughtThrough = true
        }
    }
}
