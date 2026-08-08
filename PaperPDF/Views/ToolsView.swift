import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import UIKit
import PhotosUI

struct ToolsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedTool: ToolType?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ToolType.allCases) { tool in
                        NavigationLink {
                            toolDestination(for: tool)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: icon(for: tool))
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.blue)
                                Text(tool.rawValue)
                                    .font(.headline)
                                Text(description(for: tool))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Tools")
            .navigationDestination(item: $selectedTool) { tool in
                toolDestination(for: tool)
            }
            .onAppear(perform: openPendingToolIfNeeded)
            .onChange(of: viewModel.pendingToolType) { _, _ in openPendingToolIfNeeded() }
        }
    }

    @ViewBuilder
    private func toolDestination(for tool: ToolType) -> some View {
        switch tool {
        case .scan: ScanToolView()
        case .import: ImportToolView()
        case .merge: MergeToolView()
        case .split: SplitToolView()
        case .markup: MarkupToolView()
        case .compress: CompressToolView()
        }
    }

    private func openPendingToolIfNeeded() {
        guard let pending = viewModel.pendingToolType else { return }
        selectedTool = pending
        viewModel.pendingToolType = nil
    }

    private func icon(for tool: ToolType) -> String {
        switch tool {
        case .scan: return "doc.text.viewfinder"
        case .import: return "photo.on.rectangle.angled"
        case .merge: return "square.stack.3d.forward.dottedline"
        case .split: return "square.split.2x1"
        case .markup: return "pencil.and.outline"
        case .compress: return "arrow.down.doc"
        }
    }

    private func description(for tool: ToolType) -> String {
        switch tool {
        case .scan: return "Capture paper documents and create PDFs."
        case .import: return "Convert selected images into a PDF."
        case .merge: return "Combine multiple PDFs into one file."
        case .split: return "Extract selected pages from a PDF."
        case .markup: return "Prepare a PDF copy for annotation/export."
        case .compress: return "Reduce PDF file size locally."
        }
    }
}

private enum OutputSheet: String, Identifiable {
    case share
    case export
    var id: String { rawValue }
}

struct ImportToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isPickingFiles = false
    @State private var isWorking = false
    @State private var outputDocument: DocumentItem?
    @State private var activeSheet: OutputSheet?

    var body: some View {
        ToolContainer(title: "Image Convert", subtitle: "Turn images from Photos or Files into one PDF.") {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                    Label("Photos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryToolButtonStyle())

                Button { isPickingFiles = true } label: {
                    Label("Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryToolButtonStyle())
            }

            outputActions(for: outputDocument, previewLabel: "Preview Converted PDF", activeSheet: $activeSheet)
        }
        .overlay { if isWorking { ProgressOverlay(text: "Converting...") } }
        .navigationTitle("Image Convert")
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await convertPhotos(items) }
        }
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await convertImageURLs(urls) }
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeSheet) { sheet in sheetView(sheet, document: outputDocument) }
    }

    private func convertPhotos(_ items: [PhotosPickerItem]) async {
        isWorking = true
        defer {
            isWorking = false
            selectedPhotoItems = []
        }

        do {
            let images = try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
                for (index, item) in items.enumerated() {
                    group.addTask {
                        let data = try await item.loadTransferable(type: Data.self)
                        return (index, data.flatMap(UIImage.init(data:)))
                    }
                }

                var ordered = Array<UIImage?>(repeating: nil, count: items.count)
                for try await (index, image) in group { ordered[index] = image }
                return ordered.compactMap { $0 }
            }
            try await save(images)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func convertImageURLs(_ urls: [URL]) async {
        isWorking = true
        defer { isWorking = false }

        let images = await Task.detached(priority: .userInitiated) {
            urls.compactMap { url -> UIImage? in
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }
        }.value

        do { try await save(images) } catch { viewModel.errorMessage = error.localizedDescription }
    }

    private func save(_ images: [UIImage]) async throws {
        guard !images.isEmpty else {
            viewModel.errorMessage = "No images could be loaded."
            return
        }
        let data = try viewModel.pdfService.makePDF(from: images)
        let stamp = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        outputDocument = try await viewModel.saveGeneratedPDFAsync(data, suggestedName: "Images-\(stamp).pdf")
    }
}

