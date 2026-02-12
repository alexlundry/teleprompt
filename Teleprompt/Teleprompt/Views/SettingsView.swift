import SwiftUI
import Speech
import AVFAudio

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

            VoiceTrackingSettingsView(settings: settings)
                .tabItem {
                    Label("Voice", systemImage: "mic")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .padding(20)
        .frame(width: 450, height: 380)
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

struct VoiceTrackingSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var micGranted: Bool = (AVAudioApplication.shared.recordPermission == .granted)
    @State private var micPromptTriggered: Bool = false

    var body: some View {
        Form {
            Section("Voice Tracking") {
                Toggle("Enable voice tracking", isOn: $settings.voiceTrackingEnabled)

                Text("When enabled, the teleprompter scrolls automatically by listening to your voice and matching it to the script text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Permissions") {
                HStack {
                    if micGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Microphone access granted")
                    } else if micPromptTriggered {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Microphone — enable in System Settings")
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        }
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Microphone access required")
                        Spacer()
                        Button("Request") {
                            triggerMicPermission()
                        }
                    }
                }
                .onAppear {
                    micGranted = (AVAudioApplication.shared.recordPermission == .granted)
                }

                HStack {
                    if speechStatus == .authorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Speech recognition access granted")
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Speech recognition access required")
                        Spacer()
                        Button("Request") {
                            SFSpeechRecognizer.requestAuthorization { status in
                                DispatchQueue.main.async {
                                    speechStatus = status
                                }
                            }
                        }
                    }
                }
            }

            Section("How It Works") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Uses on-device speech recognition", systemImage: "cpu")
                    Label("Matches your spoken words to the script", systemImage: "text.magnifyingglass")
                    Label("Scrolls to keep pace with your reading", systemImage: "arrow.down.doc")
                    Label("Pauses when you pause speaking", systemImage: "pause")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Briefly start the audio engine to trigger the macOS mic permission prompt,
    /// then immediately stop. This registers the app in System Settings > Microphone.
    private func triggerMicPermission() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
        engine.prepare()
        do {
            try engine.start()
            // Brief access is enough to trigger the prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
                // Check if permission was granted after the prompt
                let granted = AVAudioApplication.shared.recordPermission == .granted
                micGranted = granted
                if !granted {
                    micPromptTriggered = true
                }
            }
        } catch {
            // Engine failed to start — permission was denied or unavailable
            micPromptTriggered = true
        }
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
