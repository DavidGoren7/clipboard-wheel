import AppKit
import Combine
import ClipboardWheelCore

/// Owns every part of the app and connects them.
final class AppModel {
    let settings = SettingsStore()
    let clipboard = ClipboardModel()
    let permissions = PermissionsMonitor()
    private(set) lazy var monitor = ClipboardMonitor(clipboard: clipboard)
    private(set) lazy var wheel = WheelController(clipboard: clipboard, settings: settings)
    private(set) lazy var interceptor = HotkeyInterceptor(holdDelay: { [settings] in settings.holdDelay })

    private var menuBar: MenuBarController?
    private lazy var settingsWindow = SettingsWindowController(model: self)
    private lazy var onboardingWindow = OnboardingWindowController(permissions: permissions)
    private var cancellables: Set<AnyCancellable> = []

    func start() {
        if settings.consumeFirstLaunch() {
            try? LaunchAtLogin.setEnabled(true)
        }

        interceptor.onAction = { [weak self] action in self?.handle(action) }
        monitor.start()
        menuBar = MenuBarController(model: self)

        settings.$isPaused
            .removeDuplicates()
            .sink { [weak self] paused in
                self?.interceptor.isEnabled = !paused
                self?.monitor.isPaused = paused
                self?.menuBar?.refreshIcon(paused: paused)
            }
            .store(in: &cancellables)

        if permissions.isAccessibilityTrusted {
            startInterceptor()
        } else {
            onboardingWindow.show()
            permissions.waitForAccessibility { [weak self] in
                self?.startInterceptor()
                self?.onboardingWindow.close()
            }
        }

        if CommandLine.arguments.contains("--show-wheel") {
            wheel.showDemo()
        }
    }

    func stop() {
        interceptor.stop()
        monitor.stop()
    }

    func showSettings() { settingsWindow.show() }
    func showOnboarding() { onboardingWindow.show() }

    /// Pins whatever is on the clipboard right now (menu bar "Pin Current Clipboard").
    func pinCurrentClipboard() {
        guard let content = ClipboardMonitor.readContent(from: .general) else {
            NSSound.beep()
            return
        }
        switch content {
        case let .text(text): clipboard.pin(text: text)
        case let .image(pngData): clipboard.pinImage(pngData: pngData)
        }
    }

    private func startInterceptor() {
        if !interceptor.start() {
            NSLog("Clipboard Wheel: couldn't create the keyboard event tap")
        }
    }

    private func handle(_ action: HoldGesture.Action) {
        switch action {
        case .pasteNormally:
            PasteSimulator.postCommandV()
        case .openWheel:
            wheel.open()
        case .commitSelection:
            if let item = wheel.close(commit: true) {
                paste(item)
            }
        case .cancelWheel:
            _ = wheel.close(commit: false)
        case .togglePin:
            wheel.togglePinOnHoveredSlice()
        case .startHoldTimer, .cancelHoldTimer:
            break // handled inside the interceptor
        }
    }

    /// Puts the item on the clipboard and pastes it into the app in front.
    private func paste(_ item: ClipItem) {
        guard let changeCount = clipboard.writeToPasteboard(item) else {
            NSSound.beep()
            return
        }
        monitor.ignore(changeCount: changeCount)
        clipboard.markUsed(item.id)
        Task {
            // Give the pasteboard a moment before the app reads it.
            try? await Task.sleep(for: .milliseconds(30))
            PasteSimulator.postCommandV()
        }
    }
}
