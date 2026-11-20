import AppKit
import ClipboardWheelCore

/// The wheel icon in the menu bar and its menu.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon(paused: model.settings.isPaused)
    }

    func refreshIcon(paused: Bool) {
        let name = paused ? "pause.circle" : "chart.pie"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Clipboard Wheel")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = paused ? "Clipboard Wheel (paused)" : "Clipboard Wheel"
    }

    // Rebuilt each time it opens, so it always reflects the current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let model else { return }
        menu.removeAllItems()

        model.permissions.refresh()
        if !model.permissions.isAccessibilityTrusted {
            menu.addItem(item("Allow Accessibility Access…", action: #selector(showOnboarding)))
            menu.addItem(.separator())
        }

        let pause = item(model.settings.isPaused ? "Resume Clipboard Wheel" : "Pause Clipboard Wheel", action: #selector(togglePause))
        menu.addItem(pause)

        if model.clipboard.store.canPin {
            menu.addItem(item("Pin Current Clipboard", action: #selector(pinCurrentClipboard)))
        }

        let clear = item("Clear History", action: #selector(clearHistory))
        clear.isEnabled = model.clipboard.store.unpinnedCount > 0
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Clipboard Wheel", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func togglePause() { model?.settings.isPaused.toggle() }
    @objc private func pinCurrentClipboard() { model?.pinCurrentClipboard() }
    @objc private func clearHistory() { model?.clipboard.clearHistory() }
    @objc private func showSettings() { model?.showSettings() }
    @objc private func showOnboarding() { model?.showOnboarding() }
    @objc private func quit() { NSApp.terminate(nil) }
}
