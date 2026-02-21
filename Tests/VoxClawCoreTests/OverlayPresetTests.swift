@testable import VoxClawCore
import Testing

struct OverlayPresetTests {
    @Test func allPresetsHaveUniqueIDs() {
        let ids = OverlayPreset.all.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate preset IDs found")
    }

    @Test func allPresetsHaveNonEmptyNames() {
        for preset in OverlayPreset.all {
            #expect(!preset.name.isEmpty, "Preset \(preset.id) has an empty name")
        }
    }

    @Test func presetCountIsExactlyTen() {
        #expect(OverlayPreset.all.count == 10)
    }

    @Test func classicPresetMatchesDefaults() {
        let classic = OverlayPreset.all.first { $0.id == "classic" }
        #expect(classic != nil, "Classic preset must exist")
        #expect(classic?.appearance == OverlayAppearance())
    }

    @Test func allPresetsHaveValidFontSize() {
        for preset in OverlayPreset.all {
            #expect(
                preset.appearance.fontSize >= 16 && preset.appearance.fontSize <= 64,
                "Preset \(preset.id) has out-of-range fontSize: \(preset.appearance.fontSize)"
            )
        }
    }

    @Test func allPresetsHaveValidOpacities() {
        for preset in OverlayPreset.all {
            let a = preset.appearance
            #expect(
                a.highlightColor.opacity >= 0 && a.highlightColor.opacity <= 1,
                "Preset \(preset.id) has invalid highlight opacity"
            )
            #expect(
                a.backgroundColor.opacity >= 0 && a.backgroundColor.opacity <= 1,
                "Preset \(preset.id) has invalid background opacity"
            )
            #expect(
                a.pastWordOpacity >= 0 && a.pastWordOpacity <= 1,
                "Preset \(preset.id) has invalid pastWordOpacity"
            )
            #expect(
                a.futureWordOpacity >= 0 && a.futureWordOpacity <= 1,
                "Preset \(preset.id) has invalid futureWordOpacity"
            )
        }
    }

    @Test func allPresetsHaveValidColorComponents() {
        for preset in OverlayPreset.all {
            let a = preset.appearance
            for (label, color) in [
                ("textColor", a.textColor),
                ("highlightColor", a.highlightColor),
                ("backgroundColor", a.backgroundColor),
            ] {
                #expect(
                    color.red >= 0 && color.red <= 1
                        && color.green >= 0 && color.green <= 1
                        && color.blue >= 0 && color.blue <= 1,
                    "Preset \(preset.id) has invalid \(label) RGB components"
                )
            }
        }
    }
}
