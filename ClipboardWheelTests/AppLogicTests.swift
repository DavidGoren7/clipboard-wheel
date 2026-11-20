import AppKit
import Carbon.HIToolbox
import Testing
@testable import ClipboardWheel

@Suite("Choosing what a copy is")
struct ClipboardKindTests {
    private let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    private let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    @Test func plainTextIsText() {
        #expect(ClipboardMonitor.preferredKind(for: [.string]) == .text)
    }

    @Test func imageFirstIsImage() {
        #expect(ClipboardMonitor.preferredKind(for: [.tiff, .string]) == .image)
        #expect(ClipboardMonitor.preferredKind(for: [jpeg]) == .image)
    }

    @Test func textFirstWithPictureIsText() {
        // Word and similar apps add a picture of copied text after the text itself.
        #expect(ClipboardMonitor.preferredKind(for: [.rtf, .string, .png]) == .text)
    }

    @Test func passwordManagerCopiesAreSkipped() {
        #expect(ClipboardMonitor.preferredKind(for: [.string, concealed]) == nil)
    }

    @Test func finderFilesAreSkipped() {
        #expect(ClipboardMonitor.preferredKind(for: [.fileURL, .string, .tiff]) == nil)
    }

    @Test func unknownTypesAreSkipped() {
        #expect(ClipboardMonitor.preferredKind(for: [.rtf]) == nil)
        #expect(ClipboardMonitor.preferredKind(for: []) == nil)
    }
}

@Suite("Screen and key helpers")
struct HelperTests {
    @Test func appKitToQuartzFlipsY() {
        let point = CursorController.quartzPoint(from: NSPoint(x: 100, y: 200), primaryScreenHeight: 900)
        #expect(point == CGPoint(x: 100, y: 700))
    }

    @Test func clampKeepsWheelOnScreen() {
        let rect = NSRect(x: 158, y: 158, width: 1000, height: 600)
        #expect(WheelController.clamp(NSPoint(x: 10, y: 10), to: rect) == NSPoint(x: 158, y: 158))
        #expect(WheelController.clamp(NSPoint(x: 500, y: 400), to: rect) == NSPoint(x: 500, y: 400))
    }

    @Test func keyCodesMapToGestureKeys() {
        #expect(HotkeyInterceptor.key(forKeyCode: Int64(kVK_ANSI_V)) == .v)
        #expect(HotkeyInterceptor.key(forKeyCode: Int64(kVK_Escape)) == .escape)
        #expect(HotkeyInterceptor.key(forKeyCode: Int64(kVK_ANSI_C)) == .other)
    }

    @Test func demoWheelHasSampleItems() {
        #expect(WheelViewModel.sampleItems.count == 5)
    }
}
