import AppKit
import Carbon.HIToolbox

/// Sends ⌘V to the app in front, as if typed.
enum PasteSimulator {
    static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isKeyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: isKeyDown
            ) else { continue }
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: HotkeyInterceptor.syntheticEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }
}
