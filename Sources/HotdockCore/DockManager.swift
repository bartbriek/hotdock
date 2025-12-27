import AppKit

// MARK: - DockItem

public struct DockItem {
    public let position: Int
    public let label: String
    public let bundleIdentifier: String?
    public let path: URL?
    public let isApp: Bool

    public init(position: Int, label: String, bundleIdentifier: String?, path: URL?, isApp: Bool) {
        self.position = position
        self.label = label
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.isApp = isApp
    }
}

// MARK: - DockManager

public final class DockManager {
    public private(set) var items: [DockItem] = []

    public init() {
        refresh()
    }

    public func refresh() {
        let dockItems = DockAccessibility.shared.queryDockItems()

        items = dockItems.map { info in
            DockItem(
                position: info.position,
                label: info.label,
                bundleIdentifier: info.bundleIdentifier,
                path: info.path,
                isApp: info.isApp
            )
        }
    }

    public func item(at position: Int) -> DockItem? {
        return items.first { $0.position == position }
    }
}
