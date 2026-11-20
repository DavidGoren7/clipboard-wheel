import AppKit

/// The soft tick (and trackpad bump) as the mouse moves onto a new slice.
final class WheelFeedback {
    private let sound: NSSound? = {
        let sound = NSSound(named: "Tink")
        sound?.volume = 0.25
        return sound
    }()

    func tick(sound playSound: Bool, haptic: Bool) {
        if playSound, let sound {
            sound.stop()
            sound.play()
        }
        if haptic {
            // Only felt on a Force Touch trackpad while a finger is on it.
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}
