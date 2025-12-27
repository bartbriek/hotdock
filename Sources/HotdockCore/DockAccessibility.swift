import AppKit
import ApplicationServices
import os.log

// MARK: - Constants

public enum DockConstants {
    public static let maxShortcuts = 99
    public static let badgeSize: CGFloat = 20
    public static let badgeSizeLarge: CGFloat = 26
    public static let defaultScreenHeight: CGFloat = 900
}

// MARK: - Logging

private let logger = Logger(subsystem: "com.hotdock", category: "DockAccessibility")

// MARK: - Data Types

public struct DockItemInfo {
    public let position: Int
    public let label: String
    public let bundleIdentifier: String?
    public let path: URL?
    public let frame: CGRect
    public let isApp: Bool

    public init(position: Int, label: String, bundleIdentifier: String?, path: URL?, frame: CGRect, isApp: Bool) {
        self.position = position
        self.label = label
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.frame = frame
        self.isApp = isApp
    }
}

// MARK: - DockAccessibility

public final class DockAccessibility {

    public static let shared = DockAccessibility()

    private init() {}

    public func queryDockItems() -> [DockItemInfo] {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            logger.warning("Could not find Dock app")
            return []
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        guard let dockList = findDockList(in: dockElement) else {
            logger.warning("Could not find dock list")
            return []
        }

        guard let axItems = getChildren(of: dockList) else {
            logger.warning("Could not get dock items")
            return []
        }

        let screenHeight = NSScreen.main?.frame.height ?? DockConstants.defaultScreenHeight
        let runningApps = NSWorkspace.shared.runningApplications

        var items: [DockItemInfo] = []
        var position = 1

        for axItem in axItems {
            guard position <= DockConstants.maxShortcuts else { break }

            let label = getStringAttribute(axItem, attribute: kAXTitleAttribute) ?? ""

            guard !label.isEmpty, label != "Separator", isValidLabel(label) else {
                continue
            }

            guard let frame = getFrame(for: axItem, screenHeight: screenHeight) else {
                continue
            }

            let subrole = getStringAttribute(axItem, attribute: kAXSubroleAttribute)
            let role = getStringAttribute(axItem, attribute: kAXRoleAttribute)
            let url = getURLAttribute(axItem)

            let (bundleId, isApp) = resolveBundleInfo(
                label: label,
                subrole: subrole,
                role: role,
                runningApps: runningApps
            )

            let item = DockItemInfo(
                position: position,
                label: label,
                bundleIdentifier: bundleId,
                path: url,
                frame: frame,
                isApp: isApp
            )

            items.append(item)
            position += 1
        }

        return items
    }

    // MARK: - Private Helpers

    private func findDockList(in element: AXUIElement) -> AXUIElement? {
        guard let children = getChildren(of: element) else { return nil }

        for child in children {
            if getStringAttribute(child, attribute: kAXRoleAttribute) == "AXList" {
                return child
            }
        }
        return nil
    }

    private func getChildren(of element: AXUIElement) -> [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)

        guard result == .success else {
            logger.debug("Failed to get children: \(result.rawValue)")
            return nil
        }

        return value as? [AXUIElement]
    }

    private func getStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func getURLAttribute(_ element: AXUIElement) -> URL? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? URL
    }

    private func getFrame(for element: AXUIElement, screenHeight: CGFloat) -> CGRect? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        guard let posRef = posValue,
              let sizeRef = sizeValue,
              CFGetTypeID(posRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            logger.debug("Invalid AXValue type for position/size")
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(
            x: point.x,
            y: screenHeight - point.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    public func isValidLabel(_ label: String) -> Bool {
        return !label.contains("/") && !label.contains("..") && !label.contains("\\")
    }

    private func resolveBundleInfo(
        label: String,
        subrole: String?,
        role: String?,
        runningApps: [NSRunningApplication]
    ) -> (bundleId: String?, isApp: Bool) {

        if let app = runningApps.first(where: { $0.localizedName == label }) {
            return (app.bundleIdentifier, true)
        }

        if isValidLabel(label) {
            let appPath = "/Applications/\(label).app"
            if FileManager.default.fileExists(atPath: appPath),
               let bundle = Bundle(path: appPath) {
                return (bundle.bundleIdentifier, true)
            }
        }

        let isAppItem = subrole == "AXApplicationDockItem" || role == "AXDockItem"

        return (nil, isAppItem)
    }
}
