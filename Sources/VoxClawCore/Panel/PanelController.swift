import AppKit
import os
import SwiftUI

@MainActor
final class PanelController {
    private var panel: FloatingPanel?
    private let appState: AppState
    private let settings: SettingsManager
    private let onTogglePause: () -> Void
    private var quickSettingsWindow: NSWindow?

    init(appState: AppState, settings: SettingsManager, onTogglePause: @escaping () -> Void) {
        self.appState = appState
        self.settings = settings
        self.onTogglePause = onTogglePause
    }

    func show() {
        guard let screen = NSScreen.main else {
            Log.panel.error("No main screen available")
            return
        }

        let appearance = settings.overlayAppearance
        let screenFrame = screen.visibleFrame
        let panelWidth = screenFrame.width * appearance.panelWidthFraction
        let panelHeight = appearance.panelHeight
        let cornerRadius = appearance.cornerRadius
        let topPadding: CGFloat = 8

        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.maxY - panelHeight - topPadding

        let contentRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        let panel = FloatingPanel(contentRect: contentRect)

        let hostingView = NSHostingView(rootView:
            FloatingPanelView(
                appState: appState,
                appearance: appearance,
                onTogglePause: onTogglePause,
                onOpenSettings: { [weak self] in
                    self?.showQuickSettings()
                }
            )
            .frame(width: panelWidth, height: panelHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        panel.contentView = hostingView

        // Start off-screen for slide-down animation
        let startY = panelY + panelHeight + 20
        panel.setFrameOrigin(NSPoint(x: panelX, y: startY))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // Slide down + fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: panelX, y: panelY))
            panel.animator().alphaValue = 1
        }

        Log.panel.info("Panel shown: \(Int(panelWidth), privacy: .public)x\(Int(panelHeight), privacy: .public) at (\(Int(panelX), privacy: .public), \(Int(panelY), privacy: .public))")
        self.panel = panel
    }

    func dismiss() {
        Log.panel.info("Panel dismissed")
        quickSettingsWindow?.close()
        quickSettingsWindow = nil
        guard let panel else { return }

        let frame = panel.frame
        let targetY = frame.origin.y + frame.height + 20

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: frame.origin.x, y: targetY))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.panel?.close()
                self?.panel = nil
            }
        })
    }

    private func showQuickSettings() {
        if let existing = quickSettingsWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = OverlayQuickSettings(settings: settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.level = .floating
        window.isReleasedWhenClosed = false

        // Position near the panel
        if let panel {
            let panelFrame = panel.frame
            let x = panelFrame.maxX + 8
            let y = panelFrame.midY - 170
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        quickSettingsWindow = window
    }
}
