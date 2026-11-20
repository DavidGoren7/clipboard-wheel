import Testing
@testable import ClipboardWheelCore

@Suite("Wheel geometry")
struct WheelGeometryTests {
    let deadZone = 30.0

    @Test func deadZoneSelectsNothing() {
        let wheel = WheelGeometry(sliceCount: 8, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: 0, dy: 0) == nil)
        #expect(wheel.sliceIndex(dx: 10, dy: -20) == nil)
    }

    @Test func emptyWheelSelectsNothing() {
        let wheel = WheelGeometry(sliceCount: 0, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: 0, dy: 100) == nil)
    }

    @Test func singleSliceIsTheWholeRing() {
        let wheel = WheelGeometry(sliceCount: 1, deadZoneRadius: deadZone)
        for (dx, dy) in [(0.0, 100.0), (100, 0), (0, -100), (-100, 0)] {
            #expect(wheel.sliceIndex(dx: dx, dy: dy) == 0)
        }
    }

    @Test func twoSlicesAreTopAndBottomHalves() {
        let wheel = WheelGeometry(sliceCount: 2, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: 0, dy: 100) == 0)
        #expect(wheel.sliceIndex(dx: 0, dy: -100) == 1)
        #expect(wheel.sliceIndex(dx: 100, dy: 1) == 0)
        #expect(wheel.sliceIndex(dx: 100, dy: -1) == 1)
    }

    @Test func fourSlicesGoClockwiseFromTop() {
        let wheel = WheelGeometry(sliceCount: 4, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: 0, dy: 100) == 0)  // up
        #expect(wheel.sliceIndex(dx: 100, dy: 0) == 1)  // right
        #expect(wheel.sliceIndex(dx: 0, dy: -100) == 2) // down
        #expect(wheel.sliceIndex(dx: -100, dy: 0) == 3) // left
    }

    @Test func slightlyLeftOfTopIsStillSliceZero() {
        let wheel = WheelGeometry(sliceCount: 8, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: -10, dy: 100) == 0)
    }

    @Test func flickBeyondTheRingStillSelectsByDirection() {
        let wheel = WheelGeometry(sliceCount: 4, deadZoneRadius: deadZone)
        #expect(wheel.sliceIndex(dx: 5_000, dy: 0) == 1)
    }

    @Test(arguments: 1...12)
    func everySliceCenterMapsBackToItsIndex(sliceCount: Int) {
        let wheel = WheelGeometry(sliceCount: sliceCount, deadZoneRadius: deadZone)
        for index in 0..<sliceCount {
            let (dx, dy) = WheelGeometry.offset(angle: wheel.centerAngle(ofSlice: index), radius: 100)
            #expect(wheel.sliceIndex(dx: dx, dy: dy) == index)
        }
    }

    @Test func boundsStraddleTheTopForSliceZero() {
        let wheel = WheelGeometry(sliceCount: 4, deadZoneRadius: deadZone)
        let bounds = wheel.bounds(ofSlice: 0)
        #expect(abs(bounds.start + .pi / 4) < 1e-9)
        #expect(abs(bounds.end - .pi / 4) < 1e-9)
    }
}
