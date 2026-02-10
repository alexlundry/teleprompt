import SwiftUI
import AppKit

@main
struct TelepromptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var overlayWindowController: OverlayWindowController?
    var editorWindow: NSWindow?
    var settingsWindow: NSWindow?

    let settings = AppSettings()
    let scriptStore = ScriptStore()
    var scrollController: ScrollController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        scrollController = ScrollController(settings: settings)

        setupMenuBar()
        setupOverlayWindow()
        setupHotkeys()

        // Hide dock icon - we're a menu bar app
        NSApp.setActivationPolicy(.accessory)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Teleprompt")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView(
                scriptStore: scriptStore,
                settings: settings,
                scrollController: scrollController,
                onToggleOverlay: { [weak self] in
                    self?.toggleOverlay()
                    self?.popover?.close()
                },
                onShowEditor: { [weak self] in
                    self?.showEditor()
                    self?.popover?.close()
                },
                onShowSettings: { [weak self] in
                    self?.showSettings()
                    self?.popover?.close()
                },
                isOverlayVisible: overlayWindowController?.window?.isVisible ?? false
            )
        )
    }

    func setupOverlayWindow() {
        overlayWindowController = OverlayWindowController(
            settings: settings,
            scriptStore: scriptStore,
            scrollController: scrollController
        )
        overlayWindowController?.show()
    }

    func setupHotkeys() {
        let hotkeyManager = HotkeyManager.shared

        hotkeyManager.onSpeedUp = { [weak self] in
            self?.scrollController.speedUp()
        }

        hotkeyManager.onSpeedDown = { [weak self] in
            self?.scrollController.speedDown()
        }

        hotkeyManager.onReset = { [weak self] in
            self?.scrollController.reset()
        }

        hotkeyManager.onToggleOverlay = { [weak self] in
            self?.toggleOverlay()
        }

        // Check and request accessibility permissions
        if !HotkeyManager.checkAccessibilityPermissions() {
            hotkeyManager.requestAccessibilityPermissions()
        }

        hotkeyManager.startListening()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        // Update the view with current overlay visibility state
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView(
                scriptStore: scriptStore,
                settings: settings,
                scrollController: scrollController,
                onToggleOverlay: { [weak self] in
                    self?.toggleOverlay()
                    self?.popover?.close()
                },
                onShowEditor: { [weak self] in
                    self?.showEditor()
                    self?.popover?.close()
                },
                onShowSettings: { [weak self] in
                    self?.showSettings()
                    self?.popover?.close()
                },
                isOverlayVisible: overlayWindowController?.window?.isVisible ?? false
            )
        )

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func toggleOverlay() {
        overlayWindowController?.toggle()
    }

    func showEditor() {
        if editorWindow == nil {
            let editorView = EditorView(
                scriptStore: scriptStore,
                settings: settings,
                scrollController: scrollController
            )

            editorWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            editorWindow?.title = "Teleprompt - Script Editor"
            editorWindow?.contentView = NSHostingView(rootView: editorView)
            editorWindow?.center()
            editorWindow?.setFrameAutosaveName("EditorWindow")
        }

        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: settings)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Teleprompt Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stopListening()
        scriptStore.saveScripts()
    }
}
