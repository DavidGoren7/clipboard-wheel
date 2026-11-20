import AppKit
import SwiftUI

/// The see-through floating window the wheel draws in. It never takes keyboard focus
/// and ignores clicks, so the app you're pasting into stays in front.
final class WheelPanel: NSPanel {
    static let side: CGFloat = WheelController.outerRadius * 2 + 40

    init(viewModel: WheelViewModel, imageProvider: @escaping (String) -> NSImage?) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.side, height: Self.side),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        let hosting = NSHostingView(rootView: WheelView(model: viewModel, imageProvider: imageProvider))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.side, height: Self.side)
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(centeredAt point: NSPoint) {
        setFrameOrigin(NSPoint(x: point.x - Self.side / 2, y: point.y - Self.side / 2))
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}
