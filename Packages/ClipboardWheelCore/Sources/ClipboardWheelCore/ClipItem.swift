import Foundation

/// What a wheel slot holds.
public enum ClipContent: Codable, Hashable, Sendable {
    /// Plain text.
    case text(String)
    /// An image saved as a PNG in the images folder. The file is named after a hash of
    /// its bytes, so two copies of the same image share one file name.
    case image(fileName: String)

    public var imageFileName: String? {
        if case let .image(fileName) = self { return fileName }
        return nil
    }

    public var text: String? {
        if case let .text(text) = self { return text }
        return nil
    }
}

/// One item on the wheel.
public struct ClipItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var content: ClipContent
    /// Pinned items are never overwritten.
    public var pinned: Bool
    /// Last time the item was copied or pasted from the wheel. The least recently used
    /// unpinned item is the one a new copy overwrites.
    public var lastUsed: Date
    public let created: Date

    public init(
        id: UUID = UUID(),
        content: ClipContent,
        pinned: Bool = false,
        lastUsed: Date,
        created: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.pinned = pinned
        self.lastUsed = lastUsed
        self.created = created ?? lastUsed
    }
}

/// Which items the wheel shows.
public enum WheelMode: String, Codable, CaseIterable, Sendable {
    /// Pinned items and recent copies share the wheel.
    case historyAndPinned
    /// Only recent copies. Pinned items are kept but hidden, and pinning is off.
    case historyOnly
    /// Only pinned items. New copies don't change the wheel.
    case pinnedOnly
}
