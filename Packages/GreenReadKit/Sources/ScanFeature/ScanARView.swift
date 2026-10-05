import ARKit
import Combine
import GreenReadCore
import Observation
import RealityKit
import SwiftUI

/// Screen-space geometry for the SwiftUI overlay, refreshed every frame from the AR scene.
@MainActor
@Observable
final class ScanOverlay {
    var ball: CGPoint?
    var hole: CGPoint?
    /// Covered corridor cells as screen quads (lime paint).
    var paint: [[CGPoint]] = []
    var line: [CGPoint] = []
    var aimPoint: CGPoint?

    init() {}

    init(ball: CGPoint?, hole: CGPoint?, paint: [[CGPoint]] = [], line: [CGPoint] = [], aimPoint: CGPoint? = nil) {
        self.ball = ball
        self.hole = hole
        self.paint = paint
        self.line = line
        self.aimPoint = aimPoint
    }
}

/// What the AR view should be doing.
struct ScanARConfiguration: Equatable {
    enum Stage: Equatable { case mark, scanning, paused, result }

    var stage: Stage
    var ball: SIMD3<Float>?
    var hole: SIMD3<Float>?
    var scanID: Int
    /// Lateral aim in metres (right of the hole is positive), once there's a result.
    var aimMetres: Double?
}

