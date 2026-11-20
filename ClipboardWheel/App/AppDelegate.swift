import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests load the app as their host; don't grab ⌘V or add a menu bar icon then.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let model = AppModel()
        self.model = model
        model.start()
    }

    /// Opening the app again (from Spotlight or Finder) shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model?.showSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}
