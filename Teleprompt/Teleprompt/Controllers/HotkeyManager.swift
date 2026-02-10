import AppKit
import Carbon

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    var onSpeedUp: (() -> Void)?
    var onSpeedDown: (() -> Void)?
    var onReset: (() -> Void)?
    var onToggleOverlay: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func startListening() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Make sure accessibility permissions are granted.")
            requestAccessibilityPermissions()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopListening() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for Command + Shift modifiers
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)

        // ⌘⇧T - Toggle Overlay
        if hasCommand && hasShift && keyCode == 17 { // T key
            DispatchQueue.main.async {
                self.onToggleOverlay?()
            }
            return nil
        }

        // ⌘↑ - Speed Up
        if hasCommand && !hasShift && keyCode == 126 { // Up arrow
            DispatchQueue.main.async {
                self.onSpeedUp?()
            }
            return nil
        }

        // ⌘↓ - Speed Down
        if hasCommand && !hasShift && keyCode == 125 { // Down arrow
            DispatchQueue.main.async {
                self.onSpeedDown?()
            }
            return nil
        }

        // ⌘Home or ⌘⇧R - Reset/Jump to Start
        if hasCommand && hasShift && keyCode == 15 { // R key
            DispatchQueue.main.async {
                self.onReset?()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
}
