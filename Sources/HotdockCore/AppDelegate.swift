import AppKit

// MARK: - AppDelegate

public final class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var statusItem: NSStatusItem = {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()

    private lazy var dockManager = DockManager()
    private lazy var windowController = WindowController()
    private lazy var hotKeyManager = HotKeyManager()
    private lazy var dockOverlay = DockOverlay()

    // MARK: - Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotKeyCallbacks()

        if !hotKeyManager.start() {
            showAccessibilityAlert()
            return
        }

        setupMenuBar()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.stop()
        dockOverlay.stop()
    }

    // MARK: - Setup

    private func setupHotKeyCallbacks() {
        hotKeyManager.onHotKey = { [weak self] position in
            self?.handleHotKey(position: position)
        }

        hotKeyManager.onControlChanged = { [weak self] isPressed in
            if isPressed {
                self?.dockOverlay.start()
            } else {
                self?.dockOverlay.stop()
            }
        }
    }

    private func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Hotdock")
            if button.image == nil {
                button.title = "HD"
            }
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let infoItem = NSMenuItem(title: "Hold Ctrl to see shortcuts", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(NSMenuItem.separator())

        for item in dockManager.items.prefix(DockConstants.maxShortcuts) {
            let menuItem = NSMenuItem(
                title: "Ctrl+\(item.position): \(item.label)",
                action: nil,
                keyEquivalent: ""
            )
            menuItem.isEnabled = false
            menu.addItem(menuItem)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Dock", action: #selector(refreshDock), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Hotdock", action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    // MARK: - Actions

    private func handleHotKey(position: Int) {
        guard let item = dockManager.item(at: position) else {
            return
        }
        windowController.toggleItem(item)
    }

    @objc private func refreshDock() {
        dockManager.refresh()
        statusItem.menu = buildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Alerts

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Hotdock needs Accessibility permission to capture keyboard shortcuts.

            Please go to System Settings > Privacy & Security > Accessibility and enable Hotdock.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        NSApp.terminate(nil)
    }
}