struct ScanToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ToolContainer(title: "Scan", subtitle: "VisionKit scanning is available on a real iPhone camera.") {
            Label(viewModel.scanService.scannerAvailableMessage, systemImage: "iphone")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("The production app uses VisionKit to capture pages, then passes the scanned images to PDFService.makePDF(from:) and saves the result to the local document library.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Scan")
    }
}

struct MergeToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isPickingFiles = false
    @State private var inputURLs: [URL] = []
    @State private var isWorking = false
    @State private var outputDocument: DocumentItem?
    @State private var activeSheet: OutputSheet?

    var body: some View {
        ToolContainer(title: "Merge", subtitle: "Combine selected PDFs into a single output document.") {
            Button { isPickingFiles = true } label: {
                Label("Select PDFs", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryToolButtonStyle())

            if inputURLs.isEmpty {
                Text("Select at least two PDFs.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inputURLs, id: \.self) { url in
                    Label(url.lastPathComponent, systemImage: "doc")
                        .lineLimit(1)
                }
            }

            Button("Merge PDFs") { runMerge() }
                .buttonStyle(PrimaryToolButtonStyle())
                .disabled(inputURLs.count < 2 || isWorking)

            outputActions(for: outputDocument, previewLabel: "Preview Merged PDF", activeSheet: $activeSheet)
        }
        .overlay { if isWorking { ProgressOverlay(text: "Merging...") } }
        .navigationTitle("Merge")
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): inputURLs = urls
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeSheet) { sheet in sheetView(sheet, document: outputDocument) }
    }

    private func runMerge() {
        guard inputURLs.count >= 2 else { return }
        isWorking = true
        Task {
            do {
                let access = inputURLs.map { ($0, $0.startAccessingSecurityScopedResource()) }
                defer { access.forEach { if $0.1 { $0.0.stopAccessingSecurityScopedResource() } } }
                let data = try viewModel.pdfService.mergePDFs(urls: inputURLs)
                outputDocument = try await viewModel.saveGeneratedPDFAsync(data, suggestedName: "Merged.pdf")
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

struct SplitToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isPickingFile = false
    @State private var sourceURL: URL?
    @State private var sourceName = ""
    @State private var pageCount = 0
    @State private var selectedPages: Set<Int> = []
    @State private var isWorking = false
    @State private var outputDocument: DocumentItem?
    @State private var activeSheet: OutputSheet?

    var body: some View {
        ToolContainer(title: "Split / Extract", subtitle: "Select pages and export them as a new PDF.") {
            Button { isPickingFile = true } label: {
                Label("Select PDF", systemImage: "doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryToolButtonStyle())

            if pageCount > 0 {
                Text(sourceName).font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Button {
                            if selectedPages.contains(index) { selectedPages.remove(index) } else { selectedPages.insert(index) }
                        } label: {
                            Text("\(index + 1)")
                                .frame(width: 54, height: 54)
                                .background(selectedPages.contains(index) ? Color.blue : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(selectedPages.contains(index) ? .white : .primary)
                        }
                    }
                }

                Button("Extract Selected Pages") { runExtract() }
                    .buttonStyle(PrimaryToolButtonStyle())
                    .disabled(selectedPages.isEmpty || isWorking)
            }

            outputActions(for: outputDocument, previewLabel: "Preview Extracted PDF", activeSheet: $activeSheet)
        }
        .overlay { if isWorking { ProgressOverlay(text: "Extracting...") } }
        .navigationTitle("Split / Extract")
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): load(urls.first)
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeSheet) { sheet in sheetView(sheet, document: outputDocument) }
    }

    private func load(_ url: URL?) {
        guard let url else { return }
        sourceURL = url
        sourceName = url.lastPathComponent
        selectedPages.removeAll()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        pageCount = PDFDocument(url: url)?.pageCount ?? 0
    }

    private func runExtract() {
        guard let sourceURL else { return }
        isWorking = true
        Task {
            do {
                let access = sourceURL.startAccessingSecurityScopedResource()
                defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
                let data = try viewModel.pdfService.extractPages(from: sourceURL, selectedPageIndices: selectedPages.sorted())
                outputDocument = try await viewModel.saveGeneratedPDFAsync(data, suggestedName: "Extracted-\(sourceName)")
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

struct CompressToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isPickingFile = false
    @State private var sourceURL: URL?
    @State private var sourceName = ""
    @State private var preset: CompressionPreset = .balanced
    @State private var isWorking = false
    @State private var outputDocument: DocumentItem?
    @State private var activeSheet: OutputSheet?

    var body: some View {
        ToolContainer(title: "Compress", subtitle: "Render and rebuild a smaller local PDF.") {
            Button { isPickingFile = true } label: {
                Label("Select PDF", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryToolButtonStyle())

            Picker("Preset", selection: $preset) {
                ForEach(CompressionPreset.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if !sourceName.isEmpty { Text("Source: \(sourceName)").font(.caption).foregroundStyle(.secondary) }

            Button("Compress PDF") { runCompression() }
                .buttonStyle(PrimaryToolButtonStyle())
                .disabled(sourceURL == nil || isWorking)

            outputActions(for: outputDocument, previewLabel: "Preview Compressed PDF", activeSheet: $activeSheet)
        }
        .overlay { if isWorking { ProgressOverlay(text: "Compressing...") } }
        .navigationTitle("Compress")
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                sourceURL = urls.first
                sourceName = urls.first?.lastPathComponent ?? ""
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeSheet) { sheet in sheetView(sheet, document: outputDocument) }
    }

    private func runCompression() {
        guard let sourceURL else { return }
        isWorking = true
        Task {
            do {
                let access = sourceURL.startAccessingSecurityScopedResource()
                defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
                let data = try viewModel.pdfService.compressPDF(at: sourceURL, preset: preset)
                outputDocument = try await viewModel.saveGeneratedPDFAsync(data, suggestedName: "Compressed-\(sourceName)")
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

struct MarkupToolView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isPickingFile = false
    @State private var sourceURL: URL?
    @State private var sourceName = ""
    @State private var outputDocument: DocumentItem?
    @State private var activeSheet: OutputSheet?

    var body: some View {
        ToolContainer(title: "Markup", subtitle: "Open a PDF and save an editable working copy.") {
            Button { isPickingFile = true } label: {
                Label("Select PDF", systemImage: "pencil.and.outline")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryToolButtonStyle())

            if let sourceURL {
                PDFKitRepresentedView(document: PDFDocument(url: sourceURL) ?? PDFDocument())
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Save Markup Copy") { saveCopy() }
                    .buttonStyle(PrimaryToolButtonStyle())
            }

            outputActions(for: outputDocument, previewLabel: "Preview Markup Copy", activeSheet: $activeSheet)
        }
        .navigationTitle("Markup")
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                sourceURL = urls.first
                sourceName = urls.first?.lastPathComponent ?? "Document.pdf"
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeSheet) { sheet in sheetView(sheet, document: outputDocument) }
    }

    private func saveCopy() {
        guard let sourceURL else { return }
        Task {
            do {
                let access = sourceURL.startAccessingSecurityScopedResource()
                defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: sourceURL)
                outputDocument = try await viewModel.saveGeneratedPDFAsync(data, suggestedName: "Markup-\(sourceName)")
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ToolContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.largeTitle.weight(.bold))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                content
            }
            .padding()
        }
    }
}

private struct ProgressOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            ProgressView(text)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct PrimaryToolButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(isEnabled ? Color.blue.opacity(configuration.isPressed ? 0.78 : 1) : Color.gray.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }
}

@ViewBuilder
private func outputActions(for document: DocumentItem?, previewLabel: String, activeSheet: Binding<OutputSheet?>) -> some View {
    if let document {
        VStack(spacing: 10) {
            NavigationLink {
                PDFPreviewView(documentItem: document)
            } label: {
                Label(previewLabel, systemImage: "eye")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryToolButtonStyle())

            HStack(spacing: 12) {
                Button { activeSheet.wrappedValue = .share } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryToolButtonStyle())

                Button { activeSheet.wrappedValue = .export } label: {
                    Label("Save", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryToolButtonStyle())
            }
        }
    }
}

@ViewBuilder
private func sheetView(_ sheet: OutputSheet, document: DocumentItem?) -> some View {
    if let document, let viewModel = EnvironmentObjectReader<AppViewModel>.current {
        switch sheet {
        case .share:
            ActivityView(activityItems: [viewModel.url(for: document)])
        case .export:
            FilesExportView(url: viewModel.url(for: document))
        }
    } else {
        ContentUnavailableView("No Output PDF", systemImage: "doc.slash")
    }
}

private struct EnvironmentObjectReader<T: ObservableObject>: View {
    @EnvironmentObject private var object: T
    static var current: T? { nil }
    var body: some View { EmptyView() }
}
