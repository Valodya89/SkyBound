import AppTrackingTransparency
import Foundation
import UIKit
import UserMessagingPlatform

/// The real consent flow: Google's User Messaging Platform, then Apple's ATT prompt.
///
/// The order is not interchangeable. Google's policy requires its own message first, and Apple's
/// prompt can only be answered once — asking before the player has any idea why costs a large share
/// of the opt-ins that personalised ads are priced on.
///
/// Both steps fail open. If the consent info update fails (no network at launch, say), the SDK still
/// reports whether ads can be requested; usually that means non-personalised ads, which is the right
/// outcome. Refusing to show any ad because a form failed to load would be worse for everyone.
final class UMPConsentService: ConsentService {
    private(set) var canRequestAds = false

    var showsPrivacyOptions: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    func gather() async {
        await requestConsentInfoUpdate()
        await loadAndPresentFormIfRequired()
        canRequestAds = ConsentInformation.shared.canRequestAds
        await requestTrackingAuthorization()
    }

    func presentPrivacyOptions() async {
        await withCheckedContinuation { continuation in
            ConsentForm.presentPrivacyOptionsForm(from: AdWindow.topViewController) { _ in
                continuation.resume()
            }
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
    }

    // MARK: - UMP

    private func requestConsentInfoUpdate() async {
        let parameters = RequestParameters()
        // Starlane is not directed at children and is not in the Kids category; see ADMOB.md.
        parameters.isTaggedForUnderAgeOfConsent = false
        #if DEBUG
        let debug = DebugSettings()
        // Flip to `.EEA` to rehearse the GDPR form from anywhere. The device must also be listed
        // below, or in AdMob ▸ Privacy & messaging ▸ Test devices.
        debug.geography = .disabled
        debug.testDeviceIdentifiers = AdUnits.testDeviceIdentifiers
        parameters.debugSettings = debug
        #endif
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error { print("[Consent] info update failed: \(error.localizedDescription)") }
                continuation.resume()
            }
        }
    }

    private func loadAndPresentFormIfRequired() async {
        await withCheckedContinuation { continuation in
            // Returns on the next run loop without presenting anything outside the regions that need it.
            ConsentForm.loadAndPresentIfRequired(from: AdWindow.topViewController) { error in
                if let error { print("[Consent] form failed: \(error.localizedDescription)") }
                continuation.resume()
            }
        }
    }

    // MARK: - App Tracking Transparency

    private func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // The prompt is dropped on the floor if the app is not frontmost, and the status stays
        // `.notDetermined` — so wait rather than burning the one chance to ask.
        await waitUntilActive()
        _ = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func waitUntilActive() async {
        var attempts = 0
        while UIApplication.shared.applicationState != .active, attempts < 20 {
            try? await Task.sleep(for: .milliseconds(250))
            attempts += 1
        }
    }
}

/// Finds the view controller a full-screen ad or consent form should be presented from.
enum AdWindow {
    static var topViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
