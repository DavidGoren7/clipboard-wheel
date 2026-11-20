import AppKit
import Carbon.HIToolbox
import ClipboardWheelCore

/// Watches the keyboard (and right-clicks) system-wide with a Quartz event tap, and runs
/// the ⌘V tap-vs-hold gesture. Needs the Accessibility permission.
final class HotkeyInterceptor {
    /// Stamped on the ⌘V events the app sends itself, so the tap lets them through.
    nonisolated static let syntheticEventMarker: Int64 = 0x434C_5057 // "CLPW"

    /// Called for each gesture action except the hold timer, which is handled here.
    var onAction: ((HoldGesture.Action) -> Void)?

    /// When false (paused), every event passes straight through.
    var isEnabled = true {
        didSet { if !isEnabled { reset() } }
    }

    var isRunning: Bool { tap != nil }

    private let holdDelay: () -> TimeInterval
    private var gesture = HoldGesture()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdTimer: Timer?

    init(holdDelay: @escaping () -> TimeInterval) {
        self.holdDelay = holdDelay
    }

    /// Starts listening. Returns false if macOS refused (usually: no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .rightMouseDown, .rightMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        reset()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    // MARK: - Event handling

    /// Returns true to hide the event from the app in front.
    fileprivate func shouldSwallow(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS turns the tap off if we're ever too slow. Turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            reset()
            return false
        }
        guard isEnabled,
              event.getIntegerValueField(.eventSourceUserData) != Self.syntheticEventMarker,
              let input = Self.input(for: type, event: event)
        else { return false }

        let reaction = gesture.handle(input)
        reaction.actions.forEach(perform)
        return reaction.swallow
    }

    static func input(for type: CGEventType, event: CGEvent) -> HoldGesture.Input? {
        switch type {
        case .keyDown, .keyUp:
            let key = key(forKeyCode: event.getIntegerValueField(.keyboardEventKeycode))
            if type == .keyUp { return .keyUp(key) }
            let flags = event.flags
            return .keyDown(
                key,
                command: flags.contains(.maskCommand),
                otherModifiers: !flags.isDisjoint(with: [.maskShift, .maskAlternate, .maskControl]),
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        case .flagsChanged:
            return event.flags.contains(.maskCommand) ? nil : .commandReleased
        case .rightMouseDown:
            return .rightMouseDown
        case .rightMouseUp:
            return .rightMouseUp
        default:
            return nil
        }
    }

    static func key(forKeyCode keyCode: Int64) -> HoldGesture.Key {
        switch Int(keyCode) {
        case kVK_ANSI_V: .v
        case kVK_Escape: .escape
        default: .other
        }
    }

    private func perform(_ action: HoldGesture.Action) {
        switch action {
        case .startHoldTimer:
            startHoldTimer()
        case .cancelHoldTimer:
            holdTimer?.invalidate()
            holdTimer = nil
        default:
            // Run UI work after the event tap returns, so the tap stays fast.
            Task { [weak self] in self?.onAction?(action) }
        }
    }

    private func startHoldTimer() {
        holdTimer?.invalidate()
        let timer = Timer(timeInterval: holdDelay(), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.holdTimerFired() }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func holdTimerFired() {
        holdTimer = nil
        let reaction = gesture.handle(.holdTimerFired)
        reaction.actions.forEach(perform)
    }

    private func reset() {
        let wasOpen = gesture.state == .open
        gesture.reset()
        holdTimer?.invalidate()
        holdTimer = nil
        if wasOpen { onAction?(.cancelWheel) }
    }
}

/// The C callback macOS calls for every tapped event. The tap is attached to the main
/// run loop, so this always runs on the main thread.
private nonisolated func hotkeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let address = UInt(bitPattern: userInfo)
    // Safe: the tap's run loop source is on the main run loop, so this is the main thread.
    nonisolated(unsafe) let mainThreadEvent = event
    let swallow = MainActor.assumeIsolated {
        guard let pointer = UnsafeRawPointer(bitPattern: address) else { return false }
        return Unmanaged<HotkeyInterceptor>.fromOpaque(pointer).takeUnretainedValue()
            .shouldSwallow(type: type, event: mainThreadEvent)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
