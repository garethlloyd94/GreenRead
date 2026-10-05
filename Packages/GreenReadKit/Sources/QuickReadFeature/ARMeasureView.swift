import ARKit
import DesignSystem
import RealityKit
import SwiftUI

/// Live camera with horizontal-plane tracking. Taps raycast onto the green and report the
/// world point; markers for the ball (white) and hole (black, white rim) follow `points`.
struct ARMeasureView: UIViewRepresentable {
    let points: [SIMD3<Float>]
    let onTap: (SIMD3<Float>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration)
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        )
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.sync(points)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        view.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onTap: (SIMD3<Float>) -> Void
        weak var view: ARView?
        private var anchors: [AnchorEntity] = []

        init(onTap: @escaping (SIMD3<Float>) -> Void) {
            self.onTap = onTap
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let location = recognizer.location(in: view)
            guard let hit = view.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first
            else { return }
            let column = hit.worldTransform.columns.3
            onTap(SIMD3(column.x, column.y, column.z))
        }

        func sync(_ points: [SIMD3<Float>]) {
            guard let view else { return }
            while anchors.count > points.count {
                view.scene.removeAnchor(anchors.removeLast())
            }
            for index in anchors.count..<points.count {
                let anchor = AnchorEntity(world: points[index])
                anchor.addChild(index == 0 ? Self.ball() : Self.hole())
                view.scene.addAnchor(anchor)
                anchors.append(anchor)
            }
        }

        private static func ball() -> ModelEntity {
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 0.0214),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            entity.position.y = 0.0214
            return entity
        }

        private static func hole() -> ModelEntity {
            let rim = ModelEntity(
                mesh: .generatePlane(width: 0.128, depth: 0.128, cornerRadius: 0.064),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            let cup = ModelEntity(
                mesh: .generatePlane(width: 0.108, depth: 0.108, cornerRadius: 0.054),
                materials: [SimpleMaterial(color: UIColor(GRColor.ink), isMetallic: false)]
            )
            cup.position.y = 0.001
            rim.addChild(cup)
            return rim
        }
    }
}
