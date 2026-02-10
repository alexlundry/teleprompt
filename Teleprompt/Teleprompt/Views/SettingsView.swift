import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            AppearanceSettingsView(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ScrollSettingsView(settings: settings)
                .tabItem {
                    Label("Scrolling", systemImage: "scroll")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .padding(20)
        .frame(width: 450, height: 350)
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    let availableFonts = ["SF Pro", "SF Mono", "Helvetica Neue", "Arial", "Georgia", "Menlo"]

    var body: some View {
        Form {
            Section("Text") {
                Picker("Font", selection: $settings.fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $settings.fontSize, in: 16...72, step: 2)
                        .frame(width: 150)
                    Text("\(Int(settings.fontSize)) pt")
                        .frame(width: 50)
                }

                ColorPicker("Text Color", selection: Binding(
                    get: { settings.textColor },
                    set: { settings.textColor = $0 }
                ))

                Toggle("Mirror Text (for teleprompter glass)", isOn: $settings.mirrorText)
            }

            Section("Background") {
                ColorPicker("Background Color", selection: Binding(
                    get: { settings.backgroundColor },
                    set: { settings.backgroundColor = $0 }
                ))

                HStack {
                    Text("Opacity")
                    Spacer()
                    Slider(value: $settings.backgroundOpacity, in: 0.3...1.0, step: 0.05)
                        .frame(width: 150)
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .frame(width: 50)
                }
            }

            Section("Layout") {
                HStack {
                    Text("Line Spacing")
                    Spacer()
                    Slider(value: $settings.lineSpacing, in: 4...32, step: 2)
                        .frame(width: 150)
                    Text("\(Int(settings.lineSpacing)) pt")
                        .frame(width: 50)
                }

                HStack {
                    Text("Horizontal Padding")
                    Spacer()
                    Slider(value: $settings.horizontalPadding, in: 10...80, step: 5)
                        .frame(width: 150)
                    Text("\(Int(settings.horizontalPadding)) pt")
                        .frame(width: 50)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ScrollSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Speed") {
                HStack {
                    Text("Scroll Speed")
                    Spacer()
                    Slider(value: $settings.scrollSpeed, in: 20...300, step: 5)
                        .frame(width: 150)
                    Text("\(Int(settings.scrollSpeed)) WPM")
                        .frame(width: 70)
                }

                Text("Words per minute - adjust based on your reading pace")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Overlay Size") {
                HStack {
                    Text("Width")
                    Spacer()
                    Slider(value: $settings.overlayWidth, in: 400...1200, step: 50)
                        .frame(width: 150)
                    Text("\(Int(settings.overlayWidth)) px")
                        .frame(width: 60)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    Slider(value: $settings.overlayHeight, in: 100...400, step: 25)
                        .frame(width: 150)
                    Text("\(Int(settings.overlayHeight)) px")
                        .frame(width: 60)
                }

                Text("You can also resize the overlay by dragging its edges")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Highlight current line", isOn: $settings.highlightCurrentLine)
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Overlay Controls (click overlay to focus)") {
                ShortcutRow(action: "Play / Pause", shortcut: "Space")
                ShortcutRow(action: "Scroll Down", shortcut: "↓")
                ShortcutRow(action: "Scroll Up", shortcut: "↑")
                ShortcutRow(action: "Pause on Hover", shortcut: "Hover")
                ShortcutRow(action: "Play / Pause", shortcut: "Click")
            }

            Section("Global Shortcuts") {
                ShortcutRow(action: "Toggle Overlay", shortcut: "⌘⇧T")
                ShortcutRow(action: "Speed Up", shortcut: "⌘↑")
                ShortcutRow(action: "Speed Down", shortcut: "⌘↓")
                ShortcutRow(action: "Reset to Start", shortcut: "⌘⇧R")
            }

            Section("Permissions") {
                HStack {
                    if HotkeyManager.checkAccessibilityPermissions() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility access required")
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: AppSettings())
    }
}
