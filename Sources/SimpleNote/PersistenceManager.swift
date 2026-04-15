import AppKit

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SimpleNote/note.rtfd", isDirectory: false)
    }()

    private init() {
        ensureDirectory()
    }

    private func ensureDirectory() {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func save(_ textStorage: NSTextStorage) {
        let range = NSRange(location: 0, length: textStorage.length)
        guard let data = textStorage.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> NSAttributedString? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return NSAttributedString(rtfd: data, documentAttributes: nil)
    }
}
