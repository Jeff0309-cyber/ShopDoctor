import SwiftUI
import SceneKit
#if canImport(UIKit)
import UIKit
#endif

/// The scanned shop as a clean "clay" dollhouse: white floor and low walls, furniture as soft
/// blocks, numbered pins on each issue, and green ghosts where the Doctor suggests moving things.
/// Drawn from the measured RoomSummary (not the raw scan), so it stays on-brand and works with sample rooms.
struct ShopModelView: View {
    let room: RoomSummary
    let issues: [ExperienceIssue]
    var done: Set<String> = []
    /// The issue the camera is focused on; nil shows the whole room.
    var focused: String?
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        #if os(iOS)
        ShopSceneRepresentable(room: room, issues: issues, done: done, focused: focused, onSelect: onSelect)
        #else
        Text("3D view is available on iPhone.")
        #endif
    }
}

#if os(iOS)
private struct ShopSceneRepresentable: UIViewRepresentable {
    let room: RoomSummary
    let issues: [ExperienceIssue]
    let done: Set<String>
    let focused: String?
    let onSelect: (String) -> Void

    func makeCoordinator() -> ShopScene { ShopScene(room: room, onSelect: onSelect) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.allowsCameraControl = true  // drag to orbit, pinch to zoom
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.maximumVerticalAngle = 85
        view.defaultCameraController.minimumVerticalAngle = 15
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .white
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(ShopScene.tapped(_:))))
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.show(issues: issues, done: done, focused: focused)
    }
}

/// Builds and updates the SceneKit scene. Plan (x, z) maps to scene (x, z) with y up;
/// the backend's angle_deg turns x toward z, which is a negative rotation about y.
final class ShopScene: NSObject {
    let scene = SCNScene()
    let camera = SCNNode()
    weak var view: SCNView?
    var onSelect: (String) -> Void

    private let room: RoomSummary
    private var nodes: [String: SCNNode] = [:]       // room ids → furniture/door nodes
    private var baseMaterials: [String: SCNMaterial] = [:]
    private let overlay = SCNNode()                   // pins, ghosts and arrows, rebuilt on change
    private var lastSignature = ""
    private var lastFocus: String?? = .none
    private let center: SCNVector3
    private let span: Float

    private static let wallHeight: Float = 0.45  // a low outline, so walls never hide the furniture

    init(room: RoomSummary, onSelect: @escaping (String) -> Void) {
        self.room = room
        self.onSelect = onSelect
        let xs = room.floor.map(\.x) + room.objects.map(\.x), zs = room.floor.map(\.z) + room.objects.map(\.z)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1, minZ = zs.min() ?? 0, maxZ = zs.max() ?? 1
        center = SCNVector3(Float(minX + maxX) / 2, 0, Float(minZ + maxZ) / 2)
        span = Float(max(maxX - minX, maxZ - minZ, 3))
        super.init()
        build()
    }

    // MARK: Building

