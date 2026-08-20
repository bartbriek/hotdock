import AppKit
import ApplicationServices

// MARK: - App Resolution

extension DockItem {
    var runningApplication: NSRunningApplication? {
        if let bundleId = bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            return app
        }
        return NSWorkspace.shared.runningApplications.first { $0.localizedName == label }
    }
}

// MARK: - AppWindow

struct AppWindow {
    let element: AXUIElement
    let title: String
    let isMinimized: Bool
}

// MARK: - AppWindows

enum AppWindows {

    static func list(for app: NSRunningApplication) -> [AppWindow] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return []
        }

        return elements.compactMap { element in
            // Drop dialogs and palettes, but keep windows reporting no subrole at all:
            // an exact match would discard everything when the attribute is absent.
            if let subrole = string(element, kAXSubroleAttribute), subrole != kAXStandardWindowSubrole {
                return nil
            }

            let title = string(element, kAXTitleAttribute) ?? ""
            return AppWindow(
                element: element,
                title: title.isEmpty ? (app.localizedName ?? "Untitled") : title,
                isMinimized: bool(element, kAXMinimizedAttribute)
            )
        }
    }

    static func focus(_ window: AppWindow, in app: NSRunningApplication) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        app.activate(options: [.activateIgnoringOtherApps])
    }

    // MARK: - Private

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }
}
