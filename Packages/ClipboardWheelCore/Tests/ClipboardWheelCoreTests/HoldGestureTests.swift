import Testing
@testable import ClipboardWheelCore

private let cmdV = HoldGesture.Input.keyDown(.v, command: true, otherModifiers: false, isRepeat: false)
private let cmdVRepeat = HoldGesture.Input.keyDown(.v, command: true, otherModifiers: false, isRepeat: true)
private let plainVRepeat = HoldGesture.Input.keyDown(.v, command: false, otherModifiers: false, isRepeat: true)
private let escape = HoldGesture.Input.keyDown(.escape, command: true, otherModifiers: false, isRepeat: false)

@Suite("⌘V tap vs hold")
struct HoldGestureTests {
    @Test func tapPastesNormally() {
        var gesture = HoldGesture()
        #expect(gesture.handle(cmdV) == .init(swallow: true, actions: [.startHoldTimer]))
        #expect(gesture.handle(.keyUp(.v)) == .init(swallow: true, actions: [.cancelHoldTimer, .pasteNormally]))
        #expect(gesture.state == .idle)
    }

    @Test func holdOpensWheelAndReleaseCommits() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        #expect(gesture.handle(.holdTimerFired).actions == [.openWheel])
        #expect(gesture.state == .open)
        #expect(gesture.handle(.keyUp(.v)) == .init(swallow: true, actions: [.commitSelection]))
        #expect(gesture.state == .idle)
    }

    @Test func autoRepeatIsSwallowedWhileHolding() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        #expect(gesture.handle(cmdVRepeat) == .init(swallow: true, actions: []))
        _ = gesture.handle(.holdTimerFired)
        #expect(gesture.handle(cmdVRepeat) == .init(swallow: true, actions: []))
    }

    @Test func releasingCommandFirstCommitsAndHidesTheStrayV() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.holdTimerFired)

        let reaction = gesture.handle(.commandReleased)
        #expect(reaction == .init(swallow: false, actions: [.commitSelection]))

        // V is still down: its plain repeats and key-up must not reach the app.
        #expect(gesture.handle(plainVRepeat).swallow)
        #expect(gesture.handle(.keyUp(.v)).swallow)
        #expect(!gesture.swallowingStrayV)
    }

    @Test func releasingCommandDuringTapStillPastes() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        #expect(gesture.handle(.commandReleased).actions == [.cancelHoldTimer, .pasteNormally])
        #expect(gesture.handle(.keyUp(.v)).swallow)
    }

    @Test func escapeCancelsTheWheel() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.holdTimerFired)
        #expect(gesture.handle(escape) == .init(swallow: true, actions: [.cancelWheel]))
        #expect(gesture.handle(.keyUp(.v)).swallow)
        #expect(gesture.state == .idle)
    }

    @Test func rightClickTogglesPinAndHidesBothClicks() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.holdTimerFired)
        #expect(gesture.handle(.rightMouseDown) == .init(swallow: true, actions: [.togglePin]))
        #expect(gesture.handle(.rightMouseUp).swallow)
        #expect(gesture.state == .open)
    }

    @Test func otherShortcutsPassThrough() {
        var gesture = HoldGesture()
        let shiftCmdV = HoldGesture.Input.keyDown(.v, command: true, otherModifiers: true, isRepeat: false)
        let plainV = HoldGesture.Input.keyDown(.v, command: false, otherModifiers: false, isRepeat: false)
        let cmdC = HoldGesture.Input.keyDown(.other, command: true, otherModifiers: false, isRepeat: false)
        #expect(gesture.handle(shiftCmdV) == .passThrough)
        #expect(gesture.handle(plainV) == .passThrough)
        #expect(gesture.handle(cmdC) == .passThrough)
        #expect(gesture.handle(.rightMouseDown) == .passThrough)
        #expect(gesture.state == .idle)
    }

    @Test func otherKeyDuringPendingActsLikeATap() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        let cmdC = HoldGesture.Input.keyDown(.other, command: true, otherModifiers: false, isRepeat: false)
        #expect(gesture.handle(cmdC) == .init(swallow: false, actions: [.cancelHoldTimer, .pasteNormally]))
        #expect(gesture.state == .idle)
    }

    @Test func otherKeysAreIgnoredWhileWheelIsOpen() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.holdTimerFired)
        let cmdP = HoldGesture.Input.keyDown(.other, command: true, otherModifiers: false, isRepeat: false)
        #expect(gesture.handle(cmdP) == .init(swallow: true, actions: []))
        #expect(gesture.state == .open)
    }

    @Test func staleTimerAfterTapDoesNothing() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.keyUp(.v))
        #expect(gesture.handle(.holdTimerFired) == .passThrough)
        #expect(gesture.state == .idle)
    }

    @Test func secondTapAfterStrayVStartsFresh() {
        var gesture = HoldGesture()
        _ = gesture.handle(cmdV)
        _ = gesture.handle(.commandReleased) // stray V pending
        #expect(gesture.handle(cmdV).actions == [.startHoldTimer]) // new ⌘V clears it
        #expect(!gesture.swallowingStrayV)
    }
}
