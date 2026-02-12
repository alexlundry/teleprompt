import SwiftUI
import Combine

class ScrollController: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var currentLineIndex: Int = 0
    @Published var voiceTrackingActive: Bool = false
    @Published var currentHighlightWordIndex: Int?

    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var settings: AppSettings

    // For smooth manual scrolling
    private var targetOffset: CGFloat = 0
    private var isAnimatingManualScroll: Bool = false

    // Voice tracking EMA smoothing state
    private var voiceTargetOffset: CGFloat = 0
    private var voiceSmoothedOffset: CGFloat = 0
    private let emaAlpha: CGFloat = 0.13  // ~350ms to 95% convergence at 60fps
    private let minTargetChange: CGFloat = 3.0  // ignore target changes smaller than this

    // Smooth highlight interpolation
    private var targetHighlightWordIndex: Int? = nil
    private var highlightAdvanceAccumulator: CFTimeInterval = 0

    // Word position mapping (populated by OverlayContentView)
    var wordOffsets: [Int: CGFloat] = [:]
    var overlayHeight: CGFloat = 200

    /// Called when the user manually scrolls during voice tracking, with the
    /// approximate word index at the new scroll position.
    var onManualScroll: ((Int) -> Void)?

    // Scroll speed in points per second (calculated from words per minute)
    var scrollSpeedPointsPerSecond: CGFloat {
        // Approximate: 5 words per line, 24pt line height at default settings
        // At 60 WPM: 60 words/min = 1 word/sec = 0.2 lines/sec
        // With ~40pt per line (font + spacing), that's about 8 points/sec at 60 WPM
        let lineHeight = settings.fontSize + settings.lineSpacing
        let wordsPerLine: CGFloat = 8
        let linesPerMinute = settings.scrollSpeed / wordsPerLine
        let linesPerSecond = linesPerMinute / 60
        return linesPerSecond * lineHeight
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastFrameTime = CACurrentMediaTime()
        startDisplayLink()
    }

    func pause() {
        isPlaying = false
        stopDisplayLink()
    }

    func reset() {
        pause()
        scrollOffset = 0
        currentLineIndex = 0
    }

    func speedUp() {
        settings.scrollSpeed = min(settings.scrollSpeed + 10, 300)
    }

    func speedDown() {
        settings.scrollSpeed = max(settings.scrollSpeed - 10, 10)
    }

    func adjustOffset(by delta: CGFloat) {
        scrollOffset = max(0, scrollOffset + delta)
    }

    func smoothScroll(by delta: CGFloat) {
        targetOffset = max(0, scrollOffset + delta)
        if !isAnimatingManualScroll {
            isAnimatingManualScroll = true
            animateToTarget()
        }
    }

    private func animateToTarget() {
        let animationDuration: CGFloat = 0.15
        let steps = 10
        let stepDuration = animationDuration / CGFloat(steps)
        let totalDelta = targetOffset - scrollOffset
        let stepDelta = totalDelta / CGFloat(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(stepDuration) * Double(i)) { [weak self] in
                guard let self = self else { return }
                self.scrollOffset = max(0, self.scrollOffset + stepDelta)
                if i == steps - 1 {
                    self.scrollOffset = self.targetOffset
                    self.isAnimatingManualScroll = false
                }
            }
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let newLink = link else { return }
        self.displayLink = newLink

        let opaqueController = Unmanaged.passUnretained(self).toOpaque()

        CVDisplayLinkSetOutputCallback(newLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, context) -> CVReturn in
            guard let context = context else { return kCVReturnSuccess }
            let controller = Unmanaged<ScrollController>.fromOpaque(context).takeUnretainedValue()

            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - controller.lastFrameTime
            controller.lastFrameTime = currentTime

            DispatchQueue.main.async {
                if controller.voiceTrackingActive {
                    // Smoothly advance highlight toward target word
                    if let target = controller.targetHighlightWordIndex,
                       let current = controller.currentHighlightWordIndex {
                        if current < target {
                            controller.highlightAdvanceAccumulator += deltaTime
                            // Advance rate scales with gap: bigger gap = faster catch-up
                            let gap = target - current
                            let interval = gap > 5 ? 0.04 : gap > 2 ? 0.08 : 0.12
                            if controller.highlightAdvanceAccumulator >= interval {
                                controller.highlightAdvanceAccumulator = 0
                                let newIndex = current + 1
                                controller.currentHighlightWordIndex = newIndex
                                // Update scroll target based on interpolated highlight
                                if let targetY = controller.wordOffsets[newIndex] {
                                    let newTarget = max(0, targetY - controller.overlayHeight * 0.5)
                                    if abs(newTarget - controller.voiceTargetOffset) >= controller.minTargetChange {
                                        controller.voiceTargetOffset = newTarget
                                    }
                                }
                            }
                        } else {
                            controller.highlightAdvanceAccumulator = 0
                        }
                    }

                    // EMA smoothing for scroll position
                    let diff = controller.voiceTargetOffset - controller.voiceSmoothedOffset
                    controller.voiceSmoothedOffset += controller.emaAlpha * diff
                    if abs(diff) < 0.5 {
                        controller.voiceSmoothedOffset = controller.voiceTargetOffset
                    }
                    controller.scrollOffset = controller.voiceSmoothedOffset
                } else if controller.isPlaying {
                    // WPM-based scrolling
                    controller.scrollOffset += controller.scrollSpeedPointsPerSecond * CGFloat(deltaTime)
                }
            }

            return kCVReturnSuccess
        }, opaqueController)

        CVDisplayLinkStart(newLink)
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    // MARK: - Voice Tracking

    func enableVoiceTracking() {
        voiceTrackingActive = true
        // Stop WPM-based scrolling — voice tracker drives offset now
        isPlaying = false

        // Initialize EMA state from current position
        voiceSmoothedOffset = scrollOffset
        voiceTargetOffset = scrollOffset

        // Start display link for EMA smoothing
        startDisplayLink()
    }

    func disableVoiceTracking() {
        voiceTrackingActive = false
        currentHighlightWordIndex = nil
        targetHighlightWordIndex = nil
        highlightAdvanceAccumulator = 0
        stopDisplayLink()
    }

    func scrollToWordIndex(_ wordIndex: Int) {
        guard voiceTrackingActive else { return }

        targetHighlightWordIndex = wordIndex

        // If highlight hasn't started yet, jump directly
        if currentHighlightWordIndex == nil {
            currentHighlightWordIndex = wordIndex
        }
        // The display link will smoothly advance currentHighlightWordIndex
        // toward the target and update the scroll offset as it goes.
    }

    /// Manual scroll adjustment during voice tracking (arrow keys, scroll wheel).
    /// Shifts both smoothed and target offsets so the change is immediate,
    /// then syncs the voice tracker to the word at the new scroll position.
    func manualAdjustWhileVoiceTracking(by delta: CGFloat) {
        guard voiceTrackingActive else { return }
        let adjusted = max(0, voiceSmoothedOffset + delta)
        voiceSmoothedOffset = adjusted
        voiceTargetOffset = adjusted
        scrollOffset = adjusted

        // Find the word index closest to the reading line position
        let readingLineY = adjusted + overlayHeight * 0.5
        if let wordIndex = wordIndexForOffset(readingLineY) {
            currentHighlightWordIndex = wordIndex
            targetHighlightWordIndex = wordIndex
            highlightAdvanceAccumulator = 0
            onManualScroll?(wordIndex)
        }
    }

    /// Reverse lookup: find the word index whose Y offset is closest to (but not past) the given offset.
    private func wordIndexForOffset(_ targetY: CGFloat) -> Int? {
        guard !wordOffsets.isEmpty else { return nil }
        var bestIndex: Int? = nil
        var bestDiff: CGFloat = .greatestFiniteMagnitude
        for (index, y) in wordOffsets {
            let diff = abs(y - targetY)
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = index
            }
        }
        return bestIndex
    }

    deinit {
        stopDisplayLink()
    }
}
