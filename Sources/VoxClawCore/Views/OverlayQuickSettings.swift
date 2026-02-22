import SwiftUI

public struct OverlayQuickSettings: View {
    @Bindable var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(settings.voiceSpeed, specifier: "%.1f")x")
                    .font(.caption)
                SpeedSlider(speed: speedBinding)
            }

            OverlayPresetGallery(settings: settings, compact: true)
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Bindings

    private var speedBinding: Binding<Float> {
        Binding(
            get: { settings.voiceSpeed },
            set: { settings.voiceSpeed = $0 }
        )
    }
}
