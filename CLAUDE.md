# CLAUDE.md - Teleprompt

## Project Overview

Teleprompt is a macOS menu bar teleprompter app built with SwiftUI and AppKit. It displays scrolling script text in a floating overlay window.

## Architecture

The app follows an MVC pattern with SwiftUI views:

```
Teleprompt/Teleprompt/
├── TelepromptApp.swift       # App entry point, AppDelegate, window management
├── Models/
│   ├── AppSettings.swift     # @AppStorage-backed settings (ObservableObject)
│   └── Script.swift          # Script model + ScriptStore persistence
├── Controllers/
│   ├── ScrollController.swift  # CVDisplayLink-based scroll engine
│   └── HotkeyManager.swift    # CGEvent tap for global keyboard shortcuts
├── Views/
│   ├── MenuBarView.swift       # Status bar popover menu
│   ├── EditorView.swift        # Script editor (NavigationSplitView)
│   ├── OverlayWindow.swift     # NSWindow subclass for floating overlay
│   ├── OverlayContentView.swift # Scrolling text display
│   └── SettingsView.swift      # TabView settings panel
└── Utilities/
    └── ScreenHelper.swift      # Screen geometry and notch detection
```

## Key Patterns

- **ObservableObject**: AppSettings, ScriptStore, and ScrollController use @Published for reactive UI updates.
- **@AppStorage**: All settings persist via UserDefaults automatically.
- **CVDisplayLink**: Scrolling is frame-synced for smoothness, not timer-based.
- **CGEvent tap**: Global hotkeys are captured via a system-wide event tap (requires accessibility permissions).
- **NSWindow subclass**: The overlay is a custom borderless, floating, transparent window.
- **Menu bar app**: LSUIElement=true in Info.plist hides the dock icon.

## Data Storage

- Scripts: `~/Documents/teleprompt_scripts.json` (JSON-encoded array of Script structs)
- Settings: UserDefaults via @AppStorage

## Build

- Open `Teleprompt/Teleprompt.xcodeproj` in Xcode
- Target: macOS 14.0+
- No external dependencies or package managers

## Common Tasks

- **Adding a new setting**: Add an @AppStorage property to `AppSettings.swift`, then add UI in `SettingsView.swift`.
- **Adding a new hotkey**: Add a key code check in `HotkeyManager.swift` `handleKeyEvent()`, wire the callback in `TelepromptApp.swift`.
- **Modifying scroll behavior**: Edit `ScrollController.swift`. The `updateScroll()` method runs every display frame.
- **Changing overlay appearance**: Edit `OverlayContentView.swift` for the text display, `OverlayWindow.swift` for window-level behavior.
