import Foundation
import SwiftUI
import PDFKit
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var documents: [DocumentItem] = []
    @Published var selectedDocument: DocumentItem?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var defaultExportFolderName: String?
    @Published var pendingToolType: ToolType?

    let storageService = StorageService()
    let pdfService = PDFService()
    let scanService = ScanService()
    let purchaseService = PurchaseService()
    let adMobService = AdMobService.shared

    func loadInitialData() async {
        do {
            let initialState = try await Task.detached(priority: .userInitiated) {
                let storageService = StorageService()
                return (
                    documents: try storageService.loadDocuments(),
                    defaultExportFolderName: storageService.loadDefaultExportFolder()?.lastPathComponent
                )
            }.value

            documents = initialState.documents
            defaultExportFolderName = initialState.defaultExportFolderName
            await purchaseService.refreshStatus()
            // Preload the export ad up front so tool usage stays uninterrupted.
            adMobService.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleIncomingURL(_ url: URL) async {
        await importDocuments(from: [url], openLastImported: true)
    }

    func importDocuments(from urls: [URL], openLastImported: Bool = false) async {
        guard !urls.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let result = await Task.detached(priority: .userInitiated) { () -> (imported: [DocumentItem], errors: [String]) in
            let storageService = StorageService()
            let pdfService = PDFService()
            var imported: [DocumentItem] = []
            var errors: [String] = []

            for url in urls where url.isFileURL {
                do {
                    let startedAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if startedAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    let data = try Data(contentsOf: url)
                    let pathExt = url.pathExtension.lowercased()

                    if pathExt == "pdf" {
                        var item = try storageService.importPDFData(data, suggestedName: url.lastPathComponent)
                        item.pageCount = pdfService.pageCount(for: data)
                        imported.append(item)
                    } else if let image = UIImage(data: data) {
                        let pdfData = try pdfService.makePDF(from: [image])
                        let baseName = url.deletingPathExtension().lastPathComponent
                        var item = try storageService.importPDFData(pdfData, suggestedName: "\(baseName).pdf")
                        item.pageCount = 1
                        imported.append(item)
                    }
                } catch {
                    errors.append("Import failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            return (imported, errors)
        }.value

        let imported = result.imported
        if let firstError = result.errors.first {
            errorMessage = firstError
        }

        guard !imported.isEmpty else { return }
        documents.append(contentsOf: imported)
        sortDocuments()

        do {
            try await persistDocuments()
            if openLastImported, let last = imported.last {
                selectedDocument = last
                selectedTab = .home
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func url(for item: DocumentItem) -> URL {
        storageService.absoluteURL(for: item)
    }

    func togglePin(for item: DocumentItem) {
        guard let index = documents.firstIndex(where: { $0.id == item.id }) else { return }
        documents[index].isPinned.toggle()
        sortDocuments()
        let snapshot = documents
        Task {
            do {
                try await persistDocuments(snapshot)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @discardableResult
    func saveGeneratedPDF(_ data: Data, suggestedName: String, openAfterSave: Bool = false) throws -> DocumentItem {
        var item = try storageService.importPDFData(data, suggestedName: suggestedName)
        item.pageCount = pdfService.pageCount(for: data)
        documents.append(item)
        sortDocuments()
        try storageService.saveDocuments(documents)
        if openAfterSave {
            selectedDocument = item
        }
        return item
    }

    @discardableResult
    func saveGeneratedPDFAsync(_ data: Data, suggestedName: String, openAfterSave: Bool = false) async throws -> DocumentItem {
        let item = try await Task.detached(priority: .userInitiated) {
            let storageService = StorageService()
            let pdfService = PDFService()
            var item = try storageService.importPDFData(data, suggestedName: suggestedName)
            item.pageCount = pdfService.pageCount(for: data)
            return item
        }.value

        documents.append(item)
        sortDocuments()
        try await persistDocuments()
        if openAfterSave {
            selectedDocument = item
        }
        return item
    }

    func canRunCompression() -> Bool {
        true
    }

    func recordCompressionUsage() {
        // No-op while the app is temporarily ad-supported instead of purchase-gated.
    }

    func presentAdThenContinue(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await adMobService.presentInterstitialIfAvailable()
            action()
        }
    }

    func setDefaultExportFolder(_ url: URL) {
        do {
            try storageService.saveDefaultExportFolder(url: url)
            defaultExportFolderName = url.lastPathComponent
        } catch {
            errorMessage = "Unable to save export folder: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    func generateDemoDataset() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let demoSpecs: [(name: String, accent: UIColor, pages: Int)] = [
                ("Demo-Contract", .systemBlue, 2),
                ("Demo-Report", .systemTeal, 3),
                ("Demo-Receipt", .systemOrange, 1)
            ]

            for spec in demoSpecs {
                let images: [UIImage] = (1...spec.pages).map { page in
                    Self.makeDemoPageImage(
                        title: spec.name,
                        subtitle: "Page \(page) of \(spec.pages)",
                        accent: spec.accent
                    )
                }
                let data = try pdfService.makePDF(from: images)
                _ = try await saveGeneratedPDFAsync(data, suggestedName: "\(spec.name).pdf")
            }
        } catch {
            errorMessage = "Failed to generate demo data: \(error.localizedDescription)"
        }
    }

    private static func makeDemoPageImage(title: String, subtitle: String, accent: UIColor) -> UIImage {
        let size = CGSize(width: 1024, height: 1448)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let bandRect = CGRect(x: 0, y: 0, width: size.width, height: 220)
            accent.withAlphaComponent(0.12).setFill()
            context.fill(bandRect)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]

            title.draw(at: CGPoint(x: 70, y: 86), withAttributes: titleAttributes)
            subtitle.draw(at: CGPoint(x: 70, y: 640), withAttributes: subtitleAttributes)

            let lineRect = CGRect(x: 70, y: 760, width: size.width - 140, height: 2)
            accent.withAlphaComponent(0.5).setFill()
            context.fill(lineRect)
        }
    }
    #endif

    private func sortDocuments() {
        documents.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func persistDocuments(_ docs: [DocumentItem]? = nil) async throws {
        let snapshot = docs ?? documents
        try await Task.detached(priority: .utility) {
            let storageService = StorageService()
            try storageService.saveDocuments(snapshot)
        }.value
    }
}
