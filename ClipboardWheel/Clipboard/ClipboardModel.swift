import AppKit
import Combine
import CryptoKit
import ClipboardWheelCore

/// The wheel's items, saved to disk, plus the image files they point to.
final class ClipboardModel: ObservableObject {
    @Published private(set) var store: ClipStore

    let folder: URL
    var imagesFolder: URL { folder.appendingPathComponent("images", isDirectory: true) }
    private var storeURL: URL { folder.appendingPathComponent("items.json") }
    private let imageCache = NSCache<NSString, NSImage>()

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardWheel", isDirectory: true)
    }

    init(folder: URL = ClipboardModel.defaultFolder) {
        self.folder = folder
        let url = folder.appendingPathComponent("items.json")
        do {
            store = try ClipStorePersistence.load(from: url) ?? ClipStore()
        } catch {
            NSLog("Clipboard Wheel: couldn't read saved items, starting fresh: \(error)")
            store = ClipStore()
        }
        removeUnreferencedImages()
    }

    // MARK: - Recording

    func recordText(_ text: String) {
        store.record(.text(text))
        save()
    }

    func recordImage(pngData: Data) {
        guard let fileName = saveImage(pngData) else { return }
        store.record(.image(fileName: fileName))
        save()
    }

    // MARK: - Pinning and editing

    func pin(text: String) {
        store.pin(.text(text))
        save()
    }

    func pinImage(pngData: Data) {
        guard let fileName = saveImage(pngData) else { return }
        store.pin(.image(fileName: fileName))
        save()
    }

    @discardableResult
    func togglePin(_ id: UUID) -> Bool? {
        let result = store.togglePin(id)
        save()
        return result
    }

    func markUsed(_ id: UUID) {
        store.markUsed(id)
        save()
    }

    func remove(_ id: UUID) {
        store.remove(id)
        save()
    }

    func clearHistory() {
        store.clearHistory()
        save()
    }

    func setMaxItems(_ value: Int) {
        store.setMaxItems(value)
        save()
    }

    func setMode(_ mode: WheelMode) {
        store.setMode(mode)
        save()
    }

    // MARK: - Pasteboard

    /// Writes an item to the system clipboard. Returns the clipboard's new change count.
    func writeToPasteboard(_ item: ClipItem) -> Int? {
        let pasteboard = NSPasteboard.general
        switch item.content {
        case let .text(text):
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
        case let .image(fileName):
            guard let png = try? Data(contentsOf: imageURL(fileName)) else { return nil }
            let tiff = NSImage(data: png)?.tiffRepresentation
            pasteboard.declareTypes(tiff == nil ? [.png] : [.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiff { pasteboard.setData(tiff, forType: .tiff) }
        }
        return pasteboard.changeCount
    }

    // MARK: - Images

    func imageURL(_ fileName: String) -> URL { imagesFolder.appendingPathComponent(fileName) }

    func image(named fileName: String) -> NSImage? {
        if let cached = imageCache.object(forKey: fileName as NSString) { return cached }
        guard let image = NSImage(contentsOf: imageURL(fileName)) else { return nil }
        imageCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    /// Saves PNG bytes under a name made from their hash, so the same image is stored once.
    private func saveImage(_ pngData: Data) -> String? {
        let hash = SHA256.hash(data: pngData).prefix(16).map { String(format: "%02x", $0) }.joined()
        let fileName = "\(hash).png"
        let url = imageURL(fileName)
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try pngData.write(to: url, options: .atomic)
            }
            return fileName
        } catch {
            NSLog("Clipboard Wheel: couldn't save image: \(error)")
            return nil
        }
    }

    private func removeUnreferencedImages() {
        let keep = store.referencedImageFiles
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesFolder.path)) ?? []
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: imageURL(file))
            imageCache.removeObject(forKey: file as NSString)
        }
    }

    private func save() {
        do {
            try ClipStorePersistence.save(store, to: storeURL)
        } catch {
            NSLog("Clipboard Wheel: couldn't save items: \(error)")
        }
        removeUnreferencedImages()
    }
}
