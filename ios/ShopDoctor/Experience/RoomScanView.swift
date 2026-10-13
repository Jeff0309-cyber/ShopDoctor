import SwiftUI
#if canImport(RoomPlan) && os(iOS)
import RoomPlan
import simd
#endif

enum RoomScanner {
    /// LiDAR iPhones/iPads (12 Pro and later) can run Apple's RoomPlan scan.
    static var isSupported: Bool {
        #if canImport(RoomPlan) && os(iOS)
        RoomCaptureSession.isSupported
        #else
        false
        #endif
    }
}

#if canImport(RoomPlan) && os(iOS)

/// Full-screen RoomPlan capture with Apple's live coaching. Calls `onFinish` with the
/// measured room once the owner taps Done and RoomPlan has processed the scan.
struct RoomScanView: View {
    let onFinish: (RoomSummary) -> Void
    let onCancel: () -> Void
    @State private var controller = RoomScanController()

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureContainer(controller: controller)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                if controller.processing {
                    Label(L("Building your 3D model…"), systemImage: "cube.transparent")
                        .font(Theme.headline(15)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.6), in: Capsule())
                } else {
                    Text(L("Walk slowly along the walls. Point at every table and the counter."))
                        .font(Theme.caption).foregroundStyle(.white).multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                    HStack(spacing: 12) {
                        Button(L("Cancel")) { controller.cancel(); onCancel() }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 120)
                        Button(L("Done scanning")) { controller.finish() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(Theme.gutter)
        }
        .onAppear {
            controller.onResult = { room in onFinish(RoomSummary(captured: room)) }
        }
    }
}

@Observable
final class RoomScanController: NSObject, RoomCaptureViewDelegate {
    @ObservationIgnored let captureView = RoomCaptureView(frame: .zero)
    var processing = false
    @ObservationIgnored var onResult: (CapturedRoom) -> Void = { _ in }

    override init() {
        super.init()
        captureView.delegate = self
    }

    // RoomCaptureViewDelegate inherits NSCoding; this controller is never archived.
    required init?(coder: NSCoder) { nil }
    func encode(with coder: NSCoder) {}

    func start() { captureView.captureSession.run(configuration: RoomCaptureSession.Configuration()) }

    func finish() {
        processing = true
        captureView.captureSession.stop()  // RoomPlan then processes and calls didPresent
    }

    func cancel() { captureView.captureSession.stop() }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        processing = false
        onResult(processedResult)
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    let controller: RoomScanController
    func makeUIView(context: Context) -> RoomCaptureView {
        controller.start()
        return controller.captureView
    }
    func updateUIView(_ view: RoomCaptureView, context: Context) {}
}

// MARK: - CapturedRoom → RoomSummary

extension RoomSummary {
    /// Flattens RoomPlan's 3D result onto the floor plan, with readable ids ("table-3", "door-1").
    init(captured room: CapturedRoom) {
        func plan(_ t: simd_float4x4) -> (x: Double, z: Double, angle: Double) {
            // Rotation about y: column 0 is (cos θ, 0, −sin θ); our angle turns x toward z, i.e. −θ.
            let c0 = t.columns.0
            return (Double(t.columns.3.x), Double(t.columns.3.z), Double(atan2(c0.z, c0.x)) * 180 / .pi)
        }

        var elements: [RoomElement] = []
        func add(_ surfaces: [CapturedRoom.Surface], kind: RoomElement.Kind) {
            for (n, s) in surfaces.enumerated() {
                let p = plan(s.transform)
                elements.append(RoomElement(id: "\(kind.rawValue)-\(n + 1)", kind: kind, x: p.x, z: p.z,
                                            width: Double(s.dimensions.x), height: Double(s.dimensions.y), angleDeg: p.angle))
            }
        }
        add(room.walls, kind: .wall)
        add(room.doors, kind: .door)
        add(room.windows, kind: .window)
        add(room.openings, kind: .opening)

        var counts: [String: Int] = [:]
        let objects: [RoomObject] = room.objects.map { o in
            let category = String(describing: o.category)
            counts[category, default: 0] += 1
            let p = plan(o.transform)
            return RoomObject(id: "\(category)-\(counts[category]!)", category: category, x: p.x, z: p.z,
                              width: Double(o.dimensions.x), depth: Double(o.dimensions.z),
                              height: Double(o.dimensions.y), angleDeg: p.angle)
        }

        // Floor outline: the convex hull of the wall ends (RoomPlan's floor polygons vary by OS version).
        var ends: [PlanPoint] = []
        for w in elements where w.kind == .wall {
            let a = w.angleDeg * .pi / 180, h = w.width / 2
            ends.append(PlanPoint(x: w.x - h * cos(a), z: w.z - h * sin(a)))
            ends.append(PlanPoint(x: w.x + h * cos(a), z: w.z + h * sin(a)))
        }
        self.init(floor: Self.convexHull(ends), elements: elements, objects: objects)
    }
}

#endif

extension RoomSummary {
    /// Andrew's monotone chain; returns the hull counter-clockwise.
    static func convexHull(_ points: [PlanPoint]) -> [PlanPoint] {
        let pts = points.sorted { ($0.x, $0.z) < ($1.x, $1.z) }
        guard pts.count >= 3 else { return pts }
        func cross(_ o: PlanPoint, _ a: PlanPoint, _ b: PlanPoint) -> Double {
            (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
        }
        var lower: [PlanPoint] = [], upper: [PlanPoint] = []
        for p in pts {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        for p in pts.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }
}
