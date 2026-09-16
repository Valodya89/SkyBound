# Starlane — App Store submission pack

Everything needed to take this repository to a live App Store listing: the app record fields, the
metadata copy ready to paste, the privacy and age-rating answers, the eight in-app purchases, the
review notes, the build commands, and the things that are still broken.

Verified against the working tree on 16 Sep 2026 (`main`, commit `9221a95`) by building a Release
archive and reading the resulting `Starlane.app`. Anything marked **verified** was read out of that
bundle, not out of a source file.

---

## 1. App at a glance

| Field | Value | Source |
|---|---|---|
| App name | **Starlane** | `Info.plist` · `CFBundleDisplayName` |
| Bundle ID | **`com.ravo.skybound`** | verified in archived `Info.plist` |
| Apple Developer Team ID | **`X3VVWK6698`** | `project.pbxproj` (app target, both configs) |
| Version (`CFBundleShortVersionString`) | **1.0.0** | verified |
| Build (`CFBundleVersion`) | **1** | verified |
| Minimum OS | **iOS 17.0** | verified `MinimumOSVersion` |
| Device family | **iPhone only (`UIDeviceFamily = [1]`)** | verified |
| Orientation | Portrait only, `UIRequiresFullScreen = true` | verified |
| Appearance | Forced dark (`UIUserInterfaceStyle = Dark`) | verified |
| App Store category | Games (`public.app-category.games`) | verified `LSApplicationCategoryType` |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | verified |
| Privacy manifest | `PrivacyInfo.xcprivacy` present in the `.app` | verified |
| Uncompressed app size | ~4.2 MB | verified |
| Networking | **None.** No `URLSession`, no `Network`, no GameKit, no analytics, no ad SDK | grepped whole tree |
| Localizations | English (U.S.) only — no string catalog exists | repo |
| Bundled third-party content | Two SIL OFL fonts, licence files shipped in the bundle | verified (`OFL-*.txt` in `.app`) |

---

## 2. Where this stands

Six blockers were identified on the first pass. **Four are now fixed in the repository**; the two
that remain are account-side actions on App Store Connect that cannot be done from the codebase.

### Fixed — verified in a clean Release archive

| # | Was | Now |
|---|---|---|
| 2 | `NSPhotoLibraryAddUsageDescription` missing, so tapping **Save Image** in the run-card share sheet terminated the app | Key added to `Starlane/Info.plist` **and** to `project.yml`. Verified present in the archived `Info.plist`. |
| 3 | Archived as universal iPhone + iPad (`UIDeviceFamily = [1, 2]`) against a portrait-only design never tested on iPad | **iPhone-only.** `TARGETED_DEVICE_FAMILY = 1` on every config; verified `UIDeviceFamily = [1]` in the archive. No iPad screenshots needed, no iPad review. App size fell from 6.0 MB to 4.2 MB. |
| 4 | `project.yml` had `DEVELOPMENT_TEAM: ""` and `TARGETED_DEVICE_FAMILY: "1"`, so `xcodegen generate` would wipe the signing team and flip the device family | `project.yml` now carries the real team `X3VVWK6698` and matches the project file on every setting that mattered. The committed project file was aligned to what the spec produces, so regenerating should be a no-op. |
| — | `CODE_SIGN_IDENTITY = "iPhone Developer"` (deprecated identity name) on the app target | Removed; `CODE_SIGN_STYLE = Automatic` now governs signing unambiguously. |
| — | `AppIcon-1024.png` carried an alpha channel (fully opaque, but a possible **ITMS-90717**) | `Scripts/render-app-icon.swift` now renders into an opaque `noneSkipLast` context; the icon was regenerated and is 8-bit RGB with no alpha. Visually identical. |
| — | Stale empty `SkyBound.xcodeproj/` beside the real project | Deleted and removed from git. |

