import SwiftUI
import Combine

class ScrollController: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var currentLineIndex: Int = 0

    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var settings: AppSettings

    // For smooth manual scrolling
    private var targetOffset: CGFloat = 0
    private var isAnimatingManualScroll: Bool = false

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
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        guard let link = displayLink else { return }
        self.displayLink = link

        let opaqueController = Unmanaged.passUnretained(self).toOpaque()

        CVDisplayLinkSetOutputCallback(link, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, context) -> CVReturn in
            guard let context = context else { return kCVReturnSuccess }
            let controller = Unmanaged<ScrollController>.fromOpaque(context).takeUnretainedValue()

            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - controller.lastFrameTime
            controller.lastFrameTime = currentTime

            DispatchQueue.main.async {
                if controller.isPlaying {
                    controller.scrollOffset += controller.scrollSpeedPointsPerSecond * CGFloat(deltaTime)
                }
            }

            return kCVReturnSuccess
        }, opaqueController)

        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    deinit {
        stopDisplayLink()
    }
}
