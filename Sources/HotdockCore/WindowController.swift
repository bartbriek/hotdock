import AppKit
import os.log

private let logger = Logger(subsystem: "com.hotdock", category: "WindowController")

// MARK: - WindowController

final class WindowController {

    func toggleItem(_ item: DockItem) {
        if item.isApp {
            toggleApp(item)
        } else {
            openPath(item)
        }
    }

    private func toggleApp(_ item: DockItem) {
        // First try to find by bundle ID
        if let bundleId = item.bundleIdentifier {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

            if let app = runningApps.first {
                if app.isActive {
                    app.hide()
                    logger.debug("Hiding app: \(item.label)")
                } else {
                    app.activate(options: [.activateIgnoringOtherApps])
                    logger.debug("Activating app: \(item.label)")
                }
                return
            } else {
                // App not running - launch it
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    logger.debug("Launching app by bundle ID: \(bundleId)")
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    return
                }
            }
        }

        // Fallback: try to find running app by name
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName == item.label }) {
            if app.isActive {
                app.hide()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            return
        }

        // Try to launch by name from /Applications (with sanitization)
        if let appURL = sanitizedAppURL(for: item.label) {
            logger.debug("Launching app from /Applications: \(item.label)")
            NSWorkspace.shared.open(appURL)
            return
        }

        // Final fallback to path
        if let path = item.path {
            logger.debug("Opening path: \(path)")
            NSWorkspace.shared.open(path)
        }
    }

    private func openPath(_ item: DockItem) {
        guard let path = item.path else {
            logger.warning("No path available for item: \(item.label)")
            return
        }
        NSWorkspace.shared.open(path)
    }

    /// Returns a safe URL for an app in /Applications, or nil if the label is unsafe
    private func sanitizedAppURL(for label: String) -> URL? {
        // Prevent path traversal attacks
        guard !label.contains("/"),
              !label.contains(".."),
              !label.contains("\\"),
              !label.isEmpty else {
            logger.warning("Rejected unsafe label: \(label)")
            return nil
        }

        let appPath = "/Applications/\(label).app"

        guard FileManager.default.fileExists(atPath: appPath) else {
            return nil
        }

        return URL(fileURLWithPath: appPath)
    }
}