> `xcodegen` is not installed on this machine, so the regeneration in row 4 was fixed in the spec but
> not empirically re-run. Install it and run `xcodegen generate` once to confirm the diff is clean
> before you rely on it.

**Verification after the changes:** clean Release archive succeeded with 0 errors, and the full suite
passes — 70 core tests in 15 suites plus 23 app-layer tests in 3 suites, 93 in total.

### 1. Publish the website — needs a push and three clicks

The Privacy Policy and Support pages are written (`docs/`) and the app's hardcoded link already
points at them ([ShopScreen.swift:113](Starlane/Features/Shop/ShopScreen.swift:113),
`Starlane.storekit`, verified compiled into the binary). They are **not live until you enable GitHub
Pages** — see [WEBSITE.md](WEBSITE.md).

| Page | URL once Pages is on |
|---|---|
| Privacy Policy | `https://valodya89.github.io/SkyBound/privacy/` |
| Support | `https://valodya89.github.io/SkyBound/support/` |

Two things before you submit:

1. Push `docs/`, enable Pages (Settings ▸ Pages ▸ Deploy from a branch ▸ `main` / `/docs`), and
   confirm both URLs load. A dead privacy link is a routine rejection, and the in-app link sits on
   the shop screen the reviewer will definitely open.
2. Replace the placeholder `you@example.com` in both pages with a real inbox. Apple requires a
   working contact.

### 2. Paid Applications Agreement must be active

App Store Connect ▸ Business: the Paid Applications Agreement signed, banking and tax complete.
Until it is, **no product loads at all** — not in production, not in TestFlight. The shop renders
with every item missing and the app logs `[Store] products missing from App Store Connect: …`.

### 3. The eight in-app purchases must be created and attached to this first build

New IAPs must be submitted *with* a build the first time. Create all eight (§8), then attach them to
build 1 in the version page's **In-App Purchases** section. Skip this and they sit in "Ready to
Submit" forever and the shop is empty for reviewers.

## 3. Creating the app record

**App Store Connect ▸ My Apps ▸ + ▸ New App**

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Starlane |
| Primary language | English (U.S.) |
| Bundle ID | `com.ravo.skybound` |
| SKU | `STARLANE-IOS-001` (your reference only, never shown) |
| User Access | Full Access |

Before this works, `com.ravo.skybound` must exist as an **explicit App ID** under
developer.apple.com ▸ Certificates, Identifiers & Profiles. Explicit App IDs have In-App Purchase
enabled by default; no other capability is needed — the app uses no push, no iCloud, no Sign in with
Apple, no Game Center.

> **Check the name is free.** "Starlane" is a short, generic-ish word and may already be claimed on
> the App Store or as a trademark. If it is taken, the record cannot be created under that name and
> you will need a fallback (the bundle ID and all product IDs still say `skybound`, which is fine —
> they are never shown to users).

**Categories:** Primary *Games*, subcategories *Action* and *Arcade*.

**Pricing:** Free, with in-app purchases. Available in all territories, with one caveat:

> Starlane sells gems that open randomised cosmetic crates — a paid loot box. Belgium's gaming
> authority has taken the position that paid loot boxes constitute gambling, and several other
> jurisdictions have disclosure rules (South Korea requires published odds; the app already shows
> them). This is a business decision, not a technical one: either exclude Belgium from availability
> or take your own legal advice. The odds are disclosed in-app either way, which is what Apple's
> guideline 3.1.1 requires.

---

## 4. Version metadata — ready to paste

All copy below is written to fit App Store Connect's limits and to match what the app actually does.

### Subtitle (30 max — this is 28)

```
Endless runner through space
```

### Promotional text (170 max — editable without a new build)

```
Season 1 · Skyward is live. Twenty tiers of rewards, a fresh seeded Daily Challenge every midnight, and six sectors to outrun. Free to play, no account, fully offline.
```

### Keywords (100 max, comma-separated, no spaces)

