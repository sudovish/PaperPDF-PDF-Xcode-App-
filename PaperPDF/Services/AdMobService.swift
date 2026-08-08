import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobService: NSObject, ObservableObject {
    static let shared = AdMobService()

    private let interstitialAdUnitID = "ca-app-pub-2300650472248860/6037420220"

    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    private var dismissalContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
    }

    func start() {
        // Start the SDK once during app setup and quietly preload the first export ad.
        #if DEBUG
        // TODO: Add your physical test device IDs here while testing live ads locally.
        let testDeviceIdentifiers: [String] = []
        if !testDeviceIdentifiers.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
        }
        #endif

        MobileAds.shared.start(completionHandler: nil)
        debugLog("SDK started. Beginning interstitial preload.")
        loadInterstitialIfNeeded()
    }

    func loadInterstitialIfNeeded() {
        guard interstitialAd == nil, !isLoading else { return }
        isLoading = true
        debugLog("Loading interstitial for export flow.")

        Task {
            defer { isLoading = false }

            do {
                let ad = try await InterstitialAd.load(with: interstitialAdUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
                debugLog("Interstitial loaded successfully.")
            } catch {
                interstitialAd = nil
                debugLog("Interstitial failed to load: \(error.localizedDescription)")
            }
        }
    }

    func presentInterstitialIfAvailable() async {
        guard let ad = interstitialAd else {
            debugLog("Interstitial not ready. Continuing export without an ad.")
            loadInterstitialIfNeeded()
            return
        }

        interstitialAd = nil
        ad.fullScreenContentDelegate = self

        do {
            try ad.canPresent(from: nil)
        } catch {
            debugLog("Interstitial could not present: \(error.localizedDescription)")
            loadInterstitialIfNeeded()
            return
        }

        debugLog("Presenting interstitial before export.")

        await withCheckedContinuation { continuation in
            dismissalContinuation = continuation
            ad.present(from: nil)
        }
    }

    private func finishAdFlow() {
        debugLog("Interstitial finished. Preloading next ad.")
        dismissalContinuation?.resume()
        dismissalContinuation = nil
        loadInterstitialIfNeeded()
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AdMobService] \(message)")
        #endif
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishAdFlow()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        debugLog("Interstitial failed to present: \(error.localizedDescription)")
        finishAdFlow()
    }
}
