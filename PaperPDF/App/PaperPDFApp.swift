import SwiftUI

@main
struct PaperPDFApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appViewModel)
                .task {
                    await appViewModel.loadInitialData()
                }
                .onOpenURL { url in
                    Task {
                        await appViewModel.handleIncomingURL(url)
                    }
                }
        }
    }
}
