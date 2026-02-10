import SwiftUI

struct MenuBarView: View {
    @ObservedObject var scriptStore: ScriptStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var scrollController: ScrollController

    var onToggleOverlay: () -> Void
    var onShowEditor: () -> Void
    var onShowSettings: () -> Void
    var isOverlayVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Script selection
            if !scriptStore.scripts.isEmpty {
                Text("Scripts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(scriptStore.scripts.prefix(5)) { script in
                    Button {
                        scriptStore.selectedScript = script
                        scrollController.reset()
                    } label: {
                        HStack {
                            if script.id == scriptStore.selectedScript?.id {
                                Image(systemName: "checkmark")
                                    .frame(width: 16)
                            } else {
                                Spacer()
                                    .frame(width: 16)
                            }
                            Text(script.title)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Playback controls
            HStack(spacing: 16) {
                Button {
                    scrollController.reset()
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.plain)
                .help("Reset")

                Button {
                    scrollController.togglePlayPause()
                } label: {
                    Image(systemName: scrollController.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help(scrollController.isPlaying ? "Pause" : "Play")

                Button {
                    scrollController.speedDown()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .help("Slower")

                Text("\(Int(settings.scrollSpeed))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 30)

                Button {
                    scrollController.speedUp()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("Faster")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 8)

            // Window controls
            Button {
                onToggleOverlay()
            } label: {
                HStack {
                    Image(systemName: isOverlayVisible ? "eye.slash" : "eye")
                        .frame(width: 16)
                    Text(isOverlayVisible ? "Hide Overlay" : "Show Overlay")
                    Spacer()
                    Text("⌘⇧T")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button {
                onShowEditor()
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .frame(width: 16)
                    Text("Script Editor")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button {
                onShowSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .frame(width: 16)
                    Text("Settings...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()
                .padding(.vertical, 8)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .frame(width: 16)
                    Text("Quit Teleprompt")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.bottom, 8)
        }
        .frame(width: 220)
    }
}
