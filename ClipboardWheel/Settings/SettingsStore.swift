import Combine
import Foundation

enum WheelPosition: String, CaseIterable, Identifiable {
    /// The wheel opens wherever the mouse is.
    case cursor
    /// The wheel opens in the middle of the screen; the mouse snaps there and goes back after.
    case screenCenter

    var id: String { rawValue }
}

/// App preferences, saved in UserDefaults. (The wheel's mode and max slices are saved with
/// its items instead, in ClipStore.)
final class SettingsStore: ObservableObject {
    static let holdDelayRange: ClosedRange<Double> = 0.15...0.6

    private enum Key {
        static let wheelPosition = "wheelPosition"
        static let holdDelay = "holdDelay"
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private let defaults: UserDefaults

    @Published var wheelPosition: WheelPosition {
        didSet { defaults.set(wheelPosition.rawValue, forKey: Key.wheelPosition) }
    }

    /// Seconds ⌘V must be held before the wheel opens.
    @Published var holdDelay: Double {
        didSet { defaults.set(holdDelay, forKey: Key.holdDelay) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    @Published var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Key.hapticEnabled) }
    }

    /// Paused: ⌘V behaves exactly like macOS and nothing is recorded. Resets on relaunch.
    @Published var isPaused = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.wheelPosition: WheelPosition.cursor.rawValue,
            Key.holdDelay: 0.25,
            Key.soundEnabled: true,
            Key.hapticEnabled: true,
        ])
        wheelPosition = WheelPosition(rawValue: defaults.string(forKey: Key.wheelPosition) ?? "") ?? .cursor
        holdDelay = Self.holdDelayRange.clamped(defaults.double(forKey: Key.holdDelay))
        soundEnabled = defaults.bool(forKey: Key.soundEnabled)
        hapticEnabled = defaults.bool(forKey: Key.hapticEnabled)
    }

    /// True the very first time the app runs (and never again).
    func consumeFirstLaunch() -> Bool {
        guard !defaults.bool(forKey: Key.hasLaunchedBefore) else { return false }
        defaults.set(true, forKey: Key.hasLaunchedBefore)
        return true
    }
}

extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double { Swift.min(upperBound, Swift.max(lowerBound, value)) }
}