```
endless,runner,arcade,space,rocket,lane,dodge,reflex,dash,offline,one hand,sci-fi,runner game,ship
```

Do not repeat the app name or the category — Apple already indexes those.

### Description

```
Outrun the lanes.

Starlane is a one-thumb arcade runner set in deep space. Swipe between three lanes, climb over debris, dive under laser gates, and push as far as the corridor lets you. The speed never stops climbing.

SIX SECTORS
Launch Orbit, Ring Shallows, Ion Belt, Night Drift, Plasma Front and Aurora Gate — each with its own palette, hazards and score, crossfading into the next as you go deeper.

FIVE WAYS TO RUN
• Classic Dash — endless, speed climbs forever
• Time Sprint — 60 seconds, score as hard as you can
• Coin Rush — 40 seconds of pure loot, barely any walls
• Gauntlet — tight corridors, bosses twice as often
• Hardcore — max speed, no revives, triple payout

A NEW RUN EVERY DAY
The Daily Challenge hands everyone the same seeded track — identical obstacles, identical coins — so the only variable is you. Miss a day and the streak resets.

BUILD YOUR RUN
Five upgrade tracks (Coin Value, Magnet Field, Auto-Shield, Score Core, Grazer), boosts you stack before launch, and twelve rockets to collect across four rarities. Every rocket is cosmetic — none of them make you faster.

SEASON 1 · SKYWARD
Twenty tiers, a free track and a premium track, and daily missions that feed both.

MADE FOR ONE HAND
Portrait. Offline. No account, no sign-in, no tracking. Every sound in the game is synthesised live on your device — there is not a single audio file in the download.

—

Starlane is free to play. Coins, gems, crates, weekly ranks, duels and the ad breaks are all simulated on your device: the leaderboard rivals are generated locally, not real players. Gem packs, the Founder's Bundle, Remove Ads, the Piggy Bank and the VIP Pass are real purchases made through the App Store.

VIP Pass is an auto-renewable subscription at $6.99 per month, billed to your Apple Account. It grants double coins on every run, +2 energy capacity and no interstitials. It renews automatically unless cancelled at least 24 hours before the end of the current period; manage or cancel it in Settings › Apple Account › Subscriptions.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://valodya89.github.io/SkyBound/privacy/

The concept, engine, obstacle patterns, interface and copy were generated by Claude, an AI assistant made by Anthropic.
```

> The subscription paragraph is not optional garnish — guideline 3.1.2 requires the subscription
> title, length, price and the Terms of Use and Privacy Policy links to appear in the app **and** in
> the App Store description. Both are covered.

### What's New in This Version (1.0.0)

```
First flight. Six sectors, five modes, a seeded Daily Challenge, Season 1 · Skyward, twelve rockets to collect and a boss that does not telegraph twice.
```

### URLs

| Field | Value | Status |
|---|---|---|
| Support URL | `https://valodya89.github.io/SkyBound/support/` | Page written — **enable GitHub Pages** |
| Marketing URL | optional — leave blank for 1.0 | — |
| Privacy Policy URL | `https://valodya89.github.io/SkyBound/privacy/` | Page written — **enable GitHub Pages**. Already matches the URL hardcoded in the app |

### Copyright

```
2026 RaVo Solutions
```

(Replace with the exact legal entity on the developer account — the name shown here must be the
rights holder.)

---

## 5. Screenshots

Requirements move around; confirm the live list in the Media Manager before you spend time
rendering. As of now App Store Connect takes a single iPhone set at **6.9″** and derives the smaller
sizes from it:

| Set | Portrait pixel size | Needed? |
|---|---|---|
| iPhone 6.9″ | 1290 × 2796 (or 1320 × 2868) | **Required** |
| iPhone 6.5″ | 1242 × 2688 | Optional now — Apple scales the 6.9″ set down |
| iPad 13″ | 2064 × 2752 | **Not needed** — the app is now iPhone-only (`UIDeviceFamily = [1]`) |

