import Foundation
import Testing
@testable import ClipboardWheelCore

/// Dates one second apart, so last-used ordering is explicit in each test.
private func t(_ seconds: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(1_000_000 + seconds)) }

private func texts(_ items: [ClipItem]) -> [String] { items.compactMap(\.content.text) }

@Suite("Recording copies")
struct RecordingTests {
    @Test func wheelGrowsOneSlicePerCopy() {
        var store = ClipStore(maxItems: 4)
        for (i, word) in ["a", "b", "c"].enumerated() {
            store.record(.text(word), at: t(i))
        }
        #expect(texts(store.visibleItems) == ["a", "b", "c"])
    }

    @Test func fullWheelOverwritesLeastRecentlyUsedInPlace() {
        var store = ClipStore(maxItems: 3)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.record(.text("c"), at: t(2))
        store.markUsed(store.items[0].id, at: t(3)) // "a" pasted from the wheel, now "b" is oldest

        let result = store.record(.text("d"), at: t(4))

        guard case let .replaced(evicted, _) = result else {
            Issue.record("expected .replaced, got \(result)")
            return
        }
        #expect(evicted.content == .text("b"))
        #expect(texts(store.items) == ["a", "d", "c"]) // "d" took b's slot, others didn't move
    }

    @Test func copyingExistingContentRefreshesWithoutDuplicating() {
        var store = ClipStore(maxItems: 3)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.record(.text("c"), at: t(2))
        store.record(.text("a"), at: t(3)) // refresh "a", so "b" is now least recently used

        #expect(store.items.count == 3)
        store.record(.text("d"), at: t(4))
        #expect(texts(store.items) == ["a", "d", "c"])
    }

    @Test func pinnedItemsAreNeverOverwritten() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("old"), at: t(0))
        store.record(.text("new"), at: t(1))
        store.togglePin(store.items[0].id) // pin the oldest

        store.record(.text("newest"), at: t(2))

        #expect(texts(store.items) == ["old", "newest"])
        #expect(store.items[0].pinned)
    }

    @Test func allPinnedWheelKeepsNewCopiesOff() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.togglePin(store.items[0].id)
        store.togglePin(store.items[1].id)

        #expect(store.record(.text("c"), at: t(2)) == .noRoom)
        #expect(texts(store.items) == ["a", "b"])
    }

    @Test func imagesDedupeByFileName() {
        var store = ClipStore(maxItems: 4)
        store.record(.image(fileName: "abc.png"), at: t(0))
        store.record(.image(fileName: "abc.png"), at: t(1))
        #expect(store.items.count == 1)
        #expect(store.referencedImageFiles == ["abc.png"])
    }
}

@Suite("Pinning")
struct PinningTests {
    @Test func togglePinFlipsState() {
        var store = ClipStore(maxItems: 4)
        store.record(.text("a"), at: t(0))
        let id = store.items[0].id
        #expect(store.togglePin(id) == true)
        #expect(store.togglePin(id) == false)
    }

    @Test func pinContentAddsPinnedSlot() {
        var store = ClipStore(maxItems: 4)
        let result = store.pin(.text("snippet"), at: t(0))
        guard case let .added(item) = result else {
            Issue.record("expected .added, got \(result)")
            return
        }
        #expect(item.pinned)
    }

    @Test func pinContentWhenFullOverwritesLeastRecentlyUsedHistory() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.pin(.text("p"), at: t(2))
        #expect(texts(store.items) == ["p", "b"])
        #expect(store.items[0].pinned)
    }

    @Test func pinningIsOffInHistoryOnlyMode() {
        var store = ClipStore(maxItems: 4, mode: .historyOnly)
        store.record(.text("a"), at: t(0))
        #expect(store.togglePin(store.items[0].id) == nil)
        #expect(store.pin(.text("b")) == .ignored)
    }
}

@Suite("Modes")
struct ModeTests {
    @Test func pinnedOnlyShowsPinsAndIgnoresNewCopies() {
        var store = ClipStore(maxItems: 4)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.togglePin(store.items[1].id)
        store.setMode(.pinnedOnly)

        #expect(texts(store.visibleItems) == ["b"])
        #expect(store.record(.text("c"), at: t(2)) == .ignored)
    }

    @Test func pinnedOnlyKeepsHiddenHistory() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        let removed = store.setMode(.pinnedOnly)
        #expect(removed.isEmpty)
        store.setMode(.historyAndPinned)
        #expect(texts(store.items) == ["a", "b"])
    }

    @Test func historyOnlyHidesPinsAndGivesHistoryTheFullWheel() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("pin"), at: t(0))
        store.togglePin(store.items[0].id)
        store.setMode(.historyOnly)

        store.record(.text("a"), at: t(1))
        store.record(.text("b"), at: t(2))

        #expect(texts(store.visibleItems) == ["a", "b"])
        #expect(store.pinnedCount == 1)
    }

    @Test func switchingBackToBothTrimsLeastRecentlyUsedHistory() {
        var store = ClipStore(maxItems: 2)
        store.record(.text("pin"), at: t(0))
        store.togglePin(store.items[0].id)
        store.setMode(.historyOnly)
        store.record(.text("a"), at: t(1))
        store.record(.text("b"), at: t(2))

        let removed = store.setMode(.historyAndPinned)

        #expect(texts(removed) == ["a"])
        #expect(texts(store.visibleItems) == ["pin", "b"])
    }
}

@Suite("Max slices")
struct MaxItemsTests {
    @Test func loweringMaxRemovesLeastRecentlyUsedHistory() {
        var store = ClipStore(maxItems: 4)
        for (i, word) in ["a", "b", "c", "d"].enumerated() {
            store.record(.text(word), at: t(i))
        }
        let removed = store.setMaxItems(2)
        #expect(texts(removed) == ["a", "b"])
        #expect(texts(store.items) == ["c", "d"])
    }

    @Test func maxCannotGoBelowPinCount() {
        var store = ClipStore(maxItems: 4)
        for (i, word) in ["a", "b", "c"].enumerated() {
            store.record(.text(word), at: t(i))
            store.togglePin(store.items[i].id)
        }
        store.setMaxItems(2)
        #expect(store.maxItems == 3)
        #expect(store.items.count == 3)
    }

    @Test func maxIsClampedToRange() {
        var store = ClipStore()
        store.setMaxItems(100)
        #expect(store.maxItems == ClipStore.maxItemsRange.upperBound)
        store.setMaxItems(0)
        #expect(store.maxItems == ClipStore.maxItemsRange.lowerBound)
    }

    @Test func clearHistoryKeepsPins() {
        var store = ClipStore(maxItems: 4)
        store.record(.text("a"), at: t(0))
        store.record(.text("b"), at: t(1))
        store.togglePin(store.items[0].id)
        store.clearHistory()
        #expect(texts(store.items) == ["a"])
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test func roundTripsThroughJSON() throws {
        var store = ClipStore(maxItems: 5, mode: .historyAndPinned)
        store.record(.text("hello"), at: t(0))
        store.record(.image(fileName: "img.png"), at: t(1))
        store.togglePin(store.items[0].id)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("items.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        try ClipStorePersistence.save(store, to: url)
        let loaded = try ClipStorePersistence.load(from: url)
        #expect(loaded == store)
    }

    @Test func missingFileLoadsNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID()).json")
        #expect(try ClipStorePersistence.load(from: url) == nil)
    }
}
