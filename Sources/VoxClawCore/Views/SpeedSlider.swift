import SwiftUI

/// A speed slider (0.5x–3.0x) with a visible "1x" tick mark and snap detent at 1.0.
struct SpeedSlider: View {
    @Binding var speed: Float

    private let min: Float = 0.5
    private let max: Float = 3.0
    private let step: Float = 0.1

    /// Fraction along the track where 1.0 falls (0.0–1.0).
    private var defaultFraction: CGFloat {
        CGFloat((1.0 - min) / (max - min))
    }

    var body: some View {
        VStack(spacing: 0) {
            Slider(value: $speed, in: Float(min)...Float(max), step: step)
                .onChange(of: speed) { _, new in
                    if abs(new - 1.0) < 0.06 && new != 1.0 {
                        speed = 1.0
                    }
                }

            // Tick mark aligned to 1.0 position on the track
            GeometryReader { geo in
                let trackInset: CGFloat = 8 // approximate slider thumb half-width
                let trackWidth = geo.size.width - trackInset * 2
                let xPos = trackInset + trackWidth * defaultFraction

                Text("1x")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .position(x: xPos, y: 6)
            }
            .frame(height: 14)
        }
    }
}
