import SwiftUI

struct OverlayAppearanceSettingsView: View {
    @Bindable var settings: SettingsManager

    private let fontFamilies = [
        "Helvetica Neue", "SF Pro", "SF Mono", "Menlo",
        "Avenir", "Georgia", "Futura", "Palatino",
    ]

    private let fontWeights: [(label: String, value: String)] = [
        ("Light", "light"),
        ("Regular", "regular"),
        ("Medium", "medium"),
        ("Semibold", "semibold"),
        ("Bold", "bold"),
    ]

    var body: some View {
        Group {
            Section("Style Presets") {
                OverlayPresetGallery(settings: settings)
            }
            textSection
            colorsSection
            layoutSection

            Button("Reset to Defaults") {
                settings.overlayAppearance = .resetToDefaults()
            }
            .accessibilityIdentifier(AccessibilityID.Appearance.resetButton)
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        Section("Text") {
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

            Picker("Weight", selection: fontWeightBinding) {
                ForEach(fontWeights, id: \.value) { weight in
                    Text(weight.label).tag(weight.value)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Appearance.fontWeightPicker)

            HStack {
                Text("Line Spacing: \(Int(settings.overlayAppearance.lineSpacing))pt")
                Slider(value: lineSpacingBinding, in: 0...20, step: 1)
                    .accessibilityIdentifier(AccessibilityID.Appearance.lineSpacingSlider)
            }

            HStack {
                Text("Word Spacing: \(Int(settings.overlayAppearance.wordSpacing))pt")
                Slider(value: wordSpacingBinding, in: 0...20, step: 1)
                    .accessibilityIdentifier(AccessibilityID.Appearance.wordSpacingSlider)
            }
        }
    }

    // MARK: - Colors Section

    private var colorsSection: some View {
        Section("Colors") {
            ColorPicker("Text Color", selection: textColorBinding)
                .accessibilityIdentifier(AccessibilityID.Appearance.textColorPicker)

            ColorPicker("Highlight Color", selection: highlightColorBinding)
                .accessibilityIdentifier(AccessibilityID.Appearance.highlightColorPicker)

            HStack {
                Text("Past Word Opacity: \(Int(settings.overlayAppearance.pastWordOpacity * 100))%")
                Slider(value: pastOpacityBinding, in: 0.0...1.0, step: 0.05)
                    .accessibilityIdentifier(AccessibilityID.Appearance.pastOpacitySlider)
            }

            HStack {
                Text("Future Word Opacity: \(Int(settings.overlayAppearance.futureWordOpacity * 100))%")
                Slider(value: futureOpacityBinding, in: 0.0...1.0, step: 0.05)
                    .accessibilityIdentifier(AccessibilityID.Appearance.futureOpacitySlider)
            }

            ColorPicker("Background Color", selection: bgColorBinding)
                .accessibilityIdentifier(AccessibilityID.Appearance.bgColorPicker)

            HStack {
                Text("Background Opacity: \(Int(settings.overlayAppearance.backgroundColor.opacity * 100))%")
                Slider(value: bgOpacityBinding, in: 0.1...1.0, step: 0.05)
                    .accessibilityIdentifier(AccessibilityID.Appearance.bgOpacitySlider)
            }
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        Section("Layout") {
            HStack {
                Text("Panel Width: \(Int(settings.overlayAppearance.panelWidthFraction * 100))%")
                Slider(value: panelWidthBinding, in: 0.2...0.8, step: 0.05)
                    .accessibilityIdentifier(AccessibilityID.Appearance.panelWidthSlider)
            }

            HStack {
                Text("Panel Height: \(Int(settings.overlayAppearance.panelHeight))pt")
                Slider(value: panelHeightBinding, in: 100...400, step: 10)
                    .accessibilityIdentifier(AccessibilityID.Appearance.panelHeightSlider)
            }

            HStack {
                Text("H Padding: \(Int(settings.overlayAppearance.horizontalPadding))pt")
                Slider(value: hPaddingBinding, in: 4...40, step: 2)
                    .accessibilityIdentifier(AccessibilityID.Appearance.hPaddingSlider)
            }

            HStack {
                Text("V Padding: \(Int(settings.overlayAppearance.verticalPadding))pt")
                Slider(value: vPaddingBinding, in: 4...40, step: 2)
                    .accessibilityIdentifier(AccessibilityID.Appearance.vPaddingSlider)
            }

            HStack {
                Text("Corner Radius: \(Int(settings.overlayAppearance.cornerRadius))pt")
                Slider(value: cornerRadiusBinding, in: 0...40, step: 2)
                    .accessibilityIdentifier(AccessibilityID.Appearance.cornerRadiusSlider)
            }
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

    private var fontWeightBinding: Binding<String> {
        Binding(
            get: { settings.overlayAppearance.fontWeight },
            set: { settings.overlayAppearance.fontWeight = $0 }
        )
    }

    private var lineSpacingBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.lineSpacing) },
            set: { settings.overlayAppearance.lineSpacing = CGFloat($0) }
        )
    }

    private var wordSpacingBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.wordSpacing) },
            set: { settings.overlayAppearance.wordSpacing = CGFloat($0) }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: settings.overlayAppearance.textColor.red,
                         green: settings.overlayAppearance.textColor.green,
                         blue: settings.overlayAppearance.textColor.blue) },
            set: { newColor in
                let nsColor = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                settings.overlayAppearance.textColor = CodableColor(
                    red: Double(nsColor.redComponent),
                    green: Double(nsColor.greenComponent),
                    blue: Double(nsColor.blueComponent),
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
                let nsColor = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                settings.overlayAppearance.highlightColor = CodableColor(
                    red: Double(nsColor.redComponent),
                    green: Double(nsColor.greenComponent),
                    blue: Double(nsColor.blueComponent),
                    opacity: settings.overlayAppearance.highlightColor.opacity
                )
            }
        )
    }

    private var pastOpacityBinding: Binding<Double> {
        Binding(
            get: { settings.overlayAppearance.pastWordOpacity },
            set: { settings.overlayAppearance.pastWordOpacity = $0 }
        )
    }

    private var futureOpacityBinding: Binding<Double> {
        Binding(
            get: { settings.overlayAppearance.futureWordOpacity },
            set: { settings.overlayAppearance.futureWordOpacity = $0 }
        )
    }

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: settings.overlayAppearance.backgroundColor.red,
                         green: settings.overlayAppearance.backgroundColor.green,
                         blue: settings.overlayAppearance.backgroundColor.blue) },
            set: { newColor in
                let nsColor = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                settings.overlayAppearance.backgroundColor = CodableColor(
                    red: Double(nsColor.redComponent),
                    green: Double(nsColor.greenComponent),
                    blue: Double(nsColor.blueComponent),
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

    private var panelWidthBinding: Binding<Double> {
        Binding(
            get: { settings.overlayAppearance.panelWidthFraction },
            set: { settings.overlayAppearance.panelWidthFraction = $0 }
        )
    }

    private var panelHeightBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.panelHeight) },
            set: { settings.overlayAppearance.panelHeight = CGFloat($0) }
        )
    }

    private var hPaddingBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.horizontalPadding) },
            set: { settings.overlayAppearance.horizontalPadding = CGFloat($0) }
        )
    }

    private var vPaddingBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.verticalPadding) },
            set: { settings.overlayAppearance.verticalPadding = CGFloat($0) }
        )
    }

    private var cornerRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(settings.overlayAppearance.cornerRadius) },
            set: { settings.overlayAppearance.cornerRadius = CGFloat($0) }
        )
    }
}
