import SwiftUI

public struct FeedbackBadge: View {
    public let text: String?

    public init(text: String?) {
        self.text = text
    }

    public var body: some View {
        if let text {
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
                .accessibilityIdentifier(AccessibilityID.Overlay.feedbackBadge)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