    private func build() {
        scene.background.contents = UIColor.white
        scene.rootNode.addChildNode(overlay)

        // Floor
        if room.floor.count >= 3 {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: room.floor[0].x, y: room.floor[0].z))
            room.floor.dropFirst().forEach { path.addLine(to: CGPoint(x: $0.x, y: $0.z)) }
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: 0.04)
            shape.firstMaterial = Self.matte(UIColor(white: 0.985, alpha: 1))
            let floor = SCNNode(geometry: shape)
            floor.eulerAngles.x = .pi / 2  // path (x, y) → plan (x, z), extruding downward
            scene.rootNode.addChildNode(floor)
        }

        for e in room.elements {
            let node: SCNNode
            switch e.kind {
            case .wall:
                node = SCNNode(geometry: SCNBox(width: e.width, height: CGFloat(Self.wallHeight), length: 0.1, chamferRadius: 0.02))
                node.geometry?.firstMaterial = Self.matte(UIColor(white: 0.93, alpha: 1))
                node.position = SCNVector3(Float(e.x), Self.wallHeight / 2, Float(e.z))
            case .door, .opening:
                // A green threshold mat shows where customers come in.
                node = SCNNode(geometry: SCNBox(width: e.width, height: 0.03, length: 0.5, chamferRadius: 0.01))
                node.geometry?.firstMaterial = Self.matte(UIColor(Theme.primarySoft))
                node.position = SCNVector3(Float(e.x), 0.015, Float(e.z))
            case .window:
                // Windows: a pale-blue strip along the top of the wall.
                node = SCNNode(geometry: SCNBox(width: e.width, height: 0.06, length: 0.14, chamferRadius: 0.01))
                node.geometry?.firstMaterial = Self.matte(UIColor(red: 0.74, green: 0.86, blue: 0.96, alpha: 1))
                node.position = SCNVector3(Float(e.x), Self.wallHeight + 0.03, Float(e.z))
            }
            node.eulerAngles.y = -Float(e.angleDeg * .pi / 180)
            node.name = e.id
            nodes[e.id] = node
            scene.rootNode.addChildNode(node)
        }

        for o in room.objects {
            let node = Self.block(for: o, material: Self.material(for: o.category))
            node.name = o.id
            nodes[o.id] = node
            baseMaterials[o.id] = node.geometry?.firstMaterial
            scene.rootNode.addChildNode(node)
        }

        // Soft daylight: ambient fill plus one shadow-casting key light.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 600
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowColor = UIColor(white: 0, alpha: 0.18)
        key.light?.shadowRadius = 6
        key.light?.shadowSampleCount = 8
        key.eulerAngles = SCNVector3(-Float.pi / 2.6, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        camera.camera = SCNCamera()
        camera.camera?.projectionDirection = .horizontal  // fit the room's width, whatever the view's shape
        camera.camera?.fieldOfView = 58
        camera.camera?.zNear = 0.05
        placeCameraOverview(animated: false)
        scene.rootNode.addChildNode(camera)
    }

    private static func block(for o: RoomObject, material: SCNMaterial, dx: Double = 0, dz: Double = 0, rotate: Double = 0) -> SCNNode {
        let h = max(o.height, 0.05)
        let box = SCNBox(width: o.width, height: h, length: o.depth, chamferRadius: min(0.06, min(o.width, o.depth) / 4))
        box.firstMaterial = material
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(Float(o.x + dx), Float(h / 2), Float(o.z + dz))
        node.eulerAngles.y = -Float((o.angleDeg + rotate) * .pi / 180)
        node.castsShadow = true
        return node
    }

    private static func matte(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.9
        m.metalness.contents = 0.0
        return m
    }

    private static func material(for category: String) -> SCNMaterial {
        switch category {
        case "table": matte(UIColor(red: 0.91, green: 0.89, blue: 0.86, alpha: 1))
        case "chair", "sofa": matte(UIColor(white: 0.97, alpha: 1))
        case "storage": matte(UIColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1))
        default: matte(UIColor(red: 0.74, green: 0.79, blue: 0.84, alpha: 1))
        }
    }

    // MARK: Issues overlay

    func show(issues: [ExperienceIssue], done: Set<String>, focused: String?) {
        let signature = issues.map(\.id).joined() + done.sorted().joined() + (focused ?? "-")
        guard signature != lastSignature else { return }
        lastSignature = signature

        overlay.childNodes.forEach { $0.removeFromParentNode() }
        for (id, node) in nodes { node.geometry?.firstMaterial = baseMaterials[id] ?? node.geometry?.firstMaterial }

        let pinned = issues.enumerated().filter { $0.element.roomTarget != nil && nodes[$0.element.roomTarget!] != nil }
        for (index, issue) in pinned {
            guard let target = issue.roomTarget, let node = nodes[target] else { continue }
            let isDone = done.contains(issue.id)
            let dimmed = focused != nil && focused != issue.id

            // Tint the object the issue is about (amber, or red for high impact).
            if !isDone, room.objects.contains(where: { $0.id == target }) {
                let tint = issue.impact == .high ? UIColor(Theme.critical) : UIColor(Theme.warning)
                let m = Self.matte(tint.withAlphaComponent(1))
                m.diffuse.contents = tint.blended(with: .white, amount: dimmed ? 0.75 : 0.35)
                node.geometry?.firstMaterial = m
            }

            // Ghost + arrow for a suggested move.
            if let move = issue.suggestedMove, !isDone, let obj = room.objects.first(where: { $0.id == move.objectId }) {
                let ghostMaterial = Self.matte(UIColor(Theme.primary))
                ghostMaterial.transparency = dimmed ? 0.15 : 0.45
                let ghost = Self.block(for: obj, material: ghostMaterial, dx: move.dxM, dz: move.dzM, rotate: move.rotateDeg)
                ghost.castsShadow = false
                overlay.addChildNode(ghost)
                overlay.addChildNode(Self.dashedArrow(
                    from: SCNVector3(Float(obj.x), 0.05, Float(obj.z)),
                    to: SCNVector3(Float(obj.x + move.dxM), 0.05, Float(obj.z + move.dzM)),
                    opacity: dimmed ? 0.25 : 1))
            }

            // Numbered pin floating above the target.
            let top = node.boundingBox.max.y - node.boundingBox.min.y
            let pin = Self.pin(number: index + 1, done: isDone, high: issue.impact == .high)
            pin.position = SCNVector3(node.position.x, node.position.y + top / 2 + 0.45, node.position.z)
            pin.name = "pin:\(issue.id)"
            pin.opacity = dimmed ? 0.35 : 1
            overlay.addChildNode(pin)
            let stem = SCNNode(geometry: SCNCylinder(radius: 0.012, height: 0.32))
            stem.geometry?.firstMaterial = Self.matte(UIColor(Theme.ink).withAlphaComponent(0.5))
            stem.position = SCNVector3(pin.position.x, pin.position.y - 0.27, pin.position.z)
            stem.opacity = pin.opacity
            overlay.addChildNode(stem)
        }

        if lastFocus != .some(focused) {
            lastFocus = .some(focused)
            if let focused, let issue = issues.first(where: { $0.id == focused }), let target = issue.roomTarget, let node = nodes[target] {
                // Frame both the object and, for a suggested move, where it should go.
                var p = node.position, reach: Float = 0
                if let move = issue.suggestedMove {
                    p = SCNVector3(p.x + Float(move.dxM) / 2, p.y, p.z + Float(move.dzM) / 2)
                    reach = Float(hypot(move.dxM, move.dzM)) / 2
                }
                focus(on: p, reach: reach)
            } else if focused == nil {
                placeCameraOverview(animated: true)
            }
        }
    }

    private static func pin(number: Int, done: Bool, high: Bool) -> SCNNode {
        let size: CGFloat = 96
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let rect = CGRect(x: 6, y: 6, width: size - 12, height: size - 12)
            let fill = done ? UIColor(Theme.primary) : (high ? UIColor(Theme.critical) : UIColor(Theme.warning))
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: UIColor(white: 0, alpha: 0.25).cgColor)
            fill.setFill()
            UIBezierPath(ovalIn: rect).fill()
            ctx.cgContext.setShadow(offset: .zero, blur: 0)
            UIColor.white.setStroke()
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            ring.lineWidth = 5
            ring.stroke()
            let text = done ? "✓" : "\(number)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold).rounded(),
                .foregroundColor: UIColor.white,
            ]
            let t = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: CGPoint(x: (size - t.width) / 2, y: (size - t.height) / 2), withAttributes: attrs)
        }
        let plane = SCNPlane(width: 0.42, height: 0.42)
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.readsFromDepthBuffer = false  // always visible above the furniture
        plane.firstMaterial = m
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        node.renderingOrder = 10
        return node
    }

    private static func dashedArrow(from a: SCNVector3, to b: SCNVector3, opacity: CGFloat) -> SCNNode {
        let group = SCNNode()
        let dx = b.x - a.x, dz = b.z - a.z
        let length = sqrt(dx * dx + dz * dz)
        guard length > 0.05 else { return group }
        let dash: Float = 0.14, gapLen: Float = 0.09
        let angle = atan2(dx, dz)
        var t: Float = 0
        while t + dash < length - 0.18 {
            let seg = SCNNode(geometry: SCNBox(width: 0.05, height: 0.02, length: CGFloat(dash), chamferRadius: 0.01))
            seg.geometry?.firstMaterial = matte(UIColor(Theme.primaryDark))
            let mid = t + dash / 2
            seg.position = SCNVector3(a.x + dx * mid / length, a.y, a.z + dz * mid / length)
            seg.eulerAngles.y = angle
            group.addChildNode(seg)
            t += dash + gapLen
        }
        // Cone points +y; tip it to +z, then turn it to face along the arrow.
        let cone = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.2))
        cone.geometry?.firstMaterial = matte(UIColor(Theme.primaryDark))
        cone.eulerAngles.x = Float.pi / 2
        let head = SCNNode()
        head.addChildNode(cone)
        head.position = SCNVector3(b.x - dx / length * 0.1, a.y, b.z - dz / length * 0.1)
        head.eulerAngles.y = angle
        group.addChildNode(head)
        group.opacity = opacity
        return group
    }

    // MARK: Camera

    // The camera stands on the entrance side of the room (low plan z, where doors usually are),
    // so the owner sees the shop the way a customer walks into it.
    private var entranceSide: Float {
        let doors = room.elements.filter { $0.kind == .door }
        guard !doors.isEmpty else { return -1 }
        let doorZ = doors.map { Float($0.z) }.reduce(0, +) / Float(doors.count)
        return doorZ <= center.z ? -1 : 1
    }

    private func placeCameraOverview(animated: Bool) {
        moveCamera(to: SCNVector3(center.x, span * 0.8, center.z + entranceSide * span * 0.75),
                   lookAt: SCNVector3(center.x, 0, center.z + entranceSide * span * 0.05), animated: animated)
    }

    private func focus(on p: SCNVector3, reach: Float) {
        let d = 3.4 + reach * 1.6
        moveCamera(to: SCNVector3(p.x, d * 1.05, p.z + entranceSide * d),
                   lookAt: SCNVector3(p.x, 0.2, p.z), animated: true)
    }

    private func moveCamera(to position: SCNVector3, lookAt target: SCNVector3, animated: Bool) {
        view?.pointOfView = camera  // take back control from any manual orbit
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.8 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        camera.position = position
        camera.look(at: target)
        SCNTransaction.commit()
        view?.defaultCameraController.target = target
    }

    @objc func tapped(_ gesture: UITapGestureRecognizer) {
        guard let view else { return }
        let hits = view.hitTest(gesture.location(in: view), options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        if let name = hits.lazy.compactMap({ $0.node.name }).first(where: { $0.hasPrefix("pin:") }) {
            onSelect(String(name.dropFirst(4)))
        }
    }
}

private extension UIColor {
    func blended(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount, blue: b1 + (b2 - b1) * amount, alpha: 1)
    }
}

private extension UIFont {
    func rounded() -> UIFont {
        guard let d = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: d, size: pointSize)
    }
}
#endif
