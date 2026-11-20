import AppKit

// A background (menu bar) app: no Dock icon, no main window.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