/// LiDAR camera view. Taps raycast onto the green; while scanning, mesh anchors are binned
/// into the ball→hole corridor by `CorridorScanner`, and progress is reported about 5× a second.
struct ScanARView: UIViewRepresentable {
    let configuration: ScanARConfiguration
    let overlay: ScanOverlay
    let onTap: (SIMD3<Float>) -> Void
    let onProgress: (ScanProgress) -> Void
    let onBrightSun: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(overlay: overlay)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let session = ARWorldTrackingConfiguration()
        session.planeDetection = [.horizontal]
        session.sceneReconstruction = .mesh
        session.isLightEstimationEnabled = true
        view.session.delegateQueue = context.coordinator.queue
        view.session.delegate = context.coordinator
        view.session.run(session)
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        )
        context.coordinator.view = view
        context.coordinator.subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator = context.coordinator] _ in
            coordinator?.project()
        }
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        coordinator.onProgress = onProgress
        coordinator.onBrightSun = onBrightSun
        coordinator.apply(configuration)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        view.session.pause()
        coordinator.subscription?.cancel()
    }

    /// Lives on the main actor for UIKit and projection; scan maths runs on `queue`.
    final class Coordinator: NSObject, ARSessionDelegate, @unchecked Sendable {
        let queue = DispatchQueue(label: "com.garethlloyd.greenread.scan", qos: .userInitiated)
        let overlay: ScanOverlay
        weak var view: ARView?
        var subscription: (any Cancellable)?
        var onTap: (SIMD3<Float>) -> Void = { _ in }
        var onProgress: (ScanProgress) -> Void = { _ in }
        var onBrightSun: (Bool) -> Void = { _ in }

        // Main actor
        private var configuration = ScanARConfiguration(stage: .mark, scanID: 0)
        private var paintCells: [(u: Double, v: Double)] = []
        private var paintGeometry: CorridorScanner?
        private var lineWorld: [SIMD3<Float>] = []
        private var aimWorld: SIMD3<Float>?

        // Queue
        private var scanner: CorridorScanner?
        private var isScanning = false
        private var lastReport = Date.distantPast
        private var lastCamera: (position: SIMD3<Float>, time: TimeInterval)?
        private var fastSince: TimeInterval?
        private var isMovingFast = false
        private var brightSince: TimeInterval?
        private var isBright = false

        init(overlay: ScanOverlay) {
            self.overlay = overlay
        }

        // MARK: Configuration (main)

        @MainActor
        func apply(_ new: ScanARConfiguration) {
            let old = configuration
            configuration = new
            if new.scanID != old.scanID {
                paintCells = []
                paintGeometry = nil
                queue.async { self.scanner = nil }
            }
            if new.stage == .scanning, let ball = new.ball, let hole = new.hole, paintGeometry == nil {
                let geometry = CorridorScanner(ball: Point3(ball), hole: Point3(hole))
                paintGeometry = geometry
                let anchors = view?.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
                queue.async {
                    var scanner = geometry
                    for anchor in anchors { scanner.update(anchor: anchor.identifier.uuidString, vertices: anchor.worldVertices) }
                    self.scanner = scanner
                }
            }
            let scanning = new.stage == .scanning
            queue.async { self.isScanning = scanning }
            updateLine()
        }

        @MainActor
        private func updateLine() {
            guard let aimMetres = configuration.aimMetres, let geometry = paintGeometry,
                  let ball = configuration.ball, let hole = configuration.hole
            else {
                lineWorld = []
                aimWorld = nil
                return
            }
            let height = { (u: Double) in Double(ball.y) + (Double(hole.y) - Double(ball.y)) * u / geometry.length + 0.005 }
            lineWorld = BreakLine.points(length: geometry.length, aimMetres: aimMetres).map {
                SIMD3(geometry.world(u: $0.u, v: $0.v, y: height($0.u)))
            }
            aimWorld = SIMD3(geometry.world(u: geometry.length, v: aimMetres, y: height(geometry.length)))
        }

        // MARK: Taps (main)

        @MainActor @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard configuration.stage == .mark, let view else { return }
            let location = recognizer.location(in: view)
            guard let hit = view.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first
            else { return }
            let column = hit.worldTransform.columns.3
            onTap(SIMD3(column.x, column.y, column.z))
        }

        // MARK: Projection (main, every frame)

        @MainActor
        func project() {
            guard let view else { return }
            let project = { (point: SIMD3<Float>) in view.project(point) }
            overlay.ball = configuration.ball.flatMap(project)
            overlay.hole = configuration.hole.flatMap(project)
            if configuration.stage == .scanning || configuration.stage == .paused, let geometry = paintGeometry,
               let ball = configuration.ball, let hole = configuration.hole {
                let half = CorridorScanner.cellSize / 2
                overlay.paint = paintCells.compactMap { cell in
                    let height = Double(ball.y) + (Double(hole.y) - Double(ball.y)) * cell.u / geometry.length
                    let corners = [(-half, -half), (half, -half), (half, half), (-half, half)].compactMap { du, dv in
                        project(SIMD3(geometry.world(u: cell.u + du, v: cell.v + dv, y: height)))
                    }
                    return corners.count == 4 ? corners : nil
                }
            } else {
                overlay.paint = []
            }
            overlay.line = lineWorld.compactMap(project)
            overlay.aimPoint = aimWorld.flatMap(project)
        }

        // MARK: ARSessionDelegate (queue)

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            ingest(anchors)
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            ingest(anchors)
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors where anchor is ARMeshAnchor {
                scanner?.remove(anchor: anchor.identifier.uuidString)
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            trackMovement(frame)
            trackLight(frame)
            reportIfDue()
        }

        private func ingest(_ anchors: [ARAnchor]) {
            guard isScanning, scanner != nil else { return }
            for case let anchor as ARMeshAnchor in anchors {
                scanner?.update(anchor: anchor.identifier.uuidString, vertices: anchor.worldVertices)
            }
        }

        private func trackMovement(_ frame: ARFrame) {
            let column = frame.camera.transform.columns.3
            let position = SIMD3(column.x, column.y, column.z)
            defer { lastCamera = (position, frame.timestamp) }
            guard let last = lastCamera, frame.timestamp > last.time else { return }
            let speed = Double(simd_distance(position, last.position)) / (frame.timestamp - last.time)
            if speed > 0.8 {
                fastSince = fastSince ?? frame.timestamp
                isMovingFast = frame.timestamp - (fastSince ?? frame.timestamp) > 0.4
            } else {
                fastSince = nil
                isMovingFast = false
            }
        }

        private func trackLight(_ frame: ARFrame) {
            guard let intensity = frame.lightEstimate?.ambientIntensity else { return }
            // ~1000 lumens is a well-lit room; direct sun reads far higher. Hold for 2 s to avoid flicker.
            let bright = intensity > 2000
            if bright != isBright {
                brightSince = brightSince ?? frame.timestamp
                if frame.timestamp - (brightSince ?? frame.timestamp) > 2 {
                    isBright = bright
                    brightSince = nil
                    DispatchQueue.main.async { self.onBrightSun(bright) }
                }
            } else {
                brightSince = nil
            }
        }

        private func reportIfDue() {
            guard isScanning, let scanner, Date().timeIntervalSince(lastReport) > 0.2 else { return }
            lastReport = Date()
            var progress = scanner.progress
            if isMovingFast { progress.prompt = .slowDown }
            let cells = scanner.coveredCells
            DispatchQueue.main.async {
                self.paintCells = cells
                self.onProgress(progress)
            }
        }
    }
}

extension ARMeshAnchor {
    /// Mesh vertices in world space.
    var worldVertices: [Point3] {
        let vertices = geometry.vertices
        let transform = self.transform
        var points: [Point3] = []
        points.reserveCapacity(vertices.count)
        let pointer = vertices.buffer.contents().advanced(by: vertices.offset)
        for index in 0..<vertices.count {
            let vertex = pointer.advanced(by: vertices.stride * index).assumingMemoryBound(to: (Float, Float, Float).self).pointee
            let world = transform * SIMD4(vertex.0, vertex.1, vertex.2, 1)
            points.append(Point3(x: Double(world.x), y: Double(world.y), z: Double(world.z)))
        }
        return points
    }
}

extension Point3 {
    init(_ point: SIMD3<Float>) {
        self.init(x: Double(point.x), y: Double(point.y), z: Double(point.z))
    }
}

extension SIMD3 where Scalar == Float {
    init(_ point: Point3) {
        self.init(Float(point.x), Float(point.y), Float(point.z))
    }
}
