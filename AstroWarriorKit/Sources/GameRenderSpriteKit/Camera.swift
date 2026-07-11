import CoreGraphics
import GameSim

// Resolution independence (§6.3): lock the gameplay-critical axis (width), flex height.
public struct Camera {
    public let viewport: CGSize
    public var policy: VerticalPolicy

    public init(viewport: CGSize, policy: VerticalPolicy = .extendedField) {
        self.viewport = viewport; self.policy = policy
    }

    // Fit the whole 256×192 field into the window, preserving aspect (square pixels).
    // Wide windows pillarbox; tall windows letterbox — the field is never distorted.
    public var scale: Double {
        min(Double(viewport.width) / LOGICAL_WIDTH, Double(viewport.height) / LOGICAL_HEIGHT)
    }
    public var visibleHeight: Double { Double(viewport.height) / scale }

    public func project(_ p: Vec2) -> CGPoint {
        CGPoint(x: p.x * scale, y: p.y * scale)
    }

    /// Scene-space point of the field's centre — the camera parks here so the field is centred.
    public var fieldCenter: CGPoint {
        CGPoint(x: LOGICAL_WIDTH / 2 * scale, y: LOGICAL_HEIGHT / 2 * scale)
    }
}

public enum VerticalPolicy: Sendable { case extendedField, fixedWindow, showMore }
