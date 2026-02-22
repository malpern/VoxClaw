import SwiftUI
import VoxClawCore

struct WaitingView: View {
    let settings: SettingsManager
    let coordinator: iOSCoordinator
    let appState: AppState

    @State private var showSettings = false
    @State private var copiedText: String?

    private var listenAddress: String {
        let ip = VoxClawCore.NetworkListener.localIPAddress() ?? "<ip>"
        return "http://\(ip):\(settings.networkListenerPort)"
    }

    private var curlCommand: String {
        "curl -X POST \(listenAddress)/read \\\n  -d '{\"text\": \"Hello world\"}'"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // App logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27))

                Text("VoxClaw")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Status indicator
                statusView

                // Connection info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send text from your Mac:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        copyToClipboard(curlCommand)
                    } label: {
                        HStack {
                            Text(curlCommand)
                                .font(.system(.caption2, design: .monospaced))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: copiedText == curlCommand ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(copiedText == curlCommand ? .green : .secondary)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    if copiedText == curlCommand {
                        Text("Copied!")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    iOSSettingsView(settings: settings, coordinator: coordinator, appState: appState)
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showSettings = false
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if appState.isListening {
            Button {
                copyToClipboard(listenAddress)
            } label: {
                HStack(spacing: 4) {
                    Text(listenAddress)
                        .font(.system(.body, design: .monospaced))
                    Image(systemName: copiedText == listenAddress ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copiedText == listenAddress ? .green : .secondary)
                }
            }
            .buttonStyle(.plain)

            if copiedText == listenAddress {
                Text("Copied!")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
    }

    private var statusColor: Color {
        switch appState.sessionState {
        case .idle:
            return appState.isListening ? .green : .orange
        case .loading:
            return .blue
        case .playing:
            return .blue
        case .paused:
            return .yellow
        case .finished:
            return .green
        }
    }

    private var statusText: String {
        switch appState.sessionState {
        case .idle:
            return appState.isListening ? "Listening for text..." : "Starting listener..."
        case .loading:
            return "Receiving text..."
        case .playing:
            return "Speaking..."
        case .paused:
            return "Paused"
        case .finished:
            return "Finished"
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation {
            copiedText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if copiedText == text {
                    copiedText = nil
                }
            }
        }
    }
}
