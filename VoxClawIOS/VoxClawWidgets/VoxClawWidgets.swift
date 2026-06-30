import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// App Group shared between the app and this extension. The control/widget can't
// play audio from the extension process, so they signal the app (which reads the
// clipboard aloud when it becomes active).
enum WidgetBridge {
    static let appGroup = "group.com.malpern.voxclaw"
    static let pendingReadClipboardKey = "voxclaw.pendingReadClipboard"

    static func requestClipboardRead() {
        UserDefaults(suiteName: appGroup)?.set(Date.now.timeIntervalSince1970, forKey: pendingReadClipboardKey)
    }
}

/// Reads the clipboard aloud. Opens the app (audio can't play from an extension),
/// signalling it via the shared App Group; the app performs the read on activation.
struct ReadClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Clipboard Aloud"
    static let description = IntentDescription("Reads the clipboard aloud with VoxClaw.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WidgetBridge.requestClipboardRead()
        return .result()
    }
}

// MARK: - Control Center control

struct ReadClipboardControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.malpern.voxclaw.readClipboard") {
            ControlWidgetButton(action: ReadClipboardIntent()) {
                Label("Read Clipboard", systemImage: "waveform")
            }
        }
        .displayName("Read Clipboard")
        .description("Read the clipboard aloud with VoxClaw.")
    }
}

// MARK: - Interactive home-screen widget

private struct WidgetEntry: TimelineEntry {
    let date: Date
}

private struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { WidgetEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        completion(Timeline(entries: [WidgetEntry(date: .now)], policy: .never))
    }
}

private struct ReadClipboardWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title2)
            Button(intent: ReadClipboardIntent()) {
                Text("Read Clipboard")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ReadClipboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VoxClawReadClipboardWidget", provider: WidgetProvider()) { _ in
            ReadClipboardWidgetView()
        }
        .configurationDisplayName("Read Clipboard")
        .description("Tap to read the clipboard aloud.")
        .supportedFamilies([.systemSmall])
    }
}

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
        ReadClipboardWidget()
        ReadClipboardControl()
        VoxClawLiveActivity()
    }
}
