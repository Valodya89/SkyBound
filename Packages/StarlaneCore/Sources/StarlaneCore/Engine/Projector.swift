import Foundation

/// A point projected from track space to screen space. `y` is measured from the top edge.
public struct Projected: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let scale: Double
}

/// The fake-3D camera: a single vanishing point, three lanes converging on the horizon.
///
/// All gameplay thresholds are expressed relative to the viewport width so the simulation behaves the
/// same on every device.
public struct Projector: Sendable, Hashable {
    public static let cameraDistance: Double = 190
    public static let maxDepth: Double = 1500

    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }

    public var horizonY: Double { height * 0.42 }
    public var playerY: Double { height * 0.80 }
    public var laneSpacing: Double { width * 0.235 }

    public func laneX(_ lane: Int) -> Double {
        width / 2 + Double(lane - 1) * laneSpacing
    }

    public func scale(atDepth z: Double) -> Double {
        Self.cameraDistance / (Self.cameraDistance + max(z, -Self.cameraDistance * 0.7))
    }

    public func project(lane: Int, z: Double) -> Projected {
        project(x: laneX(lane), z: z)
    }

    public func project(x groundX: Double, z: Double) -> Projected {
        let s = scale(atDepth: z)
        return Projected(x: width / 2 + (groundX - width / 2) * s,
                         y: horizonY + (playerY - horizonY) * s,
                         scale: s)
    }

    /// How strongly an object at depth `z` should blend into the horizon haze (0…0.62).
    /// Kept moderate so obstacles are readable well before they arrive.
    public func fogAmount(atDepth z: Double) -> Double {
        let t = min(max(z / Self.maxDepth, 0), 1)
        return t * t * 0.62
    }
}
