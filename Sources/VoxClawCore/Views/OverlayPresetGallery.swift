import SwiftUI

/// Horizontal scrolling gallery of overlay style presets.
///
/// Use `compact: true` for the narrow quick-settings popover.
public struct OverlayPresetGallery: View {
    @Bindable var settings: SettingsManager
    var compact: Bool = false

    public init(settings: SettingsManager, compact: Bool = false) {
        self.settings = settings
        self.compact = compact
    }

    private var cardWidth: CGFloat { compact ? 91 : 100 }
    private var cardHeight: CGFloat { compact ? 65 : 70 }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OverlayPreset.all) { preset in
                    presetCard(preset)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Card

    private func presetCard(_ preset: OverlayPreset) -> some View {
        let isSelected = settings.overlayAppearance == preset.appearance
        let appearance = preset.appearance

        return Button {
            settings.overlayAppearance = preset.appearance
        } label: {
            VStack(spacing: compact ? 2 : 4) {
                // Mini preview
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(appearance.backgroundColor.color)

                    Text("The quick brown")
                        .font(.custom(appearance.fontFamily, size: compact ? 9 : 9))
                        .fontWeight(appearance.fontWeightValue)
                        .foregroundStyle(appearance.textColor.color)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                .frame(width: cardWidth, height: cardHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )

                // Name
                Text(preset.name)
                    .font(compact ? .system(size: 11) : .caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.PresetGallery.card(preset.id))
    }
}
