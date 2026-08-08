import Foundation

@MainActor
final class PurchaseService: ObservableObject {
    // Temporary free-access mode: keep the existing service surface so the rest of the app
    // does not need a wide refactor while paid features are disabled.
    @Published private(set) var isProUnlocked = true
    @Published var statusMessage: String?

    func refreshStatus() async {
        isProUnlocked = true
        statusMessage = nil
    }

    func purchasePro() async throws {
        // TODO: Restore the original StoreKit purchase flow here when paid features return.
        statusMessage = "Purchases are temporarily disabled while all PDF tools are free."
    }

    func restorePurchases() async {
        // TODO: Restore the original App Store restore flow here when paid features return.
        statusMessage = "Restore is unavailable while purchases are turned off."
    }
}
