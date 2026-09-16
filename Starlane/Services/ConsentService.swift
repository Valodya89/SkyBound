import Foundation

/// Privacy consent for advertising.
///
/// Two separate regimes have to be satisfied before a personalised ad can be requested:
/// GDPR/ePrivacy (and the US state laws), through Google's User Messaging Platform, and Apple's
/// App Tracking Transparency, through the system prompt. Google requires the UMP form to come first
/// so the player knows what they are agreeing to before iOS asks about the advertising identifier.
@MainActor
protocol ConsentService: AnyObject {
    /// True once a decision exists — or none was needed — and ad requests may go out.
    var canRequestAds: Bool { get }
    /// True where the law requires a standing way to change that decision, which is what the
    /// "Privacy options" row in Settings is for. False everywhere else, and the row stays hidden.
    var showsPrivacyOptions: Bool { get }
    /// Runs the whole flow once, at launch. Never throws: a consent failure must not brick the game.
    func gather() async
    /// Re-opens the form from Settings so the player can withdraw or change consent.
    func presentPrivacyOptions() async
}

/// Previews and tests: nothing to consent to, because nothing is requested.
final class NoConsentService: ConsentService {
    var canRequestAds: Bool { true }
    var showsPrivacyOptions: Bool { false }
    func gather() async {}
    func presentPrivacyOptions() async {}
}
