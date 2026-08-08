import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingFolderPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    exportCard
                    adsCard
                    privacyCard
                }
                .padding()
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingFolderPicker) {
                FolderPickerView { url in
                    viewModel.setDefaultExportFolder(url)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preferences")
                .font(.largeTitle.weight(.bold))
            Text("Manage export defaults and local app behavior.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var exportCard: some View {
        settingsCard(title: "Export", icon: "folder.badge.gearshape", tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Default folder")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.defaultExportFolderName ?? "Not set")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isShowingFolderPicker = true
                } label: {
                    Text("Choose Folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
            }
        }
    }

    private var adsCard: some View {
        settingsCard(title: "Ads", icon: "play.rectangle", tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                Text("All PDF tools are currently available for free.")
                    .font(.headline)

                Text("An interstitial ad is shown only when you tap the final Export button. Editing and tool usage stay uninterrupted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let message = viewModel.purchaseService.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(infoFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Temporary rollout notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Paid features and upgrade prompts are disabled.")
                    Text("Ads use Google AdMob test inventory for now.")
                    Text("Production AdMob IDs can be swapped in later.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyCard: some View {
        settingsCard(title: "Privacy", icon: "lock.shield", tint: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Everything runs locally on device. No account is required for the core document tools.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Google AdMob is initialized to support the export interstitial flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.title3.weight(.semibold))
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: settingsCardColors(tint: tint),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }

    private var baseCardFill: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }

    private var infoFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    private func settingsCardColors(tint: Color) -> [Color] {
        [
            baseCardFill,
            colorScheme == .dark ? tint.opacity(0.14) : tint.opacity(0.05)
        ]
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? Color.blue.opacity(configuration.isPressed ? 0.8 : 1) : Color.gray.opacity(0.45))
            )
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : Color.white.opacity(0.9))
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? Color(red: 0.39, green: 0.67, blue: 0.98).opacity(configuration.isPressed ? 0.82 : 1) : Color.gray.opacity(0.22))
            )
    }
}

private struct FolderPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let first = urls.first else { return }
            onPick(first)
        }
    }
}
