import Foundation

/// AdMob identifiers.
///
/// Debug builds always use Google's public test units. Requesting — let alone clicking — a live ad
/// from a development build is an invalid-traffic violation and gets the AdMob account suspended.
///
/// Release builds use `production`, which ships with placeholders until the units exist in the AdMob
/// dashboard (see ADMOB.md). A placeholder resolves to `nil`, and `GoogleAdService` then treats the
/// placement as "no ad available" — so a half-configured build quietly shows no ads instead of
/// serving Google's test creatives to real players.
enum AdUnits {
    /// Left in `production` until the real unit ID is pasted in.
    static let placeholder = "REPLACE_ME"

    /// One unit per placement. Create these in AdMob ▸ Apps ▸ Starlane ▸ Ad units.
    private static let production: [AdPlacement: String] = [
        .revive: "ca-app-pub-9054557293639529/2338413322",       // Rewarded    · Starlane · Revive
        .doubleCoins: "ca-app-pub-9054557293639529/4240108772",  // Rewarded    · Starlane · Double Coins
        .freeGems: "ca-app-pub-9054557293639529/7959861939",     // Rewarded    · Starlane · Free Gems
        .wheelSpin: "ca-app-pub-9054557293639529/9893469712",    // Rewarded    · Starlane · Wheel Spin
        .runEnd: "ca-app-pub-9054557293639529/6030246321",       // Interstitial· Starlane · Run End
        .returnToHub: "ca-app-pub-9054557293639529/7399168319",  // Interstitial· Starlane · Return To Hub
    ]

    /// Google's always-filling test units. Documented at developers.google.com/admob/ios/test-ads.
    private static let test: [AdPlacement: String] = [
        .revive: "ca-app-pub-3940256099942544/1712485313",
        .doubleCoins: "ca-app-pub-3940256099942544/1712485313",
        .freeGems: "ca-app-pub-3940256099942544/1712485313",
        .wheelSpin: "ca-app-pub-3940256099942544/1712485313",
        .runEnd: "ca-app-pub-3940256099942544/4411468910",
        .returnToHub: "ca-app-pub-3940256099942544/4411468910",
    ]

    /// `nil` when the placement has no usable unit, which in a release build means "not configured yet".
    static func unitID(for placement: AdPlacement) -> String? {
        #if DEBUG
        return test[placement]
        #else
        guard let id = production[placement], id != placeholder, !id.isEmpty else { return nil }
        return id
        #endif
    }

    /// Devices that must always receive test ads, even from a release build. The SDK prints the hash to
    /// use on first launch: "To get test ads on this device, set ... testDeviceIdentifiers".
    static let testDeviceIdentifiers: [String] = []
}