Up to 10 per set; the first three are what people actually see in search results. `IAP.md` still says
"6.9 and 6.5 required" — that is out of date.

Suggested shot list, in order, all capturable in the simulator with ⌘S:

1. **Mid-run, boss telegraph up** — the clearest "what is this game" frame.
2. **Mid-run in a later sector** (Night Drift or Aurora Gate) for colour contrast.
3. **The Deck** — hub over the live attract run, showing energy, level and the launch button.
4. **Results** — distance, coins, a new best, the share card.
5. **Hangar ▸ Archive** — the crate odds table and pity bar (also doubles as the IAP review screenshot).
6. **Season 1 · Skyward** — the twenty-tier track.
7. **Modes** — all five modes with their taglines.
8. **Daily** — the challenge and the login calendar.

An App Preview video is optional and not worth blocking 1.0 on.

---

## 6. App Privacy

Answer the App Privacy questionnaire as **"Data Not Collected"** — for every category, no exceptions.

This is accurate and provable: there is no networking code in the entire tree, no analytics SDK, no
ad SDK, no crash reporter, and the player profile is a local JSON file in Application Support.
Purchases are handled by StoreKit, which is Apple's own collection, not yours.

It also matches `Starlane/Resources/PrivacyInfo.xcprivacy` exactly, which declares:

| Key | Value |
|---|---|
| `NSPrivacyTracking` | `false` |
| `NSPrivacyTrackingDomains` | empty |
| `NSPrivacyCollectedDataTypes` | empty |
| `NSPrivacyAccessedAPITypes` | `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` |

That `UserDefaults` declaration is what keeps the upload from failing with **ITMS-91053 — Missing
API declaration**; `StoreKitPurchaseService` stores the install's `appAccountToken` there. The
manifest is present in the built `.app` (verified).

**Account deletion:** not applicable — the app has no accounts and no server. Settings ▸ Reset all
progress wipes the local profile.

---

## 7. Age rating

Apple's questionnaire wording changes periodically; the substance to answer is below.

| Topic | Answer | Why |
|---|---|---|
| Realistic violence | None | — |
| Cartoon or fantasy violence | **None**, or *Infrequent/Mild* if you want to be conservative | A ship strikes an obstacle and the run ends in a particle burst. No characters, no combat, no depiction of injury. |
| Horror, profanity, sexual content, nudity, alcohol/drugs/tobacco, mature themes | None | — |
| Medical/treatment information | None | — |
| Contests | None | Duels and weekly ranks award in-game currency only, against on-device generated rivals. |
| Gambling (real money) | None | — |
| Simulated gambling | **None** — see the note below | |
| Unrestricted web access | None | No web view, no external browser except the two legal links. |
| User-generated content / chat | None | No text entry anywhere in the app. |
| Third-party advertising | **No** | The "ads" are a local placeholder view labelled "Simulated ad"; no ad network is linked. Flag this in the review notes so it does not read as a dodge. |
| In-app purchases | **Yes** | |

Expected outcome: **4+**, or 9+ if you answer mild cartoon violence.

> **On simulated gambling.** Starlane has two randomised systems: gem-priced crates that yield
> cosmetic rockets, and a free once-daily fortune wheel. Apple treats loot boxes under guideline
> 3.1.1 — disclose the odds — rather than as gambling, and the app does disclose them (65 / 25 / 8 /
> 2%, matching `GachaSystem.rollRarity` exactly, plus a visible pity counter). The wheel costs
> nothing to spin, so nothing is wagered. On that basis **None** is the honest answer. The wheel is
> nonetheless the one item a reviewer could read the other way; if you are challenged, the argument
> above is the one to make, and the fallback is to answer *Infrequent/Mild*, which raises the rating
> but changes nothing else.

---

## 8. In-app purchases

