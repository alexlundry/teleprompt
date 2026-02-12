import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("fontSize") var fontSize: Double = 32
    @AppStorage("fontName") var fontName: String = "SF Pro"
    @AppStorage("textColor") var textColorHex: String = "#FFFFFF"
    @AppStorage("backgroundColor") var backgroundColorHex: String = "#000000"
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 0.85
    @AppStorage("scrollSpeed") var scrollSpeed: Double = 60 // words per minute
    @AppStorage("lineSpacing") var lineSpacing: Double = 12
    @AppStorage("horizontalPadding") var horizontalPadding: Double = 40
    @AppStorage("overlayWidth") var overlayWidth: Double = 800
    @AppStorage("overlayHeight") var overlayHeight: Double = 200
    @AppStorage("highlightCurrentLine") var highlightCurrentLine: Bool = true
    @AppStorage("mirrorText") var mirrorText: Bool = false
    @AppStorage("voiceTrackingEnabled") var voiceTrackingEnabled: Bool = false

    var textColor: Color {
        get { Color(hex: textColorHex) ?? .white }
        set { textColorHex = newValue.toHex() ?? "#FFFFFF" }
    }

    var backgroundColor: Color {
        get { Color(hex: backgroundColorHex) ?? .black }
        set { backgroundColorHex = newValue.toHex() ?? "#000000" }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
