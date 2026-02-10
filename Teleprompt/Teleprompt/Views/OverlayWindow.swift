import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    private var scrollController: ScrollController?
    private var settings: AppSettings?

    init(contentRect: NSRect, settings: AppSettings, scriptStore: ScriptStore, scrollController: ScrollController) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.scrollController = scrollController
        self.settings = settings

        // Critical: Exclude from screen sharing/recording
        self.sharingType = .none

        // Window behavior
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Allow mouse events for hover-to-pause
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true

        // Set minimum size
        self.minSize = NSSize(width: 400, height: 100)

        // Set the SwiftUI content
        let overlayView = OverlayContentView(
            settings: settings,
            scriptStore: scriptStore,
            scrollController: scrollController
        )
        self.contentView = NSHostingView(rootView: overlayView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        guard let scrollController = scrollController, let settings = settings else {
            super.keyDown(with: event)
            return
        }

        let scrollAmount = settings.fontSize + settings.lineSpacing

        switch event.keyCode {
        case 49: // Spacebar - play/pause
            scrollController.togglePlayPause()
        case 125: // Down arrow - scroll down
            scrollController.smoothScroll(by: scrollAmount)
        case 126: // Up arrow - scroll up
            scrollController.smoothScroll(by: -scrollAmount)
        default:
            super.keyDown(with: event)
        }
    }
}

class OverlayWindowController: NSWindowController {
    private let settings: AppSettings
    private let scriptStore: ScriptStore
    private let scrollController: ScrollController

    init(settings: AppSettings, scriptStore: ScriptStore, scrollController: ScrollController) {
        self.settings = settings
        self.scriptStore = scriptStore
        self.scrollController = scrollController

        let frame = ScreenHelper.calculateOverlayFrame(
            width: settings.overlayWidth,
            height: settings.overlayHeight
        )

        let window = OverlayWindow(
            contentRect: frame,
            settings: settings,
            scriptStore: scriptStore,
            scrollController: scrollController
        )

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func updatePosition() {
        guard let window = window else { return }
        let frame = ScreenHelper.calculateOverlayFrame(
            width: window.frame.width,
            height: window.frame.height
        )
        window.setFrame(frame, display: true)
    }
}
