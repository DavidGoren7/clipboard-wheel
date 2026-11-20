import AppKit
import ApplicationServices
import Combine

/// Tracks the Accessibility permission (needed to see ⌘V and paste) and the clipboard
/// privacy setting.
final class PermissionsMonitor: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()

    private var pollTimer: Timer?
    private var onGranted: (() -> Void)?

    func refresh() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    /// Shows macOS's own "allow Accessibility" prompt.
    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Checks once a second until Accessibility is allowed, then calls `onGranted` once.
    func waitForAccessibility(onGranted: @escaping () -> Void) {
        pollTimer?.invalidate()
        self.onGranted = onGranted
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh()
                if self.isAccessibilityTrusted {
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil
                    let callback = self.onGranted
                    self.onGranted = nil
                    callback?()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    /// A warning when macOS's clipboard privacy setting blocks the app, otherwise nil.
    var clipboardAccessNote: String? {
        guard #available(macOS 15.4, *) else { return nil }
        switch NSPasteboard.general.accessBehavior {
        case .alwaysDeny:
            return "Blocked. Allow Clipboard Wheel to paste from other apps in System Settings → Privacy & Security."
        case .ask:
            return "macOS will ask before each read. Choose “Always Allow” when it does."
        default:
            return nil
        }
    }
}
