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
                    settings: settings,
                    scrollController: scrollController,
                    highlightWordIndex: scrollController.voiceTrackingActive ? scrollController.currentHighlightWordIndex : nil
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
                            .frame(height: geometry.size.height * 0.5)
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

                // Play/Pause indicator (hide when voice tracking is active)
                if !scrollController.isPlaying && !scrollController.voiceTrackingActive {
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

                // Voice tracking indicator
                if scrollController.voiceTrackingActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red.opacity(0.8))
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
            .onChange(of: geometry.size) {
                scrollController.overlayHeight = geometry.size.height
            }
            .onAppear {
                scrollController.overlayHeight = geometry.size.height
            }
        }
        .onHover { hovering in
            isHovering = hovering
            // Don't auto-pause on hover when voice tracking is active
            guard !scrollController.voiceTrackingActive else { return }
            if hovering && scrollController.isPlaying {
                wasPlayingBeforeHover = true
                scrollController.pause()
            } else if !hovering && wasPlayingBeforeHover {
                wasPlayingBeforeHover = false
                scrollController.play()
            }
        }
        .onTapGesture {
            if !scrollController.voiceTrackingActive {
                scrollController.togglePlayPause()
            }
        }
    }
}

struct ScrollingTextView: View {
    let text: String
    let scrollOffset: CGFloat
    @ObservedObject var settings: AppSettings
    var scrollController: ScrollController?
    var highlightWordIndex: Int?

    var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    private let highlightAheadCount = 8 // words highlighted ahead of current word

    /// Map each word (by global index) to which line (paragraph) it belongs to
    private var wordToLine: [Int: (lineIndex: Int, wordInLine: Int)] {
        var map: [Int: (Int, Int)] = [:]
        var globalIdx = 0
        for (lineIdx, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: true)
            for (wordIdx, _) in words.enumerated() {
                map[globalIdx] = (lineIdx, wordIdx)
                globalIdx += 1
            }
        }
        return map
    }

    /// The global word indices that should be highlighted:
    /// starts at the matched word and extends forward.
    private var highlightedIndices: Set<Int> {
        guard let idx = highlightWordIndex else { return [] }
        let totalWords = wordToLine.count
        let end = min(totalWords - 1, idx + highlightAheadCount)
        return Set(idx...end)
    }

    /// Which lines contain at least one highlighted word
    private var linesWithHighlighting: [Int: [(wordInLine: Int, isCurrent: Bool)]] {
        var result: [Int: [(Int, Bool)]] = [:]
        for globalIdx in highlightedIndices {
            guard let mapping = wordToLine[globalIdx] else { continue }
            let isCurrent = (globalIdx == highlightWordIndex)
            result[mapping.lineIndex, default: []].append((mapping.wordInLine, isCurrent))
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: settings.lineSpacing) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    lineView(line: line, lineIndex: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -scrollOffset)
            .onAppear {
                updateWordOffsets(viewWidth: geometry.size.width)
            }
            .onChange(of: text) {
                updateWordOffsets(viewWidth: geometry.size.width)
            }
            .onChange(of: settings.fontSize) {
                updateWordOffsets(viewWidth: geometry.size.width)
            }
            .onChange(of: settings.lineSpacing) {
                updateWordOffsets(viewWidth: geometry.size.width)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func lineView(line: String, lineIndex: Int) -> some View {
        if let hlWords = linesWithHighlighting[lineIndex] {
            let currentSet = Set(hlWords.filter { $0.isCurrent }.map { $0.wordInLine })
            let surroundSet = Set(hlWords.map { $0.wordInLine })
            Text(buildHighlightedLine(line, currentWords: currentSet, surroundWords: surroundSet))
                .lineSpacing(settings.lineSpacing)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
        } else {
            Text(line.isEmpty ? " " : line)
                .font(.custom(settings.fontName, size: settings.fontSize))
                .foregroundColor(settings.textColor)
                .lineSpacing(settings.lineSpacing)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
        }
    }

    /// Build an AttributedString with real yellow background highlighting
    private func buildHighlightedLine(_ line: String, currentWords: Set<Int>, surroundWords: Set<Int>) -> AttributedString {
        let words = line.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else {
            var attr = AttributedString(" ")
            attr.font = .custom(settings.fontName, size: settings.fontSize)
            attr.foregroundColor = settings.textColor
            return attr
        }

        let allHighlighted = surroundWords.union(currentWords)

        var result = AttributedString("")
        for (idx, word) in words.enumerated() {
            if idx > 0 {
                var space = AttributedString(" ")
                space.font = .custom(settings.fontName, size: settings.fontSize)
                // Highlight the space if both adjacent words are highlighted
                if allHighlighted.contains(idx - 1) && allHighlighted.contains(idx) {
                    space.backgroundColor = .yellow
                    space.foregroundColor = .black
                } else {
                    space.foregroundColor = settings.textColor
                }
                result += space
            }

            var wordAttr = AttributedString(String(word))
            wordAttr.font = .custom(settings.fontName, size: settings.fontSize)

            if allHighlighted.contains(idx) {
                wordAttr.backgroundColor = .yellow
                wordAttr.foregroundColor = .black
            } else {
                wordAttr.foregroundColor = settings.textColor
            }

            result += wordAttr
        }
        return result
    }

    /// Pre-calculate the Y offset of each word for scroll-to-word mapping,
    /// accounting for line wrapping within paragraphs.
    private func updateWordOffsets(viewWidth: CGFloat) {
        guard let scrollController = scrollController else { return }

        let font = NSFont(name: settings.fontName, size: settings.fontSize) ?? NSFont.systemFont(ofSize: settings.fontSize)
        let spaceWidth = NSAttributedString(string: " ", attributes: [.font: font]).size().width
        let singleLineHeight = ceil(font.ascender - font.descender + font.leading)
        let lineAdvance = singleLineHeight + settings.lineSpacing

        var wordOffsets: [Int: CGFloat] = [:]
        var globalWordIdx = 0
        var cumulativeY: CGFloat = 0
        let constraintWidth = max(viewWidth, 100)

        for line in lines {
            let words = line.split(separator: " ", omittingEmptySubsequences: true)

            if words.isEmpty {
                // Empty line (paragraph break) still takes up space
                cumulativeY += lineAdvance
                continue
            }

            var currentLineWidth: CGFloat = 0
            var visualLineY = cumulativeY

            for word in words {
                let wordWidth = NSAttributedString(string: String(word), attributes: [.font: font]).size().width

                // Check if adding this word would overflow the current visual line
                let neededWidth = currentLineWidth > 0 ? currentLineWidth + spaceWidth + wordWidth : wordWidth
                if currentLineWidth > 0 && neededWidth > constraintWidth {
                    // Wrap to next visual line
                    visualLineY += lineAdvance
                    currentLineWidth = wordWidth
                } else {
                    currentLineWidth = neededWidth
                }

                wordOffsets[globalWordIdx] = visualLineY
                globalWordIdx += 1
            }

            // Advance past this paragraph's last visual line
            cumulativeY = visualLineY + lineAdvance
        }

        scrollController.wordOffsets = wordOffsets
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