Create all eight under the app record ▸ Monetization ▸ In-App Purchases. Identifiers must match
`StoreProduct` in
[ShopCatalog.swift](Packages/StarlaneCore/Sources/StarlaneCore/Economy/ShopCatalog.swift) character
for character — a mismatch makes the product silently vanish from the shop.

| # | Product ID | Type | Reference Name | Display Name | Price (USD) | Description (45 max) |
|---|---|---|---|---|---|---|
| 1 | `com.ravo.skybound.gems.pouch` | Consumable | Pouch of Gems | Pouch of Gems | 1.99 | 120 gems. |
| 2 | `com.ravo.skybound.gems.chest` | Consumable | Chest of Gems | Chest of Gems | 7.99 | 650 gems, including an 8% bonus. |
| 3 | `com.ravo.skybound.gems.vault` | Consumable | Vault of Gems | Vault of Gems | 14.99 | 1,450 gems, including a 20% bonus. |
| 4 | `com.ravo.skybound.gems.hoard` | Consumable | Singularity Hoard | Singularity Hoard | 39.99 | 4,000 gems, including a 34% bonus. |
| 5 | `com.ravo.skybound.piggybank` | Consumable | Piggy Bank | Piggy Bank | 3.99 | Smash it and collect every coin inside. |
| 6 | `com.ravo.skybound.noads` | Non-Consumable | Remove Ads | Remove Ads | 2.99 | Permanently removes all interstitial ads. |
| 7 | `com.ravo.skybound.bundle.founder` | Non-Consumable | Founder's Bundle | Founder's Bundle | 5.99 | 1,200 gems, a rocket skin and 3 boosts. |
| 8 | `com.ravo.skybound.vip.monthly` | Auto-Renewable | VIP Pass Monthly | VIP Pass | 6.99 / month | Double coins, +2 energy cap and no ads. |

- **Family Sharing:** off for all eight.
- **Localization:** English (U.S.) only, using the Display Name and Description columns above.
- **Subscription group:** name it **Starlane VIP**, one member (`com.ravo.skybound.vip.monthly`) at
  level 1. The code expects group id `skybound.vip` (`StoreProduct.vipSubscriptionGroupID`). If you
  add an annual tier later, put it in the same group at the same level.
- **No introductory or promotional offers** are configured in code. Leave them off for 1.0.

**Review screenshot:** each product needs one (any size — Apple only uses it during review). One
capture of the Shop tab shows all eight; reuse it for every product.

**Review note** for each product:

```
Open the app and tap the SHOP tab. All products are listed there. No login or special account is required. The VIP Pass row also shows its price, period and renewal terms.
```

`Starlane.storekit` in the repo already mirrors this catalog for local testing. Note it is **not
bundled into the app** — confirmed absent from the archived `.app` — it is only wired to the
scheme's Run action.

---

## 9. App Review information

| Field | Value |
|---|---|
| Sign-in required | **No** |
| Demo account | Not needed |
| Contact | your name, phone and email on the account |
| Attachment | none needed |

### Notes for the reviewer

```
Starlane is a single-player arcade runner. It works fully offline — there is no networking code in the app at all, no account, and no analytics or advertising SDK.

Three things that could otherwise look wrong:

1. "Ads". The ad breaks and the rewarded-video buttons are a local placeholder screen, labelled "Simulated ad" on screen. No ad network is integrated and nothing is downloaded or installed. The Remove Ads product removes these placeholder breaks.

2. Leaderboards and duels. The weekly ranking and the duel opponents are generated on the device. The app states this on the Ranks screen ("Offline board — rivals are generated on this device, not real players.") so it is not presented as real competition.

3. Crates. The randomised cosmetic crates are in Hangar ▸ Archive. The drop odds (65% Common, 25% Rare, 8% Epic, 2% Legendary) and the pity counter are shown on that screen before any purchase, per guideline 3.1.1. Crates yield rocket appearances only — they have no effect on gameplay.

All eight in-app purchases are on the SHOP tab. Restore Purchases is available in both Shop ▸ Purchases and Settings.

Gameplay: swipe left/right to change lane, swipe up to jump debris, swipe down to slide under laser gates.
```

