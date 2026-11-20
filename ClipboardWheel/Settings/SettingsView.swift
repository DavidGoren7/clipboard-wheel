import AppKit
import SwiftUI
import ClipboardWheelCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clipboard: ClipboardModel
    @ObservedObject var permissions: PermissionsMonitor

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            wheelSection
            feedbackSection
            generalSection
            itemsSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            permissions.refresh()
        }
    }

    // MARK: - Sections

    private var wheelSection: some View {
        Section("Wheel") {
            Picker("Wheel shows", selection: Binding(get: { clipboard.store.mode }, set: clipboard.setMode)) {
                Text("History + pinned").tag(WheelMode.historyAndPinned)
                Text("History only").tag(WheelMode.historyOnly)
                Text("Pinned only").tag(WheelMode.pinnedOnly)
            }

            Stepper(
                value: Binding(get: { clipboard.store.maxItems }, set: clipboard.setMaxItems),
                in: clipboard.store.minimumAllowedMax...ClipStore.maxItemsRange.upperBound
            ) {
                LabeledContent("Max slices", value: "\(clipboard.store.maxItems)")
            }

            Picker("Opens", selection: $settings.wheelPosition) {
                Text("At the mouse cursor").tag(WheelPosition.cursor)
                Text("In the center of the screen").tag(WheelPosition.screenCenter)
            }

            VStack(alignment: .leading) {
                LabeledContent("Hold ⌘V for", value: String(format: "%.2f s", settings.holdDelay))
                Slider(value: $settings.holdDelay, in: SettingsStore.holdDelayRange, step: 0.05)
            }
        }
    }

    private var feedbackSection: some View {
        Section("Feedback") {
            Toggle("Sound tick between slices", isOn: $settings.soundEnabled)
            Toggle("Trackpad haptic between slices", isOn: $settings.hapticEnabled)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        try LaunchAtLogin.setEnabled(enabled)
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            if LaunchAtLogin.needsApproval {
                Button("Approve in Login Items…", action: LaunchAtLogin.openLoginItemsSettings)
            }
            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
            }

            LabeledContent("Accessibility") {
                if permissions.isAccessibilityTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button("Allow…", action: permissions.openAccessibilitySettings)
                }
            }

            if let note = permissions.clipboardAccessNote {
                LabeledContent("Clipboard access") {
                    Text(note).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var itemsSection: some View {
        Section {
            if clipboard.store.items.isEmpty {
                Text("Nothing copied yet.").foregroundStyle(.secondary)
            }
            ForEach(clipboard.store.items) { item in
                ItemRow(
                    item: item,
                    canPin: clipboard.store.canPin,
                    image: item.content.imageFileName.flatMap(clipboard.image(named:)),
                    togglePin: { clipboard.togglePin(item.id) },
                    remove: { clipboard.remove(item.id) }
                )
            }
            if clipboard.store.unpinnedCount > 0 {
                Button("Clear History", role: .destructive, action: clipboard.clearHistory)
            }
        } header: {
            Text("Items")
        } footer: {
            Text("In slot order, starting at the top of the wheel. Pinned items are never overwritten.")
        }
    }
}

private struct ItemRow: View {
    let item: ClipItem
    let canPin: Bool
    let image: NSImage?
    let togglePin: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: 36, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if let text = item.content.text {
                    Text(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
                        .lineLimit(2)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if canPin || item.pinned {
                Button(action: togglePin) {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(item.pinned ? Color.accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!canPin)
                .help(item.pinned ? "Unpin" : "Pin")
            }

            Button(action: remove) {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove from the wheel")
        }
    }
}

/// The Settings window (opened from the menu bar).
final class SettingsWindowController {
    private weak var model: AppModel?
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil, let model {
            let view = SettingsView(settings: model.settings, clipboard: model.clipboard, permissions: model.permissions)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Clipboard Wheel Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
