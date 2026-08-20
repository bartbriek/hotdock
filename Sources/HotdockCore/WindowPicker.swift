import AppKit

// MARK: - Constants

private enum PickerMetrics {
    static let width: CGFloat = 460
    static let rowHeight: CGFloat = 32
    static let headerHeight: CGFloat = 28
    static let padding: CGFloat = 8
    static let cornerRadius: CGFloat = 14
    static let indexColumnWidth: CGFloat = 30
}

// MARK: - WindowPicker

/// A floating list of an app's open windows. Keys are delivered by the event tap rather
/// than by the panel itself, so the picker never has to steal focus from the active app.
final class WindowPicker {

    private var panel: NSWindow?
    private var listView: PickerListView?
    private var windows: [AppWindow] = []
    private var app: NSRunningApplication?
    private var selection = 0

    var isVisible: Bool { panel != nil }

    func show(app: NSRunningApplication, windows: [AppWindow]) {
        close()
        guard !windows.isEmpty else { return }

        self.app = app
        self.windows = windows
        self.selection = 0

        let height = PickerMetrics.headerHeight
            + CGFloat(windows.count) * PickerMetrics.rowHeight
            + PickerMetrics.padding * 2

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: PickerMetrics.width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = true

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: PickerMetrics.width, height: height))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = PickerMetrics.cornerRadius
        effect.layer?.masksToBounds = true

        let list = PickerListView(frame: effect.bounds)
        list.appName = app.localizedName ?? "Windows"
        list.windows = windows
        list.selection = 0
        list.autoresizingMask = [.width, .height]
        effect.addSubview(list)

        window.contentView = effect
        window.setFrameOrigin(origin(for: NSSize(width: PickerMetrics.width, height: height)))
        window.orderFrontRegardless()

        self.panel = window
        self.listView = list
    }

    func moveSelection(by delta: Int) {
        guard !windows.isEmpty else { return }
        let count = windows.count
        selection = ((selection + delta) % count + count) % count
        listView?.selection = selection
    }

    func select(index: Int) {
        guard windows.indices.contains(index) else { return }
        selection = index
        listView?.selection = index
    }

    func commit() {
        if let app, windows.indices.contains(selection) {
            AppWindows.focus(windows[selection], in: app)
        }
        close()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        listView = nil
        windows = []
        app = nil
        selection = 0
    }

    /// Centres the panel on the screen holding the pointer so it lands on the display the
    /// user is working on rather than always on the primary one.
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let frame = screen?.frame else { return NSPoint(x: 0, y: 0) }

        return NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
    }
}

// MARK: - PickerListView

private final class PickerListView: NSView {

    var appName: String = "" { didSet { needsDisplay = true } }
    var windows: [AppWindow] = [] { didSet { needsDisplay = true } }
    var selection: Int = 0 { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawHeader()

        for (index, window) in windows.enumerated() {
            drawRow(index: index, window: window)
        }
    }

    private func drawHeader() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let rect = NSRect(
            x: PickerMetrics.padding + 8,
            y: PickerMetrics.padding + 4,
            width: bounds.width - PickerMetrics.padding * 2,
            height: PickerMetrics.headerHeight
        )
        appName.uppercased().draw(in: rect, withAttributes: attributes)
    }

    private func drawRow(index: Int, window: AppWindow) {
        let isSelected = index == selection
        let rowRect = NSRect(
            x: PickerMetrics.padding,
            y: PickerMetrics.padding + PickerMetrics.headerHeight + CGFloat(index) * PickerMetrics.rowHeight,
            width: bounds.width - PickerMetrics.padding * 2,
            height: PickerMetrics.rowHeight
        )

        if isSelected {
            let path = NSBezierPath(roundedRect: rowRect.insetBy(dx: 0, dy: 2), xRadius: 7, yRadius: 7)
            NSColor.controlAccentColor.setFill()
            path.fill()
        }

        let indexColor: NSColor = isSelected ? .white : .tertiaryLabelColor
        let titleColor: NSColor = isSelected ? .white : .labelColor

        let indexAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: indexColor
        ]
        let indexText = "\(index + 1)"
        let indexSize = indexText.size(withAttributes: indexAttributes)
        indexText.draw(
            at: NSPoint(
                x: rowRect.minX + PickerMetrics.indexColumnWidth - indexSize.width,
                y: rowRect.midY - indexSize.height / 2
            ),
            withAttributes: indexAttributes
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: titleColor
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        var attributes = titleAttributes
        attributes[.paragraphStyle] = paragraph

        let title = window.isMinimized ? "\(window.title)  (minimized)" : window.title
        let titleHeight = title.size(withAttributes: attributes).height
        let titleRect = NSRect(
            x: rowRect.minX + PickerMetrics.indexColumnWidth + 12,
            y: rowRect.midY - titleHeight / 2,
            width: rowRect.width - PickerMetrics.indexColumnWidth - 24,
            height: titleHeight
        )
        title.draw(in: titleRect, withAttributes: attributes)
    }
}