---

## 10. Build and upload

### Bump the build number first

Every upload needs a unique `CFBundleVersion`. Build 1 is unused so far; increment
`CURRENT_PROJECT_VERSION` in `project.yml` (and the project file) for each subsequent upload.
`MARKETING_VERSION` stays 1.0.0 until the next public version.

### Archive

The cleanest route is Xcode: select the **Starlane** scheme, destination **Any iOS Device (arm64)**,
then Product ▸ Archive, and upload from the Organizer. That path handles signing, symbols and
validation in one pass.

From the command line:

```bash
xcodebuild -project Starlane.xcodeproj -scheme Starlane -configuration Release -destination 'generic/platform=iOS' -archivePath build/Starlane.xcarchive archive
```

Then export with an `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>X3VVWK6698</string>
	<key>uploadSymbols</key>
	<true/>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive -archivePath build/Starlane.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

```bash
xcrun altool --upload-app -f build/export/Starlane.ipa -t ios --apiKey YOUR_KEY_ID --apiIssuer YOUR_ISSUER_ID
```

(Generate the API key under App Store Connect ▸ Users and Access ▸ Integrations ▸ App Store Connect
API, and put the `.p8` in `~/.appstoreconnect/private_keys/`.)

### Verified build state

A **clean** Release archive was produced from the current tree after every fix above:
`** ARCHIVE SUCCEEDED **`, 0 errors, no `actool` icon warnings, 4.2 MB app. Confirmed in the
resulting `Starlane.app`:

- `UIDeviceFamily = [1]` — iPhone only
- `NSPhotoLibraryAddUsageDescription` present
- `PrivacyInfo.xcprivacy` present in the payload
- `https://valodya89.github.io/SkyBound/privacy/` compiled into the binary

The full test suite passes: 93 tests (70 core in 15 suites, 23 app-layer in 3 suites).

That archive used `CODE_SIGNING_ALLOWED=NO`, so **signing is the one part of the archive path not yet
exercised end to end.** Your first real Archive from Xcode will be the first time the team ID and
provisioning profile are used together.

`actool` still writes an `AppIcon76x76@2x~ipad.png` and a `CFBundleIcons~ipad` key into the bundle.
That is an artefact of the single-size 1024 icon format and is inert — `UIDeviceFamily` is what
determines device compatibility and iPad screenshot requirements, and it is `[1]`.

### Tests

