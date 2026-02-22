import SwiftUI

public struct OverlayAppearanceSettingsView: View {
    @Bindable var settings: SettingsManager
    @State private var showCustomOptions = false

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    private let fontFamilies = [
        "Helvetica Neue", "SF Pro", "SF Mono", "Menlo",
        "Avenir", "Georgia", "Futura", "Palatino",
    ]

    public var body: some View {
        Group {
            Section("Style Presets") {
                OverlayPresetGallery(settings: settings)
            }

            DisclosureGroup(isExpanded: $showCustomOptions, content: {
                Section {
                    Picker("Font", selection: fontFamilyBinding) {
                        ForEach(fontFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Appearance.fontPicker)

                    HStack {
                        Text("Size: \(Int(settings.overlayAppearance.fontSize))pt")
                        Slider(value: fontSizeBinding, in: 16...64, step: 1)
                            .accessibilityIdentifier(AccessibilityID.Appearance.fontSizeSlider)
                    }

                    HStack {
                        Text("Line Height: \(String(format: "%.1f", settings.overlayAppearance.lineHeightMultiplier))x")
                        Slider(value: lineHeightBinding, in: 1.0...2.5, step: 0.1)
                            .accessibilityIdentifier(AccessibilityID.Appearance.lineSpacingSlider)
                    }

                    HStack {
                        Text("Padding: \(Int(settings.overlayAppearance.horizontalPadding))pt")
                        Slider(value: paddingBinding, in: 0...60, step: 2)
                            .accessibilityIdentifier(AccessibilityID.Appearance.hPaddingSlider)
                    }

                    ColorPicker("Text Color", selection: textColorBinding)
                        .accessibilityIdentifier(AccessibilityID.Appearance.textColorPicker)

                    ColorPicker("Highlight Color", selection: highlightColorBinding)
                        .accessibilityIdentifier(AccessibilityID.Appearance.highlightColorPicker)

                    ColorPicker("Background", selection: bgColorBinding)
                        .accessibilityIdentifier(AccessibilityID.Appearance.bgColorPicker)

                    HStack {
                        Text("Background Opacity: \(Int(settings.overlayAppearance.backgroundColor.opacity * 100))%")
                        Slider(value: bgOpacityBinding, in: 0.1...1.0, step: 0.05)
                            .accessibilityIdentifier(AccessibilityID.Appearance.bgOpacitySlider)
                    }
                }

                Button("Reset to Defaults") {
                    settings.overlayAppearance = .resetToDefaults()
                }
                .accessibilityIdentifier(AccessibilityID.Appearance.resetButton)
            }, label: {
                Button {
                    withAnimation { showCustomOptions.toggle() }
                } label: {
                    Text("Customize")
                }
                .buttonStyle(.plain)
            })
        }
    }

    // MARK: - Bindings

    private var fontFamilyBinding: Binding<String> {
        Binding(
            get: { settings.overlayAppearance.fontFamily },
            set: { settings.overlayAppearance.fontFamily = $0 }
        )
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.fontSize) },
            set: { settings.overlayAppearance.fontSize = CGFloat($0) }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.lineHeightMultiplier) },
            set: { settings.overlayAppearance.lineHeightMultiplier = CGFloat($0) }
        )
    }

    private var paddingBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.horizontalPadding) },
            set: {
                settings.overlayAppearance.horizontalPadding = CGFloat($0)
                settings.overlayAppearance.verticalPadding = CGFloat($0)
            }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: settings.overlayAppearance.textColor.red,
                         green: settings.overlayAppearance.textColor.green,
                         blue: settings.overlayAppearance.textColor.blue) },
            set: { newColor in
                let resolved = CodableColor(newColor)
                settings.overlayAppearance.textColor = CodableColor(
                    red: resolved.red,
                    green: resolved.green,
                    blue: resolved.blue,
                    opacity: settings.overlayAppearance.textColor.opacity
                )
            }
        )
    }

    private var highlightColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: settings.overlayAppearance.highlightColor.red,
                         green: settings.overlayAppearance.highlightColor.green,
                         blue: settings.overlayAppearance.highlightColor.blue) },
            set: { newColor in
                let resolved = CodableColor(newColor)
                settings.overlayAppearance.highlightColor = CodableColor(
                    red: resolved.red,
                    green: resolved.green,
                    blue: resolved.blue,
                    opacity: settings.overlayAppearance.highlightColor.opacity
                )
            }
        )
    }

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: settings.overlayAppearance.backgroundColor.red,
                         green: settings.overlayAppearance.backgroundColor.green,
                         blue: settings.overlayAppearance.backgroundColor.blue) },
            set: { newColor in
                let resolved = CodableColor(newColor)
                settings.overlayAppearance.backgroundColor = CodableColor(
                    red: resolved.red,
                    green: resolved.green,
                    blue: resolved.blue,
                    opacity: settings.overlayAppearance.backgroundColor.opacity
                )
            }
        )
    }

    private var bgOpacityBinding: Binding<Double> {
        Binding(
            get: { settings.overlayAppearance.backgroundColor.opacity },
            set: { settings.overlayAppearance.backgroundColor.opacity = $0 }
        )
    }
}
