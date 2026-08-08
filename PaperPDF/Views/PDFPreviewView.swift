import SwiftUI
import PDFKit
import UIKit

struct PDFPreviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let documentItem: DocumentItem
    @State private var activeSheet: PreviewSheet?

    var body: some View {
        NavigationStack {
            Group {
                if let document = PDFDocument(url: viewModel.url(for: documentItem)) {
                    PDFKitRepresentedView(document: document)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("Unable to load PDF", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle(documentItem.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.presentAdThenContinue {
                            activeSheet = .share
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        viewModel.presentAdThenContinue {
                            activeSheet = .export
                        }
                    } label: {
                        Label("Export", systemImage: "folder")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .share:
                    ActivityView(activityItems: [viewModel.url(for: documentItem)])
                case .export:
                    FilesExportView(url: viewModel.url(for: documentItem))
                }
            }
        }
    }
}

private enum PreviewSheet: String, Identifiable {
    case share
    case export

    var id: String { rawValue }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FilesExportView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {}
}
