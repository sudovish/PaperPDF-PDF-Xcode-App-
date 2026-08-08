import Foundation
import PDFKit
import UIKit

enum CompressionPreset: String, CaseIterable, Identifiable {
    case high = "High"
    case balanced = "Balanced"
    case small = "Small"

    var id: String { rawValue }

    var dpiScale: CGFloat {
        switch self {
        case .high:
            return 1.15
        case .balanced:
            return 0.85
        case .small:
            return 0.6
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .high:
            return 0.88
        case .balanced:
            return 0.65
        case .small:
            return 0.42
        }
    }
}

final class PDFService {
    enum PDFError: LocalizedError {
        case invalidPDF
        case failedToGenerate

        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "Invalid PDF data."
            case .failedToGenerate:
                return "Failed to generate PDF."
            }
        }
    }

    func pageCount(for data: Data) -> Int {
        PDFDocument(data: data)?.pageCount ?? 0
    }

    func pageCount(for url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    func thumbnail(for url: URL, size: CGSize = CGSize(width: 120, height: 160)) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }

    func makePDF(from images: [UIImage]) throws -> Data {
        guard !images.isEmpty else { throw PDFError.failedToGenerate }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)

        for image in images {
            let bounds = CGRect(origin: .zero, size: image.size)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            image.draw(in: bounds)
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    func mergePDFs(urls: [URL], progress: ((Double) -> Void)? = nil) throws -> Data {
        guard !urls.isEmpty else { throw PDFError.failedToGenerate }
        let result = PDFDocument()
        var insertionIndex = 0

        for (offset, url) in urls.enumerated() {
            guard let document = PDFDocument(url: url) else { continue }
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                result.insert(page, at: insertionIndex)
                insertionIndex += 1
            }
            let completion = Double(offset + 1) / Double(urls.count)
            progress?(completion)
        }

        guard let data = result.dataRepresentation() else {
            throw PDFError.failedToGenerate
        }
        return data
    }

    func mergePDFs(sources: [MergePDFSource], progress: ((Double) -> Void)? = nil) throws -> Data {
        guard !sources.isEmpty else { throw PDFError.failedToGenerate }

        let result = PDFDocument()
        var insertionIndex = 0

        for (offset, source) in sources.enumerated() {
            guard let document = PDFDocument(url: source.url) else { continue }

            let pageIndices = source.pageIndices ?? Array(0..<document.pageCount)
            for pageIndex in pageIndices {
                guard let page = document.page(at: pageIndex) else { continue }
                result.insert(page, at: insertionIndex)
                insertionIndex += 1
            }

            let completion = Double(offset + 1) / Double(sources.count)
            progress?(completion)
        }

        guard let data = result.dataRepresentation() else {
            throw PDFError.failedToGenerate
        }
        return data
    }

    func extractPages(from url: URL, selectedPageIndices: [Int]) throws -> Data {
        guard let source = PDFDocument(url: url) else { throw PDFError.invalidPDF }
        let output = PDFDocument()

        for (outputIndex, sourceIndex) in selectedPageIndices.enumerated() {
            guard let page = source.page(at: sourceIndex) else { continue }
            output.insert(page, at: outputIndex)
        }

        guard output.pageCount > 0, let data = output.dataRepresentation() else {
            throw PDFError.failedToGenerate
        }
        return data
    }

    func compressPDF(at url: URL, preset: CompressionPreset, progress: ((Double) -> Void)? = nil) throws -> Data {
        guard let source = PDFDocument(url: url), source.pageCount > 0 else {
            throw PDFError.invalidPDF
        }

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for pageIndex in 0..<source.pageCount {
                guard let page = source.page(at: pageIndex) else { continue }
                let pageBounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])

                let compressedImage = renderCompressedImage(
                    for: page,
                    pageBounds: pageBounds,
                    preset: preset
                )
                compressedImage.draw(in: pageBounds)

                let completion = Double(pageIndex + 1) / Double(source.pageCount)
                progress?(completion)
            }
        }
    }

    private func renderCompressedImage(for page: PDFPage, pageBounds: CGRect, preset: CompressionPreset) -> UIImage {
        let renderSize = CGSize(
            width: max(1, pageBounds.width * preset.dpiScale),
            height: max(1, pageBounds.height * preset.dpiScale)
        )

        let imageRenderer = UIGraphicsImageRenderer(size: renderSize)
        let renderedImage = imageRenderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            context.cgContext.saveGState()
            context.cgContext.scaleBy(x: preset.dpiScale, y: preset.dpiScale)
            context.cgContext.translateBy(x: 0, y: pageBounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }

        if let jpegData = renderedImage.jpegData(compressionQuality: preset.jpegQuality),
           let compressed = UIImage(data: jpegData) {
            return compressed
        }
        return renderedImage
    }
}

struct MergePDFSource {
    let url: URL
    let pageIndices: [Int]?
}
