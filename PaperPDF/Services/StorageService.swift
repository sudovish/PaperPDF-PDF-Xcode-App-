import Foundation

final class StorageService {
    enum StorageError: LocalizedError {
        case unableToCreateStorage
        case invalidFile

        var errorDescription: String? {
            switch self {
            case .unableToCreateStorage:
                return "Unable to prepare app storage."
            case .invalidFile:
                return "The selected file is not valid."
            }
        }
    }

    private struct MetadataContainer: Codable {
        var documents: [DocumentItem]
    }

    private let fm = FileManager.default
    private let metadataFileName = "metadata.json"
    private let defaultExportBookmarkKey = "settings.default.export.bookmark"
    private let storageFolderName = "Paper PDF"
    private let legacyStorageFolderName = "PDFToolkit"

    var baseDirectory: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent(storageFolderName, isDirectory: true)
    }

    private var legacyBaseDirectory: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent(legacyStorageFolderName, isDirectory: true)
    }

    var documentsDirectory: URL {
        baseDirectory.appendingPathComponent("Documents", isDirectory: true)
    }

    private var metadataURL: URL {
        baseDirectory.appendingPathComponent(metadataFileName)
    }

    func ensureStorageReady() throws {
        try migrateLegacyStorageIfNeeded()
        try fm.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: metadataURL.path) {
            let initial = MetadataContainer(documents: [])
            let data = try JSONEncoder().encode(initial)
            try data.write(to: metadataURL, options: .atomic)
        }
    }

    private func migrateLegacyStorageIfNeeded() throws {
        let legacyExists = fm.fileExists(atPath: legacyBaseDirectory.path)
        let newExists = fm.fileExists(atPath: baseDirectory.path)

        guard legacyExists, !newExists else { return }
        try fm.moveItem(at: legacyBaseDirectory, to: baseDirectory)
    }

    func loadDocuments() throws -> [DocumentItem] {
        try ensureStorageReady()
        let data = try Data(contentsOf: metadataURL)
        let decoded = try JSONDecoder().decode(MetadataContainer.self, from: data)
        return decoded.documents.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func saveDocuments(_ docs: [DocumentItem]) throws {
        try ensureStorageReady()
        let container = MetadataContainer(documents: docs)
        let data = try JSONEncoder().encode(container)
        try data.write(to: metadataURL, options: .atomic)
    }

    func absoluteURL(for item: DocumentItem) -> URL {
        documentsDirectory.appendingPathComponent(item.relativePath)
    }

    func importPDFData(_ data: Data, suggestedName: String) throws -> DocumentItem {
        try ensureStorageReady()
        let safeName = suggestedName.replacingOccurrences(of: "/", with: "-")
        let finalName = safeName.lowercased().hasSuffix(".pdf") ? safeName : "\(safeName).pdf"
        let uniqueName = "\(UUID().uuidString)-\(finalName)"
        let destination = documentsDirectory.appendingPathComponent(uniqueName)
        try data.write(to: destination, options: .atomic)

        let attributes = try fm.attributesOfItem(atPath: destination.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? Int64(data.count)

        return DocumentItem(
            id: UUID(),
            fileName: finalName,
            relativePath: uniqueName,
            createdAt: Date(),
            pageCount: 0,
            fileSizeBytes: fileSize,
            isPinned: false
        )
    }

    func saveDefaultExportFolder(url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: defaultExportBookmarkKey)
    }

    func loadDefaultExportFolder() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: defaultExportBookmarkKey) else {
            return nil
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try saveDefaultExportFolder(url: url)
            }
            return url
        } catch {
            return nil
        }
    }
}
