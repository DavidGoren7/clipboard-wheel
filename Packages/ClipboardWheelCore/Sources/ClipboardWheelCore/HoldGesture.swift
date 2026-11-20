/// Decides what ⌘V does: a quick tap pastes normally, holding opens the wheel, and
/// letting go pastes the hovered slice.
///
/// It's a pure state machine. The event tap feeds it keyboard and mouse input and
/// carries out the returned actions; `swallow` says whether to hide the event from
/// the app in front.
public struct HoldGesture: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        /// ⌘V is down, waiting to see if it's a tap or a hold.
        case pending
        /// The wheel is showing.
        case open
    }

    public enum Key: Equatable, Sendable {
        case v
        case escape
        case other
    }

    public enum Input: Equatable, Sendable {
        /// `command` = ⌘ is held; `otherModifiers` = ⇧, ⌥ or ⌃ is held.
        case keyDown(Key, command: Bool, otherModifiers: Bool, isRepeat: Bool)
        case keyUp(Key)
        /// Modifier keys changed and ⌘ is no longer held.
        case commandReleased
        case rightMouseDown
        case rightMouseUp
        /// The hold delay passed while ⌘V was still down.
        case holdTimerFired
    }

    public enum Action: Equatable, Sendable {
        case startHoldTimer
        case cancelHoldTimer
        /// It was a tap: send a normal ⌘V to the app.
        case pasteNormally
        case openWheel
        /// Paste the hovered slice, or do nothing if the cursor is in the dead zone.
        case commitSelection
        /// Close the wheel without pasting.
        case cancelWheel
        /// Pin or unpin the hovered slice.
        case togglePin
    }

    public struct Reaction: Equatable, Sendable {
        public var swallow: Bool
        public var actions: [Action]

        public static let passThrough = Reaction(swallow: false, actions: [])
        static func swallow(_ actions: Action...) -> Reaction { Reaction(swallow: true, actions: actions) }
    }

    public private(set) var state: State = .idle
    /// V is still physically down after the gesture ended (⌘ was released first, or Esc
    /// was pressed). Its auto-repeats and key-up are hidden so the app doesn't see a
    /// stray "v".
    public private(set) var swallowingStrayV = false
    private var swallowRightMouseUp = false

    public init() {}

    public mutating func handle(_ input: Input) -> Reaction {
        switch state {
        case .idle: handleIdle(input)
        case .pending: handlePending(input)
        case .open: handleOpen(input)
        }
    }

    /// Drops back to idle, e.g. when the wheel is paused or the event tap restarts.
    public mutating func reset() {
        state = .idle
        swallowingStrayV = false
        swallowRightMouseUp = false
    }

    // MARK: - States

    private mutating func handleIdle(_ input: Input) -> Reaction {
        switch input {
        case .keyDown(.v, command: true, otherModifiers: false, isRepeat: false):
            swallowingStrayV = false
            state = .pending
            return .swallow(.startHoldTimer)
        case .keyDown(.v, _, _, isRepeat: true) where swallowingStrayV:
            return .swallow()
        case .keyUp(.v) where swallowingStrayV:
            swallowingStrayV = false
            return .swallow()
        case .rightMouseUp where swallowRightMouseUp:
            swallowRightMouseUp = false
            return .swallow()
        default:
            return .passThrough
        }
    }

    private mutating func handlePending(_ input: Input) -> Reaction {
        switch input {
        case .keyDown(.v, _, _, isRepeat: true):
            return .swallow()
        case .keyUp(.v):
            state = .idle
            return .swallow(.cancelHoldTimer, .pasteNormally)
        case .commandReleased:
            // Let the modifier change through so the app's ⌘ state stays correct.
            state = .idle
            swallowingStrayV = true
            return Reaction(swallow: false, actions: [.cancelHoldTimer, .pasteNormally])
        case .keyDown(.escape, _, _, _):
            state = .idle
            swallowingStrayV = true
            return .swallow(.cancelHoldTimer)
        case .keyDown:
            // Another key while ⌘V is down: treat it as a tap, then let the key through.
            state = .idle
            swallowingStrayV = true
            return Reaction(swallow: false, actions: [.cancelHoldTimer, .pasteNormally])
        case .holdTimerFired:
            state = .open
            return Reaction(swallow: false, actions: [.openWheel])
        case .keyUp, .rightMouseDown, .rightMouseUp:
            return .passThrough
        }
    }

    private mutating func handleOpen(_ input: Input) -> Reaction {
        switch input {
        case .keyUp(.v):
            state = .idle
            return .swallow(.commitSelection)
        case .commandReleased:
            state = .idle
            swallowingStrayV = true
            return Reaction(swallow: false, actions: [.commitSelection])
        case .keyDown(.escape, _, _, _):
            state = .idle
            swallowingStrayV = true
            return .swallow(.cancelWheel)
        case .keyDown, .keyUp:
            // Ignore other keys while the wheel is up.
            return .swallow()
        case .rightMouseDown:
            swallowRightMouseUp = true
            return .swallow(.togglePin)
        case .rightMouseUp:
            swallowRightMouseUp = false
            return .swallow()
        case .holdTimerFired:
            return .passThrough
        }
    }
}
