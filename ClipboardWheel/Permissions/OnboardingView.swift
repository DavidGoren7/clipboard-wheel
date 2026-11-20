import AppKit
import SwiftUI

/// First-launch window that explains and requests the Accessibility permission.
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsMonitor

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            Text("Let Clipboard Wheel see ⌘V")
                .font(.title2.bold())

            Text("Clipboard Wheel needs **Accessibility** permission to notice when you hold ⌘V and to paste what you pick. It only watches for ⌘V and doesn't record your typing.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label("Click **Open System Settings** below", systemImage: "1.circle")
                Label("Turn on **Clipboard Wheel** in the list", systemImage: "2.circle")
                Label("Come back here. This window closes by itself", systemImage: "3.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if permissions.isAccessibilityTrusted {
                Label("All set! Hold ⌘V to try it.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings") {
                    permissions.requestAccessibility()
                    permissions.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text("If Clipboard Wheel is already in the list but this window stays open, remove it with the – button and turn it on again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 420)
    }
}

final class OnboardingWindowController {
    private let permissions: PermissionsMonitor
    private var window: NSWindow?

    init(permissions: PermissionsMonitor) {
        self.permissions = permissions
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(permissions: permissions)))
            window.title = "Welcome to Clipboard Wheel"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
