import Foundation

/// Slice math for a wheel with `sliceCount` equal slices.
///
/// Angles are in radians, measured clockwise from 12 o'clock. Slice 0 is centered
/// straight up, slice 1 is next clockwise, and so on. Offsets are in a y-up coordinate
/// space (like AppKit screen coordinates): positive `dy` is toward the top of the screen.
public struct WheelGeometry: Equatable, Sendable {
    public var sliceCount: Int
    /// Inside this distance from the center no slice is selected (letting go cancels).
    public var deadZoneRadius: Double

    public init(sliceCount: Int, deadZoneRadius: Double) {
        self.sliceCount = sliceCount
        self.deadZoneRadius = deadZoneRadius
    }

    /// The angle each slice covers.
    public var sliceAngle: Double { sliceCount > 0 ? 2 * .pi / Double(sliceCount) : 0 }

    /// The slice the cursor points at, or nil in the dead zone or on an empty wheel.
    /// The cursor can be beyond the ring: only the direction matters (a flick).
    public func sliceIndex(dx: Double, dy: Double) -> Int? {
        guard sliceCount > 0, (dx * dx + dy * dy).squareRoot() >= deadZoneRadius else { return nil }
        if sliceCount == 1 { return 0 }
        let angle = WheelGeometry.clockwiseAngle(dx: dx, dy: dy)
        let index = Int(((angle + sliceAngle / 2) / sliceAngle).rounded(.down))
        return index % sliceCount
    }

    /// Clockwise angle from 12 o'clock, in 0..<2π.
    public static func clockwiseAngle(dx: Double, dy: Double) -> Double {
        let angle = atan2(dx, dy)
        return angle < 0 ? angle + 2 * .pi : angle
    }

    /// Where slice `index` starts and ends (clockwise from 12 o'clock). `start` can be
    /// negative for slice 0, since it straddles the top.
    public func bounds(ofSlice index: Int) -> (start: Double, end: Double) {
        let center = centerAngle(ofSlice: index)
        return (center - sliceAngle / 2, center + sliceAngle / 2)
    }

    public func centerAngle(ofSlice index: Int) -> Double { Double(index) * sliceAngle }

    /// A point at `angle` and `radius` from the center, as a y-up offset.
    public static func offset(angle: Double, radius: Double) -> (dx: Double, dy: Double) {
        (sin(angle) * radius, cos(angle) * radius)
    }
}
