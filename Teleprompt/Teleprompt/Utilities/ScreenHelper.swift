import AppKit

struct ScreenHelper {
    /// Returns the height of the notch area (menu bar + notch) on the main screen
    static func getNotchHeight() -> CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        // The notch/menu bar height is the difference between full height and visible height
        // plus the y-offset of the visible frame
        return fullFrame.height - visibleFrame.height - visibleFrame.origin.y + visibleFrame.origin.y
    }

    /// Returns the safe area insets for the main screen
    static func getSafeAreaInsets() -> NSEdgeInsets {
        guard let screen = NSScreen.main else {
            return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }

        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        return NSEdgeInsets(
            top: fullFrame.maxY - visibleFrame.maxY,
            left: visibleFrame.minX - fullFrame.minX,
            bottom: visibleFrame.minY - fullFrame.minY,
            right: fullFrame.maxX - visibleFrame.maxX
        )
    }

    /// Calculates the ideal frame for the overlay window, positioned just below the notch
    static func calculateOverlayFrame(width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: width, height: height)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Position at top center, just below the menu bar/notch area
        let x = screenFrame.midX - (width / 2)
        let y = visibleFrame.maxY - height

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Checks if the current Mac has a notch
    static var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        if let auxiliaryTopLeftArea = screen.auxiliaryTopLeftArea,
           let auxiliaryTopRightArea = screen.auxiliaryTopRightArea {
            // If both auxiliary areas exist, there's a notch between them
            return auxiliaryTopLeftArea.width > 0 && auxiliaryTopRightArea.width > 0
        }
        return false
    }
}
