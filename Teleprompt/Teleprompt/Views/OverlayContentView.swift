import SwiftUI

struct OverlayContentView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scriptStore: ScriptStore
    @ObservedObject var scrollController: ScrollController

    @State private var isHovering = false
    @State private var wasPlayingBeforeHover = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.backgroundColor.opacity(settings.backgroundOpacity))

                // Scrolling text content
                ScrollingTextView(
                    text: scriptStore.selectedScript?.content ?? "No script selected",
                    scrollOffset: scrollController.scrollOffset,
                    settings: settings
                )
                .padding(.horizontal, settings.horizontalPadding)
                .padding(.vertical, 16)

                // Gradient overlays for fade effect
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            settings.backgroundColor.opacity(settings.backgroundOpacity),
                            settings.backgroundColor.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)

                    Spacer()

                    LinearGradient(
                        gradient: Gradient(colors: [
                            settings.backgroundColor.opacity(0),
                            settings.backgroundColor.opacity(settings.backgroundOpacity)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Focus indicator line at reading position
                if settings.highlightCurrentLine {
                    VStack {
                        Spacer()
                            .frame(height: geometry.size.height * 0.33)
                        HStack {
                            Rectangle()
                                .fill(Color.yellow.opacity(0.6))
                                .frame(width: 4)
                                .cornerRadius(2)
                            Spacer()
                        }
                        .frame(height: settings.fontSize + 8)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }

                // Play/Pause indicator
                if !scrollController.isPlaying {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: isHovering ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(12)
                        }
                    }
                }

                // Drag handle indicator
                VStack {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 6)
                    Spacer()
                }
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering && scrollController.isPlaying {
                wasPlayingBeforeHover = true
                scrollController.pause()
            } else if !hovering && wasPlayingBeforeHover {
                wasPlayingBeforeHover = false
                scrollController.play()
            }
        }
        .onTapGesture {
            scrollController.togglePlayPause()
        }
    }
}

struct ScrollingTextView: View {
    let text: String
    let scrollOffset: CGFloat
    @ObservedObject var settings: AppSettings

    var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: settings.lineSpacing) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.custom(settings.fontName, size: settings.fontSize))
                        .foregroundColor(settings.textColor)
                        .lineSpacing(settings.lineSpacing)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -scrollOffset)
        }
        .clipped()
    }
}

struct OverlayContentView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayContentView(
            settings: AppSettings(),
            scriptStore: ScriptStore(),
            scrollController: ScrollController(settings: AppSettings())
        )
        .frame(width: 800, height: 200)
    }
}
