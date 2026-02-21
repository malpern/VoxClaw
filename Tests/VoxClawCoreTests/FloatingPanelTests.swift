import AppKit
@testable import VoxClawCore
import Testing

@Suite(.serialized) @MainActor
struct FloatingPanelTests {
    @Test func panelAllowsMouseInteractionForOverlayControls() {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 120))
        #expect(panel.ignoresMouseEvents == false)
    }
}
