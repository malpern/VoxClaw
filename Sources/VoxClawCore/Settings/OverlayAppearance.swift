import SwiftUI

/// A Codable color representation bridging to SwiftUI `Color`.
struct CodableColor: Codable, Sendable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(_ color: Color, opacity: Double = 1.0) {
        // Resolve to components via NSColor
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    static let white = CodableColor(red: 1, green: 1, blue: 1)
    static let black = CodableColor(red: 0, green: 0, blue: 0)
    static let yellow = CodableColor(red: 1, green: 1, blue: 0)
}

/// All visual properties for the floating teleprompter overlay.
struct OverlayAppearance: Codable, Sendable, Equatable {
    var fontFamily: String = "Helvetica Neue"
    var fontSize: CGFloat = 28
    var fontWeight: String = "medium"
    var lineSpacing: CGFloat = 6
    var wordSpacing: CGFloat = 6
    var textColor: CodableColor = .white
    var highlightColor: CodableColor = CodableColor(red: 1, green: 1, blue: 0, opacity: 0.35)
    var pastWordOpacity: Double = 0.5
    var futureWordOpacity: Double = 0.9
    var backgroundColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, opacity: 0.85)
    var cornerRadius: CGFloat = 20
    var horizontalPadding: CGFloat = 20
    var verticalPadding: CGFloat = 16
    var panelWidthFraction: Double = 1.0 / 3.0
    var panelHeight: CGFloat = 162

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = OverlayAppearance()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? defaults.fontFamily
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? defaults.fontSize
        fontWeight = try container.decodeIfPresent(String.self, forKey: .fontWeight) ?? defaults.fontWeight
        lineSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .lineSpacing) ?? defaults.lineSpacing
        wordSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .wordSpacing) ?? defaults.wordSpacing
        textColor = try container.decodeIfPresent(CodableColor.self, forKey: .textColor) ?? defaults.textColor
        highlightColor = try container.decodeIfPresent(CodableColor.self, forKey: .highlightColor) ?? defaults.highlightColor
        pastWordOpacity = try container.decodeIfPresent(Double.self, forKey: .pastWordOpacity) ?? defaults.pastWordOpacity
        futureWordOpacity = try container.decodeIfPresent(Double.self, forKey: .futureWordOpacity) ?? defaults.futureWordOpacity
        backgroundColor = try container.decodeIfPresent(CodableColor.self, forKey: .backgroundColor) ?? defaults.backgroundColor
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        horizontalPadding = try container.decodeIfPresent(CGFloat.self, forKey: .horizontalPadding) ?? defaults.horizontalPadding
        verticalPadding = try container.decodeIfPresent(CGFloat.self, forKey: .verticalPadding) ?? defaults.verticalPadding
        panelWidthFraction = try container.decodeIfPresent(Double.self, forKey: .panelWidthFraction) ?? defaults.panelWidthFraction
        panelHeight = try container.decodeIfPresent(CGFloat.self, forKey: .panelHeight) ?? defaults.panelHeight
    }

    var fontWeightValue: Font.Weight {
        switch fontWeight {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .medium
        }
    }

    static func resetToDefaults() -> OverlayAppearance {
        OverlayAppearance()
    }
}
