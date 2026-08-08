import Foundation

struct DocumentItem: Identifiable, Codable, Hashable {
    let id: UUID
    var fileName: String
    var relativePath: String
    var createdAt: Date
    var pageCount: Int
    var fileSizeBytes: Int64
    var isPinned: Bool

    var displayName: String {
        if fileName.lowercased().hasSuffix(".pdf") {
            return String(fileName.dropLast(4))
        }
        return fileName
    }
}
