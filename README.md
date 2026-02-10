# Teleprompt

A macOS menu bar teleprompter app for natural video calls, presentations, and recordings. Displays scrolling script text in a floating overlay near your camera so you can maintain eye contact while reading.

## Features

- **Floating overlay** - Transparent, always-on-top window positioned near your camera. Excluded from screen recording so it won't appear in calls or captures.
- **Smooth scrolling** - Frame-synced scrolling via CVDisplayLink with adjustable speed (20-300 WPM).
- **Script management** - Create, edit, and organize multiple scripts with word count and estimated read time.
- **File import** - Import scripts from `.txt`, `.docx`, `.doc`, and `.rtf` files.
- **Global hotkeys** - Control playback from any app without switching windows.
- **Customizable appearance** - Font, size, color, background opacity, line spacing, and padding.
- **Interactive overlay** - Hover to pause, click to toggle, arrow keys to manually scroll.
- **Mirror mode** - Flip text horizontally for use with reflective glass teleprompters.
- **Menu bar app** - Lives in the menu bar with quick access to scripts and playback controls.

## Keyboard Shortcuts

### Overlay Controls (when overlay is focused)
| Action | Shortcut |
|--------|----------|
| Play / Pause | `Space` |
| Scroll Up | `Up Arrow` |
| Scroll Down | `Down Arrow` |

### Global Hotkeys (work from any app)
| Action | Shortcut |
|--------|----------|
| Toggle Overlay | `Cmd + Shift + T` |
| Speed Up | `Cmd + Up Arrow` |
| Speed Down | `Cmd + Down Arrow` |
| Reset to Start | `Cmd + Shift + R` |

> Global hotkeys require accessibility permissions. The app will prompt you on first launch.

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permissions (for global hotkeys)

## Building

1. Open `Teleprompt/Teleprompt.xcodeproj` in Xcode
2. Select the Teleprompt scheme
3. Build and run (`Cmd + R`)

## License

All rights reserved.
