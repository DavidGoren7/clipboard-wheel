import AppKit
import ClipboardWheelCore

/// Shows and hides the wheel, tracks which slice the mouse points at, and plays the tick.
final class WheelController {
    static let outerRadius: CGFloat = 150
    static let deadZoneRadius: CGFloat = 44

    private let clipboard: ClipboardModel
    private let settings: SettingsStore
    private let viewModel = WheelViewModel()
    private let feedback = WheelFeedback()
    private lazy var panel = WheelPanel(viewModel: viewModel, imageProvider: { [clipboard] in clipboard.image(named: $0) })

    private var center: NSPoint = .zero
    private var restoreCursorTo: NSPoint?
    private var trackingTimer: Timer?
    private var demoCloseTask: Task<Void, Never>?
    private(set) var isOpen = false

    init(clipboard: ClipboardModel, settings: SettingsStore) {
        self.clipboard = clipboard
        self.settings = settings
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true

        let mouse = NSEvent.mouseLocation
        let screenFrame = CursorController.screen(containing: mouse)?.frame
            ?? NSRect(origin: .zero, size: CGSize(width: 1440, height: 900))
        switch settings.wheelPosition {
        case .cursor:
            // Keep the whole wheel on screen near the edges.
            center = Self.clamp(mouse, to: screenFrame.insetBy(dx: Self.outerRadius + 8, dy: Self.outerRadius + 8))
        case .screenCenter:
            center = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        }
        if center != mouse {
            // Snap the mouse to the wheel's center, and put it back when the wheel closes.
            restoreCursorTo = mouse
            CursorController.warp(to: center)
        } else {
            restoreCursorTo = nil
        }

        viewModel.items = clipboard.store.visibleItems
        viewModel.canPin = clipboard.store.canPin
        viewModel.hoveredIndex = nil
        panel.show(centeredAt: center)
        viewModel.isPresented = true
        startTracking()
    }

    /// Closes the wheel. When `commit` is true, returns the item under the mouse (nil if
    /// the mouse is in the middle).
    func close(commit: Bool) -> ClipItem? {
        guard isOpen else { return nil }
        updateHover(playFeedback: false)
        let selected = commit ? viewModel.hoveredIndex.flatMap { viewModel.items[safe: $0] } : nil

        isOpen = false
        demoCloseTask?.cancel()
        trackingTimer?.invalidate()
        trackingTimer = nil
        viewModel.isPresented = false
        panel.hide()
        if let restoreCursorTo {
            CursorController.warp(to: restoreCursorTo)
            self.restoreCursorTo = nil
        }
        return selected
    }

    func togglePinOnHoveredSlice() {
        guard isOpen, let index = viewModel.hoveredIndex, let item = viewModel.items[safe: index] else { return }
        guard clipboard.togglePin(item.id) != nil else {
            NSSound.beep()
            return
        }
        viewModel.items = clipboard.store.visibleItems
        if let hovered = viewModel.hoveredIndex, hovered >= viewModel.items.count {
            viewModel.hoveredIndex = nil
        }
        feedback.tick(sound: settings.soundEnabled, haptic: settings.hapticEnabled)
    }

    /// Opens the wheel for a few seconds without the hotkey (for screenshots):
    /// launch with `--show-wheel`.
    func showDemo() {
        open()
        if viewModel.items.isEmpty {
            viewModel.items = WheelViewModel.sampleItems
        }
        demoCloseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            _ = self?.close(commit: false)
        }
    }

    // MARK: - Mouse tracking

    private func startTracking() {
        trackingTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover(playFeedback: true) }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    private func updateHover(playFeedback: Bool) {
        let mouse = NSEvent.mouseLocation
        let geometry = WheelGeometry(sliceCount: viewModel.items.count, deadZoneRadius: Self.deadZoneRadius)
        let index = geometry.sliceIndex(dx: mouse.x - center.x, dy: mouse.y - center.y)
        guard index != viewModel.hoveredIndex else { return }
        viewModel.hoveredIndex = index
        if playFeedback, index != nil {
            feedback.tick(sound: settings.soundEnabled, haptic: settings.hapticEnabled)
        }
    }

    static func clamp(_ point: NSPoint, to rect: NSRect) -> NSPoint {
        guard rect.width > 0, rect.height > 0 else { return point }
        return NSPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
