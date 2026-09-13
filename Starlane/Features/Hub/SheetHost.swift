import SwiftUI

/// Routes `SheetKind` to its full-screen page. Kinds that share a page open it on the matching section.
struct SheetHost: View {
    let kind: SheetKind

    var body: some View {
        switch kind {
        case .modes: ModesScreen()
        case .shop: ShopScreen()
        case .crates: HangarScreen(initialTab: .rockets)
        case .upgrades: HangarScreen(initialTab: .workshop)
        case .pass: SeasonScreen()
        case .login: DailyScreen(focus: .streak)
        case .wheel: DailyScreen(focus: .spin)
        case .dailyChallenge: DailyScreen(focus: .course)
        case .rank: RanksScreen(initialTab: .weekly)
        case .duels: RanksScreen(initialTab: .duels)
        case .settings: SettingsScreen()
        }
    }
}
