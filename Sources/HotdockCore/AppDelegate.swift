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
    private lazy var windowPicker = WindowPicker()

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
        windowPicker.close()
    }

    // MARK: - Setup

    private func setupHotKeyCallbacks() {
        hotKeyManager.onHotKey = { [weak self] position in
            self?.handleHotKey(position: position)
        }

        hotKeyManager.onLongPress = { [weak self] position in
            self?.handleLongPress(position: position)
        }

        hotKeyManager.onPickerKey = { [weak self] key in
            self?.handlePickerKey(key)
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

        let cycleItem = NSMenuItem(title: "Hold the number to pick a window", action: nil, keyEquivalent: "")
        cycleItem.isEnabled = false
        menu.addItem(cycleItem)

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

    private func handleLongPress(position: Int) {
        guard let item = dockManager.item(at: position) else {
            return
        }

        guard item.isApp, let app = item.runningApplication else {
            windowController.toggleItem(item)
            return
        }

        let windows = AppWindows.list(for: app)
        guard windows.count > 1 else {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }

        windowPicker.show(app: app, windows: windows)
        hotKeyManager.isPickerOpen = true
    }

    private func handlePickerKey(_ key: PickerKey) {
        switch key {
        case .up:
            windowPicker.moveSelection(by: -1)
        case .down:
            windowPicker.moveSelection(by: 1)
        case .digit(let number):
            windowPicker.select(index: number - 1)
        case .confirm:
            windowPicker.commit()
            hotKeyManager.isPickerOpen = false
        case .cancel:
            windowPicker.close()
            hotKeyManager.isPickerOpen = false
        }
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