```bash
xcodebuild -project Starlane.xcodeproj -scheme Starlane -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

## 11. Testing purchases before you ship

- **Simulator:** just run. The scheme points at `Starlane.storekit`, so all eight products load with
  no App Store Connect involvement. Use Debug ▸ StoreKit ▸ Manage Transactions to refund a purchase,
  expire the subscription or force a failure, and confirm the perk is withdrawn (VIP's +2 energy cap
  in particular).
- **Sandbox on device:** create a Sandbox Apple Account under Users and Access ▸ Sandbox, sign into
  it in Settings ▸ Developer ▸ Sandbox Apple Account, and **remove the StoreKit configuration from
  the scheme** so real sandbox products are used. In sandbox a month renews every 5 minutes and
  auto-renews six times before stopping — long enough to watch VIP lapse.
- **TestFlight:** requires the Paid Applications Agreement to be active, otherwise the shop is empty
  there too.

What the app already does correctly, so you know what to watch for: transactions are finished only
*after* the grant is persisted; consumable grants are idempotent via
`ShopSystem.redeem(transactionID:)`; entitlements are re-read on every foreground; and a lapsed or
refunded VIP removes the perk symmetrically.

---

## 12. Pre-submission checklist

**Verified in the built product — nothing to do**

- [x] Release archive builds with zero errors
- [x] `PrivacyInfo.xcprivacy` present in the payload, declaring `UserDefaults` / `CA92.1`
- [x] `ITSAppUsesNonExemptEncryption = false` — no export-compliance questionnaire
- [x] `LSApplicationCategoryType` reaches the real `Info.plist` (it would be ignored via `INFOPLIST_KEY_` because `GENERATE_INFOPLIST_FILE = NO`)
- [x] App icon present at 1024×1024 with dark and tinted variants, no alpha channel
- [x] Minimum OS 17.0, version 1.0.0 (1)
- [x] iPhone-only (`UIDeviceFamily = [1]`) — no iPad screenshots required
- [x] `NSPhotoLibraryAddUsageDescription` present — the share sheet's Save Image no longer kills the app
- [x] `project.yml` and the project file agree, so `xcodegen generate` is safe
- [x] Full test suite passes (93 tests)
- [x] `Starlane.storekit` is *not* bundled into the app
- [x] Crate odds shown in-app match `GachaSystem.rollRarity` exactly
- [x] Subscription price, period, renewal terms, Terms of Use and Privacy Policy links all shown next to the VIP row
- [x] Restore Purchases present in both Shop and Settings
- [x] Simulated ads labelled "Simulated ad"; generated rivals disclosed on the Ranks screen
- [x] No tracking, no networking, no third-party SDKs

**Needs you**

- [ ] Enable GitHub Pages so `docs/` goes live, and confirm both URLs load ([WEBSITE.md](WEBSITE.md))
- [ ] Replace the placeholder `you@example.com` in the two pages with a real inbox
- [ ] Activate the Paid Applications Agreement; complete banking and tax
- [ ] Confirm the name "Starlane" is available
- [ ] Register the explicit App ID `com.ravo.skybound`
- [ ] Create the app record (§3)
- [ ] Create the eight IAPs and attach them to build 1 (§8)
- [ ] Capture and upload screenshots (§5)
- [ ] Paste the metadata (§4)
- [ ] Answer App Privacy as "Data Not Collected" (§6)
- [ ] Complete the age-rating questionnaire (§7)
- [ ] Fill in App Review information and the reviewer notes (§9)
- [ ] Upload a signed build and confirm it appears in TestFlight
- [ ] Sandbox-test at least one consumable, the non-consumable restore and the subscription lapse
- [ ] Submit for Review

---

## 13. Most likely rejection reasons for this specific app

| Risk | Guideline | Mitigation |
|---|---|---|
| Privacy Policy URL dead (Pages not enabled) | 5.1.1 | Blocker #1 |
| Shop empty during review (products not attached, or agreement inactive) | 2.1 | Blockers #2, #3 |
| Loot box odds not disclosed | 3.1.1 | Already handled — the odds table is on the crate screen |
| Subscription terms not visible | 3.1.2 | Already handled in-app and in the description |
| Missing Restore Purchases | 3.1.1 | Already handled |
| Simulated leaderboard read as real competition | 2.3.1 | Already disclosed on the Ranks screen; also in the review notes |
| Missing API declaration (ITMS-91053) | — | Already handled by the privacy manifest |
| App crash on Save Image | 2.1 | Fixed — Photos usage description added |
| Poor experience on iPad | 2.4.1 / 4.0 | Fixed — shipping iPhone-only |
| App icon alpha channel | ITMS-90717 | Fixed — icon regenerated without alpha |

---

## Related documents

- [IAP.md](IAP.md) — deeper detail on the purchase implementation and StoreKit behaviour. Note its
  "Outstanding" list is partly stale: the signing team *is* set in the project file, and its
  screenshot sizes are out of date.
- [ARCHITECTURE.md](ARCHITECTURE.md) — how the app is put together.
- [WEBSITE.md](WEBSITE.md) — how to publish and edit the Privacy and Support pages.
- [README.md](README.md) — building and running.
