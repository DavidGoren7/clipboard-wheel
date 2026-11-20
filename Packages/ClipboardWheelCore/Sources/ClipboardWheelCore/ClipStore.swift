import Foundation

/// The wheel's items and the rules for adding, pinning and overwriting them.
///
/// `items` is in slot order: index 0 is the top slice, then clockwise. A new copy is
/// appended until the wheel is full; after that it replaces the least recently used
/// unpinned item *in that item's slot*, so every other item stays where it was.
public struct ClipStore: Codable, Equatable, Sendable {
    public static let maxItemsRange: ClosedRange<Int> = 2...12
    public static let defaultMaxItems = 8

    public private(set) var items: [ClipItem]
    public private(set) var maxItems: Int
    public private(set) var mode: WheelMode

    public init(items: [ClipItem] = [], maxItems: Int = ClipStore.defaultMaxItems, mode: WheelMode = .historyAndPinned) {
        self.items = items
        self.mode = mode
        self.maxItems = ClipStore.maxItemsRange.clamped(maxItems)
        _ = enforceCapacity()
    }

    // MARK: - Reading

    /// The items the wheel shows right now, in slot order.
    public var visibleItems: [ClipItem] {
        switch mode {
        case .historyAndPinned: items
        case .historyOnly: items.filter { !$0.pinned }
        case .pinnedOnly: items.filter(\.pinned)
        }
    }

    public var pinnedCount: Int { items.lazy.filter(\.pinned).count }
    public var unpinnedCount: Int { items.count - pinnedCount }

    /// Whether right-click pinning is available in the current mode.
    public var canPin: Bool { mode != .historyOnly }

    /// How many unpinned (history) items the wheel has room for.
    public var historyCapacity: Int {
        switch mode {
        case .historyAndPinned: max(0, maxItems - pinnedCount)
        case .historyOnly: maxItems
        case .pinnedOnly: 0
        }
    }

    /// The smallest max the user may pick: never below the pin count.
    public var minimumAllowedMax: Int { Swift.max(ClipStore.maxItemsRange.lowerBound, pinnedCount) }

    /// Image files still referenced by some item. Anything else in the images folder can be deleted.
    public var referencedImageFiles: Set<String> { Set(items.compactMap(\.content.imageFileName)) }

    public func item(id: UUID) -> ClipItem? { items.first { $0.id == id } }

    // MARK: - Recording copies

    public enum RecordResult: Equatable, Sendable {
        /// A new slot was added at the end of the wheel.
        case added(ClipItem)
        /// The content was already on the wheel; its last-used time was refreshed.
        case refreshed(ClipItem)
        /// The wheel was full; `evicted` was overwritten in place by `item`.
        case replaced(evicted: ClipItem, item: ClipItem)
        /// The wheel is full of pinned items, so the copy stays off the wheel.
        case noRoom
        /// The current mode doesn't record copies (pinned only).
        case ignored
    }

    /// Records something the user copied.
    @discardableResult
    public mutating func record(_ content: ClipContent, at date: Date = Date()) -> RecordResult {
        if let index = items.firstIndex(where: { $0.content == content }) {
            items[index].lastUsed = date
            return .refreshed(items[index])
        }
        guard mode != .pinnedOnly else { return .ignored }

        let item = ClipItem(content: content, lastUsed: date)
        if unpinnedCount < historyCapacity {
            items.append(item)
            return .added(item)
        }
        guard let index = leastRecentlyUsedUnpinnedIndex() else { return .noRoom }
        let evicted = items[index]
        items[index] = item
        return .replaced(evicted: evicted, item: item)
    }

    /// Marks an item as just used (pasted from the wheel), so it's the last to be overwritten.
    public mutating func markUsed(_ id: UUID, at date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].lastUsed = date
    }

    // MARK: - Pinning

    /// Pins or unpins an item on the wheel. Returns the new pinned state, or nil if the
    /// item doesn't exist or pinning is off in this mode.
    @discardableResult
    public mutating func togglePin(_ id: UUID) -> Bool? {
        guard canPin, let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        if !items[index].pinned && pinnedCount >= maxItems { return nil }
        items[index].pinned.toggle()
        return items[index].pinned
    }

    public enum PinResult: Equatable, Sendable {
        /// Pinned an item that was already stored.
        case pinnedExisting(ClipItem)
        /// Added a new pinned slot at the end of the wheel.
        case added(ClipItem)
        /// The wheel was full; `evicted` was overwritten in place by the new pinned item.
        case replaced(evicted: ClipItem, item: ClipItem)
        /// Every slot is already pinned.
        case noRoom
        /// Pinning is off in this mode (history only).
        case ignored
    }

    /// Pins arbitrary content (the menu bar's "Pin current clipboard").
    @discardableResult
    public mutating func pin(_ content: ClipContent, at date: Date = Date()) -> PinResult {
        guard canPin else { return .ignored }
        if let index = items.firstIndex(where: { $0.content == content }) {
            if !items[index].pinned {
                guard pinnedCount < maxItems else { return .noRoom }
                items[index].pinned = true
            }
            items[index].lastUsed = date
            return .pinnedExisting(items[index])
        }
        guard pinnedCount < maxItems else { return .noRoom }

        let item = ClipItem(content: content, pinned: true, lastUsed: date)
        let slotsUsed = mode == .pinnedOnly ? pinnedCount : items.count
        if slotsUsed < maxItems {
            items.append(item)
            return .added(item)
        }
        guard let index = leastRecentlyUsedUnpinnedIndex() else { return .noRoom }
        let evicted = items[index]
        items[index] = item
        return .replaced(evicted: evicted, item: item)
    }

    // MARK: - Removing and settings

    @discardableResult
    public mutating func remove(_ id: UUID) -> ClipItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    /// Removes every unpinned item. Returns what was removed.
    @discardableResult
    public mutating func clearHistory() -> [ClipItem] {
        let removed = items.filter { !$0.pinned }
        items.removeAll { !$0.pinned }
        return removed
    }

    /// Changes the max slice count (clamped to the allowed range and never below the pin
    /// count). Returns the items removed to fit.
    @discardableResult
    public mutating func setMaxItems(_ newValue: Int) -> [ClipItem] {
        maxItems = Swift.min(ClipStore.maxItemsRange.upperBound, Swift.max(minimumAllowedMax, newValue))
        return enforceCapacity()
    }

    /// Changes which items the wheel shows. Returns the items removed to fit.
    @discardableResult
    public mutating func setMode(_ newValue: WheelMode) -> [ClipItem] {
        mode = newValue
        return enforceCapacity()
    }

    // MARK: - Private

    private func leastRecentlyUsedUnpinnedIndex() -> Int? {
        items.indices
            .filter { !items[$0].pinned }
            .min { items[$0].lastUsed < items[$1].lastUsed }
    }

    /// Drops least recently used history until it fits. In pinned-only mode history is
    /// hidden rather than trimmed, so switching back doesn't lose it.
    private mutating func enforceCapacity() -> [ClipItem] {
        guard mode != .pinnedOnly else { return [] }
        var removed: [ClipItem] = []
        while unpinnedCount > historyCapacity, let index = leastRecentlyUsedUnpinnedIndex() {
            removed.append(items.remove(at: index))
        }
        return removed
    }
}

extension ClosedRange where Bound: Comparable {
    func clamped(_ value: Bound) -> Bound { Swift.min(upperBound, Swift.max(lowerBound, value)) }
}
