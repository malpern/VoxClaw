import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity ("Now reading…")

struct VoxClawLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoxClawActivityAttributes.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.snippet)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.5))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.snippet).font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                ProgressView(value: context.state.progress).progressViewStyle(.circular)
            } minimal: {
                Image(systemName: "waveform")
            }
        }
    }
}

// MARK: - Bundle

@main
struct VoxClawWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoxClawLiveActivity()
    }
}
