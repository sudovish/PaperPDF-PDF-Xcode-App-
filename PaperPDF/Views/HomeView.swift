import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewingItem: DocumentItem?
    @State private var selectedTool: ToolType?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Paper PDF")
                        .font(.largeTitle.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(ToolType.allCases) { tool in
                            Button {
                                selectedTool = tool
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: toolIcon(for: tool))
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(toolTint(for: tool))
                                        .frame(width: 46, height: 46)
                                        .background(toolTint(for: tool).opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(tool.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(toolDescription(for: tool))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
                                .padding(16)
                                .background(
                                    LinearGradient(
                                        colors: homeCardColors(tint: toolTint(for: tool)),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(toolTint(for: tool).opacity(0.14), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Documents")
                            .font(.title3.weight(.semibold))

                        if viewModel.documents.isEmpty {
                            Text("No documents yet. Start with Scan or Image Convert.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(cardBaseFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            ForEach(viewModel.documents) { item in
                                Button {
                                    previewingItem = item
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "doc.richtext")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.blue)
                                            .frame(width: 42, height: 42)
                                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(item.pageCount) pages • \(ByteCountFormatter.string(fromByteCount: item.fileSizeBytes, countStyle: .file))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if item.isPinned {
                                            Image(systemName: "pin.fill")
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(14)
                                    .background(cardBaseFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(item.isPinned ? "Unpin" : "Pin") {
                                        viewModel.togglePin(for: item)
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(item: $selectedTool) { tool in
                toolDestinationView(for: tool)
            }
            .onAppear {
                openPendingToolIfNeeded()
            }
            .onChange(of: viewModel.pendingToolType) { _, _ in
                openPendingToolIfNeeded()
            }
            .sheet(item: $previewingItem) { item in
                PDFPreviewView(documentItem: item)
                    .environmentObject(viewModel)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("Processing...")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func openPendingToolIfNeeded() {
        guard let pending = viewModel.pendingToolType else { return }
        selectedTool = pending
        viewModel.pendingToolType = nil
        viewModel.selectedTab = .home
    }

    private func toolIcon(for tool: ToolType) -> String {
        switch tool {
        case .scan:
            return "doc.text.viewfinder"
        case .import:
            return "photo.on.rectangle.angled"
        case .merge:
            return "square.stack.3d.forward.dottedline"
        case .split:
            return "square.split.2x1"
        case .markup:
            return "pencil.and.outline"
        case .compress:
            return "arrow.down.doc"
        }
    }

    private func toolTint(for tool: ToolType) -> Color {
        switch tool {
        case .scan:
            return .blue
        case .import:
            return .green
        case .merge:
            return .orange
        case .split:
            return .teal
        case .markup:
            return .pink
        case .compress:
            return .indigo
        }
    }

    private func toolDescription(for tool: ToolType) -> String {
        switch tool {
        case .scan:
            return "Capture paper documents with the camera and turn them into a PDF."
        case .import:
            return "Turn selected images into a new PDF."
        case .merge:
            return "Combine multiple PDFs into a single document."
        case .split:
            return "Pull selected pages out of a PDF to create a new smaller PDF."
        case .markup:
            return "Draw or highlight directly on a PDF and save the edited copy."
        case .compress:
            return "Reduce PDF file size for sharing or storage."
        }
    }

    private var cardBaseFill: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }

    private func homeCardColors(tint: Color) -> [Color] {
        [
            cardBaseFill,
            colorScheme == .dark ? tint.opacity(0.14) : tint.opacity(0.06)
        ]
    }
}

@ViewBuilder
private func toolDestinationView(for tool: ToolType) -> some View {
    switch tool {
    case .scan:
        ScanToolView()
    case .import:
        ImportToolView()
    case .markup:
        MarkupToolView()
    case .compress:
        CompressToolView()
    case .merge:
        MergeToolView()
    case .split:
        SplitToolView()
    }
}
