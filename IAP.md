# In-app purchases — App Store Connect setup

Everything below is what Starlane's code already expects. Create these exactly; a mismatched identifier
means the product silently disappears from the shop (the app logs `[Store] products missing from App Store
Connect: …` on launch).

- **App bundle ID:** `com.ravo.skybound`
- **Catalog in code:** `StoreProduct` in `Packages/StarlaneCore/Sources/StarlaneCore/Economy/ShopCatalog.swift`
- **Local test catalog:** `Starlane.storekit` (wired to the scheme's Run and Test actions)

## Products

| # | Product ID | Type | Reference Name | Display Name | Tier / Price (USD) | Grants |
|---|------------|------|----------------|--------------|--------------------|--------|
| 1 | `com.ravo.skybound.gems.pouch` | Consumable | Pouch of Gems | Pouch of Gems | $1.99 | 120 gems |
| 2 | `com.ravo.skybound.gems.chest` | Consumable | Chest of Gems | Chest of Gems | $7.99 | 650 gems (+8% bonus) |
| 3 | `com.ravo.skybound.gems.vault` | Consumable | Vault of Gems | Vault of Gems | $14.99 | 1,450 gems (+20% bonus) |
| 4 | `com.ravo.skybound.gems.hoard` | Consumable | Singularity Hoard | Singularity Hoard | $39.99 | 4,000 gems (+34% bonus) |
| 5 | `com.ravo.skybound.piggybank` | Consumable | Piggy Bank | Piggy Bank | $3.99 | Coins accumulated from play (capped at 4,000) |
| 6 | `com.ravo.skybound.noads` | Non-Consumable | Remove Ads | Remove Ads | $2.99 | Disables every interstitial permanently |
| 7 | `com.ravo.skybound.bundle.founder` | Non-Consumable | Founder's Bundle | Founder's Bundle | $5.99 | 1,200 gems + Gilded Comet skin + 3 boosts |
| 8 | `com.ravo.skybound.vip.monthly` | Auto-Renewable Subscription | VIP Pass Monthly | VIP Pass | $6.99 / month | +2 energy cap, 2× coins every run, no interstitials |

**Family Sharing:** off for all eight. Remove Ads and the Founder's Bundle may be enabled later if you want
to; that is a product setting only, no code change.

### Subscription group

| Field | Value |
|-------|-------|
| Reference Name | Starlane VIP |
| Group identifier in code | `StoreProduct.vipSubscriptionGroupID` = `skybound.vip` |
| Members | `com.ravo.skybound.vip.monthly` (level 1) |

The group is deliberately a single tier. If you add an annual VIP later, put it in the same group at the
same level so upgrades and downgrades are handled by the App Store, and add it to `StoreProduct.all`.

### Localizations (English — US)

Every product needs one English (U.S.) localization. App Store Connect caps Reference Name at 64
characters, Display Name at 30 and Description at 45; all of the below fit.

| Product | Display Name | Description |
|---------|--------------|-------------|
| Pouch of Gems | Pouch of Gems | 120 gems. |
| Chest of Gems | Chest of Gems | 650 gems, including an 8% bonus. |
| Vault of Gems | Vault of Gems | 1,450 gems, including a 20% bonus. |
| Singularity Hoard | Singularity Hoard | 4,000 gems, including a 34% bonus. |
| Piggy Bank | Piggy Bank | Smash it and collect every coin inside. |
| Remove Ads | Remove Ads | Permanently removes all interstitial ads. |
| Founder's Bundle | Founder's Bundle | 1,200 gems, a rocket skin and 3 boosts. |
| VIP Pass | VIP Pass | Double coins, +2 energy cap and no ads. |

### Review information

Every product needs a screenshot (any size; Apple only uses it for review) and a review note. The shop
screen ("Supply" tab) shows all eight products, so one screenshot of it works for each. Suggested note:

> Open the app, tap the SHOP tab. All products are listed there. No login or special account is required.

## What the app does at runtime

| Behaviour | Where |
|-----------|-------|
| Loads the catalog at launch, retries with backoff when offline | `StoreKitPurchaseService.loadCatalog()` |
| Shows the **localised** price from `Product.displayPrice` (the `$…` strings above are only a fallback) | `GameCoordinator.priceLabel(for:)` |
| Listens to `Transaction.updates` for the app's whole lifetime | `StoreKitPurchaseService.start()` |
| Finishes a transaction **only after** the grant is persisted | `GameCoordinator.grant(_:)` → `onTransaction` |
| Never grants the same transaction twice | `ShopSystem.redeem(transactionID:)` |
| Re-reads entitlements on every foreground | `GameCoordinator.appDidBecomeActive()` |
| Revokes VIP (and its +2 energy cap) when the subscription lapses or is refunded | `ShopSystem.sync(_:to:)` |
| Restore Purchases button (`AppStore.sync()`) | Shop ▸ Purchases, and Settings ▸ Purchases |
| Manage Subscription sheet | Shop VIP row when active, and Settings ▸ Manage VIP |
| Sends an `appAccountToken` with every purchase, for server-side validation later | `StoreKitPurchaseService.appAccountToken` |

## App Store review requirements already covered in the UI

- Subscription price, period and renewal terms are shown next to the VIP row (Shop ▸ Purchases).
- A **Restore Purchases** control exists — required for the non-consumables.
- Links to Terms of Use (Apple's standard EULA) and a Privacy Policy sit under the shop.

## Submission readiness

### Fixed in the project

| Item | What was wrong | Fix |
|------|----------------|-----|
| Privacy manifest | No `PrivacyInfo.xcprivacy`. `StoreKitPurchaseService` uses `UserDefaults`, a required-reason API, so the upload is rejected with **ITMS-91053 — Missing API declaration**. | Added `Starlane/Resources/PrivacyInfo.xcprivacy`: no tracking, no collected data, `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. Verified present in the archived `.app`. |
| False reference price | The Founder's Bundle showed a struck-through "$19.99 / 70% OFF" it was never sold at — a rejection risk and restricted by consumer-pricing law in several markets. | Strikethrough removed (and the unused `strike:` plumbing with it); the badge now reads "Best starter". |
| Leaderboard could read as real | Weekly ranks and duels list invented opponents with no on-screen indication. | Both now say the rivals are generated on-device. |
| App category never applied | `INFOPLIST_KEY_LSApplicationCategoryType` is ignored because `GENERATE_INFOPLIST_FILE` is `NO`. | Moved `LSApplicationCategoryType` into the real `Info.plist`. |

### Already compliant — checked, not assumed

- **Loot box odds** (guideline 3.1.1): crates disclose 65 / 25 / 8 / 2% plus the pity counter before purchase,
  and those figures match `GachaSystem.rollRarity` exactly.
- **Subscription disclosure**: price, period, renewal terms, cancellation path, Terms of Use and Privacy
  Policy links all sit next to the VIP row.
- **Restore Purchases** exists in both Shop and Settings — required for the non-consumables.
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false`.
- **App icon**: 1024×1024 universal, plus dark and tinted variants.
- **Release archive** succeeds; `MinimumOSVersion` 17.0, version 1.0.0 (1).
- **Mock ads** are labelled "Simulated ad" and the install button states nothing installs.

### Outstanding — these need you, not code

1. **Signing team.** `DEVELOPMENT_TEAM` is empty in `project.yml` and the project file. Set your Apple
   Developer Team ID; archiving for upload fails without it.
2. **Privacy Policy URL must resolve.** `LegalLinks.privacy` in `ShopScreen.swift` points at
   `https://ravosolutions.com/starlane/privacy`, which does not exist yet. The same URL goes in App Store
   Connect ▸ App Privacy. A dead link here is a routine rejection.
3. **Paid Applications Agreement** must be active with banking and tax details complete, or no product
   loads — not even in TestFlight.
4. **Create the eight products** in App Store Connect using the tables above, and attach them to the
   build in the version's *In-App Purchases* section. New products must be submitted *with* a build the
   first time or they stay in "Ready to Submit" forever.
5. **App Store Connect metadata**: screenshots (6.9" and 6.5" required), description, keywords, support
   URL, age rating questionnaire, and the App Privacy answers — "Data Not Collected" matches what the
   privacy manifest declares.
6. **Server-side validation** is not implemented; grants are local. Every purchase is verified by
   StoreKit's own signature check (`VerificationResult.verified`), which is sufficient for a local-only
   economy, but if progress ever moves to a server, validate with the App Store Server API and use the
   `appAccountToken` already being sent to match transactions to players.

## Testing

- **Simulator / local:** just Run. The scheme points at `Starlane.storekit`, so all eight products load
  with no App Store Connect involvement. Use *Debug ▸ StoreKit ▸ Manage Transactions* to refund a
  purchase, expire the subscription or force a failure, and check that the perk is withdrawn.
- **Sandbox on device:** create a Sandbox Apple Account in App Store Connect ▸ Users and Access ▸ Sandbox,
  sign into it under Settings ▸ Developer ▸ Sandbox Apple Account, and remove the scheme's StoreKit
  configuration so real sandbox products are used.
- **Renewal speed in sandbox:** a month renews every 5 minutes, and a subscription auto-renews 6 times
  before stopping — enough to watch VIP lapse and confirm the energy cap drops back.
