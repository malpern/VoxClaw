@testable import VoxClawCore
import Foundation
import Testing

struct OverlayAppearanceTests {
    @Test func roundtripEncodingPreservesAllValues() throws {
        var appearance = OverlayAppearance()
        appearance.fontFamily = "SF Mono"
        appearance.fontSize = 36
        appearance.fontWeight = "bold"
        appearance.lineHeightMultiplier = 1.5
        appearance.wordSpacing = 8
        appearance.textColor = CodableColor(red: 0.5, green: 0.6, blue: 0.7, opacity: 0.8)
        appearance.highlightColor = CodableColor(red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4)
        appearance.pastWordOpacity = 0.3
        appearance.futureWordOpacity = 0.7
        appearance.backgroundColor = CodableColor(red: 0.2, green: 0.2, blue: 0.2, opacity: 0.9)
        appearance.cornerRadius = 12
        appearance.horizontalPadding = 24
        appearance.verticalPadding = 20
        appearance.panelWidthFraction = 0.5
        appearance.panelHeight = 200

        let data = try JSONEncoder().encode(appearance)
        let decoded = try JSONDecoder().decode(OverlayAppearance.self, from: data)

        #expect(decoded == appearance)
    }

    @Test func defaultValuesMatchHardCodedAppearance() {
        let appearance = OverlayAppearance()

        #expect(appearance.fontFamily == "Helvetica Neue")
        #expect(appearance.fontSize == 28)
        #expect(appearance.fontWeight == "medium")
        #expect(appearance.lineHeightMultiplier == 1.2)
        #expect(appearance.wordSpacing == 2)
        #expect(appearance.textColor == .white)
        #expect(appearance.highlightColor == CodableColor(red: 1, green: 1, blue: 0, opacity: 0.35))
        #expect(appearance.pastWordOpacity == 0.5)
        #expect(appearance.futureWordOpacity == 0.9)
        #expect(appearance.backgroundColor == CodableColor(red: 0, green: 0, blue: 0, opacity: 0.85))
        #expect(appearance.cornerRadius == 20)
        #expect(appearance.horizontalPadding == 20)
        #expect(appearance.verticalPadding == 16)
        #expect(appearance.panelHeight == 162)
    }

    @Test func resetToDefaultsReturnsDefaultValues() {
        var appearance = OverlayAppearance()
        appearance.fontSize = 50
        appearance.cornerRadius = 0

        let reset = OverlayAppearance.resetToDefaults()
        #expect(reset.fontSize == 28)
        #expect(reset.cornerRadius == 20)
    }

    @Test func fontWeightValueMapsCorrectly() {
        var appearance = OverlayAppearance()

        appearance.fontWeight = "light"
        #expect(appearance.fontWeightValue == .light)

        appearance.fontWeight = "regular"
        #expect(appearance.fontWeightValue == .regular)

        appearance.fontWeight = "medium"
        #expect(appearance.fontWeightValue == .medium)

        appearance.fontWeight = "semibold"
        #expect(appearance.fontWeightValue == .semibold)

        appearance.fontWeight = "bold"
        #expect(appearance.fontWeightValue == .bold)

        appearance.fontWeight = "unknown"
        #expect(appearance.fontWeightValue == .medium)
    }

    @Test func codableColorEquality() {
        let a = CodableColor(red: 1, green: 0, blue: 0, opacity: 1)
        let b = CodableColor(red: 1, green: 0, blue: 0, opacity: 1)
        let c = CodableColor(red: 0, green: 1, blue: 0, opacity: 1)

        #expect(a == b)
        #expect(a != c)
    }

    @Test func partialJSONDecodesWithDefaults() throws {
        // Simulate a stored JSON that only has a subset of keys (forward-compat)
        let json = """
        {"fontFamily":"SF Pro","fontSize":32}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(OverlayAppearance.self, from: data)

        #expect(decoded.fontFamily == "SF Pro")
        #expect(decoded.fontSize == 32)
        // Other fields get their defaults
        #expect(decoded.cornerRadius == 20)
        #expect(decoded.pastWordOpacity == 0.5)
    }
}
