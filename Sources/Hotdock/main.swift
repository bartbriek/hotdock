import AppKit
import HotdockCore

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Hide from dock (menu bar app only)
app.setActivationPolicy(.accessory)

app.run()
