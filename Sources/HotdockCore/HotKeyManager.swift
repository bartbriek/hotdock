import Foundation
import CoreGraphics
import Carbon
import os.lock

// MARK: - Constants

private enum KeyCodes {
    // Number keys 0-9
    static let mappings: [CGKeyCode: Int] = [
        29: 0,  // 0
        18: 1,  // 1
        19: 2,  // 2
        20: 3,  // 3
        21: 4,  // 4
        23: 5,  // 5
        22: 6,  // 6
        26: 7,  // 7
        28: 8,  // 8
        25: 9   // 9
    ]
}

private enum HotKeyConstants {
    /// Time to wait for additional digits (in seconds)
    static let multiDigitTimeout: TimeInterval = 0.4
}

// MARK: - HotKeyManager

final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotKey: ((Int) -> Void)?
    var onControlChanged: ((Bool) -> Void)?

    // Thread-safe access to controlIsDown
    private var _controlIsDown = false
    private var lock = os_unfair_lock()

    private var controlIsDown: Bool {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _controlIsDown
        }
        set {
            os_unfair_lock_lock(&lock)
            _controlIsDown = newValue
            os_unfair_lock_unlock(&lock)
        }
    }

    // Multi-digit input handling
    private var digitBuffer: [Int] = []
    private var digitTimer: DispatchWorkItem?
    private let digitQueue = DispatchQueue(label: "com.hotdock.digit-buffer")

    init() {}

    deinit {
        stop()
    }

    func start() -> Bool {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap. Make sure Accessibility is enabled.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        digitTimer?.cancel()
        digitTimer = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let ctrlPressed = flags.contains(.maskControl)
        let cmdPressed = flags.contains(.maskCommand)
        let optPressed = flags.contains(.maskAlternate)
        let shiftPressed = flags.contains(.maskShift)

        // Handle modifier key changes (Ctrl press/release)
        if type == .flagsChanged {
            let ctrlOnly = ctrlPressed && !cmdPressed && !optPressed && !shiftPressed
            let wasDown = controlIsDown

            if ctrlOnly && !wasDown {
                controlIsDown = true
                DispatchQueue.main.async { [weak self] in
                    self?.onControlChanged?(true)
                }
            } else if !ctrlPressed && wasDown {
                controlIsDown = false
                // When Ctrl is released, immediately fire any pending digits
                flushDigitBuffer()
                DispatchQueue.main.async { [weak self] in
                    self?.onControlChanged?(false)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Handle Ctrl+number hotkeys
        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

            if ctrlPressed && !cmdPressed && !optPressed && !shiftPressed {
                if let digit = KeyCodes.mappings[keyCode] {
                    appendDigit(digit)
                    return nil  // Consume the event
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Multi-digit Input

    private func appendDigit(_ digit: Int) {
        digitQueue.async { [weak self] in
            guard let self = self else { return }

            // Cancel existing timer
            self.digitTimer?.cancel()

            // Add digit to buffer
            self.digitBuffer.append(digit)

            // Start new timer
            let workItem = DispatchWorkItem { [weak self] in
                self?.flushDigitBuffer()
            }
            self.digitTimer = workItem
            self.digitQueue.asyncAfter(
                deadline: .now() + HotKeyConstants.multiDigitTimeout,
                execute: workItem
            )
        }
    }

    private func flushDigitBuffer() {
        digitQueue.async { [weak self] in
            guard let self = self, !self.digitBuffer.isEmpty else { return }

            // Cancel any pending timer
            self.digitTimer?.cancel()
            self.digitTimer = nil

            // Convert digits to position number
            let position = self.digitBuffer.reduce(0) { result, digit in
                result * 10 + digit
            }

            // Clear buffer
            self.digitBuffer.removeAll()

            // Only trigger for valid positions (1+)
            guard position > 0 else { return }

            DispatchQueue.main.async { [weak self] in
                self?.onHotKey?(position)
            }
        }
    }
}
