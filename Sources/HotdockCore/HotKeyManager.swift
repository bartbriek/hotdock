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

private enum PickerKeyCodes {
    static let up: CGKeyCode = 126
    static let down: CGKeyCode = 125
    static let returnKey: CGKeyCode = 36
    static let keypadEnter: CGKeyCode = 76
    static let escape: CGKeyCode = 53
}

private enum HotKeyConstants {
    /// Time to wait for additional digits (in seconds)
    static let multiDigitTimeout: TimeInterval = 0.4

    /// Dock positions stop at 99, so a shortcut is never more than two digits.
    /// Bounding the buffer also keeps the position arithmetic from overflowing.
    static let maxDigits = 2
}

// MARK: - HotKeyManager

final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotKey: ((Int) -> Void)?
    var onLongPress: ((Int) -> Void)?
    var onPickerKey: ((PickerKey) -> Void)?
    var onControlChanged: ((Bool) -> Void)?

    /// While the picker is open the tap routes navigation keys to it instead of the dock
    /// shortcuts, which is what lets the panel work without taking keyboard focus.
    var isPickerOpen: Bool {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _isPickerOpen
        }
        set {
            os_unfair_lock_lock(&lock)
            _isPickerOpen = newValue
            os_unfair_lock_unlock(&lock)
        }
    }

    // Thread-safe access to state shared between the event tap and the digit queue
    private var _controlIsDown = false
    private var _heldKeyCode: CGKeyCode?
    private var _isPickerOpen = false
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
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

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
                // When Ctrl is released, immediately fire any pending digits as a plain toggle
                flushDigitBuffer(allowLongPress: false)
                DispatchQueue.main.async { [weak self] in
                    self?.onControlChanged?(false)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Release of a digit key we consumed: ends the window cycle, if one is running
        if type == .keyUp {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            return releaseKey(keyCode) ? nil : Unmanaged.passUnretained(event)
        }

        // Handle Ctrl+number hotkeys
        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

            if isPickerOpen, let key = pickerKey(for: keyCode) {
                DispatchQueue.main.async { [weak self] in
                    self?.onPickerKey?(key)
                }
                return nil
            }

            if ctrlPressed && !cmdPressed && !optPressed && !shiftPressed {
                if let digit = KeyCodes.mappings[keyCode] {
                    // Swallow OS auto-repeat: the hold is tracked by our own timing, and
                    // repeats would otherwise pile extra digits into the buffer
                    guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }

                    holdKey(keyCode)
                    appendDigit(digit)
                    return nil  // Consume the event
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Long Press State

    private func holdKey(_ keyCode: CGKeyCode) {
        os_unfair_lock_lock(&lock)
        _heldKeyCode = keyCode
        os_unfair_lock_unlock(&lock)
    }

    /// Clears the held key. Returns whether the key-up belongs to a key-down we consumed,
    /// so the caller knows to swallow it too.
    private func releaseKey(_ keyCode: CGKeyCode) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard _heldKeyCode == keyCode else { return false }
        _heldKeyCode = nil
        return true
    }

    private func pickerKey(for keyCode: CGKeyCode) -> PickerKey? {
        switch keyCode {
        case PickerKeyCodes.up: return .up
        case PickerKeyCodes.down: return .down
        case PickerKeyCodes.returnKey, PickerKeyCodes.keypadEnter: return .confirm
        case PickerKeyCodes.escape: return .cancel
        default:
            guard let digit = KeyCodes.mappings[keyCode], digit > 0 else { return nil }
            return .digit(digit)
        }
    }

    /// Dispatches a flushed shortcut. Reading the held key under the lock keeps the
    /// long-press decision ordered against a key-up arriving on another thread.
    private func dispatch(position: Int, allowLongPress: Bool) {
        os_unfair_lock_lock(&lock)
        let isLongPress = allowLongPress && _heldKeyCode != nil
        os_unfair_lock_unlock(&lock)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isLongPress {
                self.onLongPress?(position)
            } else {
                self.onHotKey?(position)
            }
        }
    }

    // MARK: - Multi-digit Input

    private func appendDigit(_ digit: Int) {
        digitQueue.async { [weak self] in
            guard let self = self else { return }

            // Drop digits past the second one, and leave the pending timer alone so the
            // shortcut still fires instead of being pushed back by every extra keypress
            guard self.digitBuffer.count < HotKeyConstants.maxDigits else { return }

            // Cancel existing timer
            self.digitTimer?.cancel()

            // Add digit to buffer
            self.digitBuffer.append(digit)

            // Start new timer
            let workItem = DispatchWorkItem { [weak self] in
                self?.flushDigitBuffer(allowLongPress: true)
            }
            self.digitTimer = workItem
            self.digitQueue.asyncAfter(
                deadline: .now() + HotKeyConstants.multiDigitTimeout,
                execute: workItem
            )
        }
    }

    private func flushDigitBuffer(allowLongPress: Bool) {
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

            self.dispatch(position: position, allowLongPress: allowLongPress)
        }
    }
}

// MARK: - PickerKey

enum PickerKey {
    case up
    case down
    case confirm
    case cancel
    case digit(Int)
}
