import AppKit

// MARK: - DockOverlay

final class DockOverlay {
    private var badgeWindows: [BadgeWindow] = []
    private var isVisible = false

    func start() {
        guard !isVisible else { return }
        isVisible = true

        DispatchQueue.main.async { [weak self] in
            self?.updateBadges()
            self?.showBadges()
        }
    }

    func stop() {
        guard isVisible else { return }
        isVisible = false
        hideBadges()
    }

    func updateBadges() {
        let dockItems = DockAccessibility.shared.queryDockItems()

        // Ensure we have enough badge windows
        ensureBadgeWindows(count: dockItems.count)

        // Update each badge window's position
        for (index, window) in badgeWindows.enumerated() {
            let position = index + 1
            if let item = dockItems.first(where: { $0.position == position }) {
                window.updatePosition(for: item.frame)
                window.hasValidPosition = true
            } else {
                window.hasValidPosition = false
            }
        }

        if isVisible {
            showBadges()
        }
    }

    private func ensureBadgeWindows(count: Int) {
        // Add more windows if needed
        while badgeWindows.count < count {
            let position = badgeWindows.count + 1
            let window = BadgeWindow(position: position)
            badgeWindows.append(window)
        }
    }

    private func showBadges() {
        for window in badgeWindows where window.hasValidPosition {
            window.orderFrontRegardless()
        }
    }

    private func hideBadges() {
        for window in badgeWindows {
            window.orderOut(nil)
        }
    }
}

// MARK: - BadgeWindow

private final class BadgeWindow: NSWindow {
    let position: Int
    var hasValidPosition = false

    private var badgeView: BadgeView!

    init(position: Int) {
        self.position = position

        let size = position > 9 ? DockConstants.badgeSizeLarge : DockConstants.badgeSize

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent()
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hasShadow = false
    }

    private func setupContent() {
        let size = position > 9 ? DockConstants.badgeSizeLarge : DockConstants.badgeSize
        badgeView = BadgeView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        badgeView.position = position
        contentView = badgeView
    }

    func updatePosition(for iconFrame: CGRect) {
        let size = position > 9 ? DockConstants.badgeSizeLarge : DockConstants.badgeSize
        let badgeX = iconFrame.maxX - size
        let badgeY = iconFrame.minY

        setFrameOrigin(NSPoint(x: badgeX, y: badgeY))
    }
}

// MARK: - BadgeView

private final class BadgeView: NSView {
    var position: Int = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw circle background
        let circlePath = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        NSColor.systemBlue.setFill()
        circlePath.fill()

        // White border
        NSColor.white.setStroke()
        circlePath.lineWidth = 1.5
        circlePath.stroke()

        // Draw number - adjust font size for 2-digit numbers
        let text = "\(position)"
        let fontSize: CGFloat = position > 9 ? 11 : 12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white
        ]

        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        text.draw(in: textRect, withAttributes: attributes)
    }
}
