import AppKit

/// Moves the mouse pointer, for the "screen center" wheel position.
enum CursorController {
    /// Converts an AppKit screen point (origin bottom-left of the main display) to a
    /// Quartz point (origin top-left of the main display).
    static func quartzPoint(from point: NSPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    static func warp(to point: NSPoint) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(quartzPoint(from: point, primaryScreenHeight: primaryHeight))
        // Without this, macOS ignores real mouse movement for a moment after a warp.
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }
}
