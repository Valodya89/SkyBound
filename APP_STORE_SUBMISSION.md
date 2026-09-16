# Starlane — App Store submission pack

Everything needed to take this repository to a live App Store listing: the app record fields, the
metadata copy ready to paste, the privacy and age-rating answers, the eight in-app purchases, the
review notes, the build commands, and the things that are still broken.

Verified against the working tree on **17 Sep 2026** by building a clean Release archive and reading
the resulting `Starlane.app`. Anything marked **verified** was read out of that bundle, not out of a
source file.

> This revision covers the AdMob integration that landed after the first pass. Advertising changes
> the App Privacy label, the age rating and the store description, so those sections were rewritten
> rather than amended — see §6, §7 and §4.

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
| Other platforms | **All off** — no iPad, Mac, Vision Pro or watchOS | verified, see §2 |
| Orientation | Portrait only, `UIRequiresFullScreen = true` | verified |
| Appearance | Forced dark (`UIUserInterfaceStyle = Dark`) | verified |
| App Store category | Games (`public.app-category.games`) | verified `LSApplicationCategoryType` |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | verified |
| Privacy manifest | `PrivacyInfo.xcprivacy` present in the `.app` | verified |
| Uncompressed app size | ~7.5 MB | verified (was 4.2 MB before the ad SDKs) |
| AdMob app ID | `ca-app-pub-9054557293639529~8799879891` | verified `GADApplicationIdentifier` in the archive |
| Ad units | All six live (4 rewarded, 2 interstitial) | `AdUnits.swift` — no placeholders left |
| SKAdNetwork IDs | 50 | verified `SKAdNetworkItems` |
| Tracking | **Yes** — IDFA via AdMob, behind ATT | `NSUserTrackingUsageDescription` present; `NSPrivacyTracking = true` |
| Networking | The game is offline; **the ad SDKs are not**. No `URLSession` or analytics of our own, no GameKit | grepped whole tree |
| Localizations | English (U.S.) only — no string catalog exists | repo |
| Embedded frameworks | `GoogleMobileAds.framework`, `UserMessagingPlatform.framework` | verified in `.app/Frameworks` |
| Bundled third-party content | Two SIL OFL fonts (licences shipped), plus the two Google SDKs above | verified in the `.app` |

---

## 2. Where this stands

Everything that can be fixed in the codebase is fixed and verified in a clean Release archive. What
remains is account-side work in App Store Connect and AdMob.

### Fixed and verified

| Was | Now |
|---|---|
| Privacy Policy and Support URLs pointed at a domain that did not exist | Site written and **live on Netlify**; all three URLs return 200, and the privacy URL is compiled into the binary |
| `NSPhotoLibraryAddUsageDescription` missing — **Save Image** in the run-card share sheet terminated the app | Key present in `Info.plist` and `project.yml`; verified in the archive |
| Archived as universal iPhone + iPad against a portrait-only design never tested on iPad | **iPhone-only**, `UIDeviceFamily = [1]` verified. Dropped the archive from 9.4 MB to 7.5 MB. **This regressed once — see the warning below.** |
| `project.yml` had an empty `DEVELOPMENT_TEAM`, so `xcodegen generate` wiped signing | Real team `X3VVWK6698` in the spec |
| `CODE_SIGN_IDENTITY = "iPhone Developer"` (deprecated) | Removed; automatic signing governs |
| `AppIcon-1024.png` carried an alpha channel (possible **ITMS-90717**) | `render-app-icon.swift` renders into an opaque context; icon regenerated, 8-bit RGB, visually identical |
| Stale empty `SkyBound.xcodeproj/` | Deleted |
| The app would have shipped to Apple Silicon Macs and Vision Pro. `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` and `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD` were unset, and **both default to YES** | Both set to `NO`, with `SUPPORTS_MACCATALYST: NO` and `SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"`. Verified in resolved build settings and in the archive |
| AdMob app ID and all six ad units were `REPLACE_ME` placeholders | All real. App ID verified in the archived `Info.plist`; units cross-checked against the same publisher ID |
| `app-ads.txt` could never be found from a GitHub project page | Written at `docs/app-ads.txt` with the real publisher ID; serves from the domain root once you redeploy |

> ### ⚠ The iPhone-only setting regressed once, and can again
>
> `project.yml` correctly declares `TARGETED_DEVICE_FAMILY: "1"`, but the committed
> `project.pbxproj` was rewritten at 00:17 — almost certainly by Xcode writing back its defaults when
> the Google SPM packages were added — and it re-added a target-level `"1,2"`. The archive silently
> went universal again.
>
> It is fixed again and verified. **Re-check the platform gates before every upload** — any trip
> through the Xcode UI that touches target settings can reintroduce Apple's defaults:
>
> ```bash
> xcodebuild -project Starlane.xcodeproj -target Starlane -configuration Release -showBuildSettings \
>   | grep -E "TARGETED_DEVICE_FAMILY|SUPPORTS_MACCATALYST|SUPPORTS_MAC_DESIGNED|SUPPORTS_XR_DESIGNED|SUPPORTED_PLATFORMS"
> ```
>
> Expect exactly this:
>
> ```
> SUPPORTED_PLATFORMS = iphoneos iphonesimulator
> SUPPORTS_MACCATALYST = NO
> SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO
> SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO
> TARGETED_DEVICE_FAMILY = 1
> ```
>
> And in the archive, `UIDeviceFamily` must be `Array { 1 }`:
>
> ```bash
> /usr/libexec/PlistBuddy -c "Print :UIDeviceFamily" <archive>/Products/Applications/Starlane.app/Info.plist
> ```
>
> A `2` means iPad screenshots and an iPad review. A `YES` on either "Designed for" setting means the
> App Store offers the app on Macs or Vision Pro, where a portrait-locked swipe game has never been
> tested.

**Verification run:** clean Release archive, 0 errors, `** ARCHIVE SUCCEEDED **`. Both Google SDK
privacy manifests present alongside the app's own. Full test suite green.

### Remaining — App Store Connect

**1. Paid Applications Agreement.** Under Business: agreement signed, banking and tax complete.
Until it is, **no product loads at all**, in production or TestFlight — the shop renders empty and
the app logs `[Store] products missing from App Store Connect: …`.

**2. Create the eight in-app purchases and attach them to build 1.** New IAPs must be submitted
*with* a build the first time (§8). Skip this and they sit in "Ready to Submit" forever while
reviewers see an empty shop.

### Remaining — AdMob

These are account settings, not code. `ADMOB.md` has the full list; the ones that block or distort
review:

| Where | Why it matters |
|---|---|
| **Privacy & messaging ▸ European regulations** | Publish a GDPR consent message. Without it `ConsentInformation` reports ads cannot be requested in the EEA/UK, and those players see **no ads at all** |
| **Privacy & messaging ▸ ATT** | Create the IDFA explainer that precedes Apple's prompt |
| **Blocking controls ▸ Ad content rating** | Cap at G or PG to match the App Store rating. The app requests `parentalGuidance` per call, but the account-level cap is what binds |
| **App settings ▸ COPPA / target audience** | Mark as **not** directed at children — accurate here, and tagging otherwise kills personalised demand |
| **Payments** | Address verification by post, then tax and payment details. Earnings are withheld until all three are done |
| **app-ads.txt** | Redeploy the site so `/app-ads.txt` is served, then let AdMob verify it |

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
Portrait, one thumb, no account and no sign-in. The game itself plays offline. Every sound is synthesised live on your device — there is not a single audio file in the download.

—

Starlane is free to play, paid for by ads. Full-screen breaks appear between runs, and the rewarded videos are always your choice — watch one for a revive, doubled coins, gems or a wheel spin. Remove Ads and the VIP Pass both take the breaks away for good.

Coins, gems, crates, weekly ranks and duels are simulated on your device: the leaderboard rivals are generated locally, not real players. Gem packs, the Founder's Bundle, Remove Ads, the Piggy Bank and the VIP Pass are real purchases made through the App Store.

VIP Pass is an auto-renewable subscription at $6.99 per month, billed to your Apple Account. It grants double coins on every run, +2 energy capacity and no interstitials. It renews automatically unless cancelled at least 24 hours before the end of the current period; manage or cancel it in Settings › Apple Account › Subscriptions.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ravo-starlane.netlify.app/privacy/

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
| Support URL | `https://ravo-starlane.netlify.app/support/` | **Live** — verified 200 |
| Marketing URL | `https://ravo-starlane.netlify.app/` | **Live** — verified 200 |
| Privacy Policy URL | `https://ravo-starlane.netlify.app/privacy/` | **Live** — verified 200, and matches the URL compiled into the binary |

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

The app itself still collects nothing — no back end, no analytics, no crash reporter, and the player
profile is a local JSON file in Application Support. **But the Google Mobile Ads SDK does collect**,
and Apple's questionnaire covers everything in the binary, not just your own code. Answering "Data
Not Collected" with AdMob linked is a rejection, and a false privacy label besides.

Declare the categories below. They come from the SDK's own privacy manifest inside
`GoogleMobileAds.xcframework`; Google's
[data disclosure page](https://developers.google.com/admob/ios/privacy/data-disclosure) is the
authority if it changes.

| Category | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Device ID (advertising identifier) | Yes | Yes | **Yes** | Third-party advertising |
| Advertising Data | Yes | Yes | No | Third-party advertising, analytics |
| Product Interaction | Yes | Yes | No | Third-party advertising, analytics |
| Coarse Location | Yes | Yes | No | Third-party advertising, analytics |
| Crash Data, Performance Data, Other Diagnostic Data | Yes | No | No | Analytics, advertising |

Because Device ID is used for tracking, the label carries a **"Data Used to Track You"** section and
the app must show the ATT prompt — which it does, after the consent form, from
`UMPConsentService.gather()`.

`Starlane/Resources/PrivacyInfo.xcprivacy` now declares:

| Key | Value |
|---|---|
| `NSPrivacyTracking` | `true` |
| `NSPrivacyTrackingDomains` | empty — see the comment in the file; Google publishes no list, and a listed domain is hard-blocked by iOS under an ATT denial |
| `NSPrivacyCollectedDataTypes` | empty — the app collects nothing of its own; Xcode merges the SDK's manifest into the privacy report |
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
| Third-party advertising | **Yes** | Google AdMob: interstitials between runs and opt-in rewarded videos. Ad content is capped at `parentalGuidance` in `GoogleAdService.start()`; keep the AdMob blocking controls in step with whatever rating this questionnaire produces. |
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
Starlane is a single-player arcade runner. Gameplay works offline; there is no account and no analytics. The only network use is the App Store (prices and purchases) and Google AdMob, which serves the ads.

Three things that could otherwise look wrong:

1. Ads. Full-screen interstitials appear between runs, at most every other transition and never within 75 seconds of another ad. The "watch a video" buttons on the results, Supply and Daily screens are opt-in rewarded ads, and the reward is only granted when Google reports the video was watched to the reward point. The Remove Ads product and the VIP Pass both remove the interstitials permanently; the rewarded videos remain available because they are always the player's choice. Consent is collected through Google's UMP form where it is required, and the ATT prompt follows it; Settings has an "Ad privacy options" row wherever the consent form applies.

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

A **clean** Release archive was produced from the current tree, with the ad SDKs linked:
`** ARCHIVE SUCCEEDED **`, 0 errors, no `actool` icon warnings, **7.5 MB** app. Confirmed by reading
the resulting `Starlane.app`:

| Check | Result |
|---|---|
| `UIDeviceFamily` | `[1]` — iPhone only (**re-check this every upload**, see §2) |
| `GADApplicationIdentifier` | `ca-app-pub-9054557293639529~8799879891` |
| `SKAdNetworkItems` | 50 entries |
| `NSUserTrackingUsageDescription` | present |
| `NSPhotoLibraryAddUsageDescription` | present |
| Privacy manifests | the app's own, plus `GoogleMobileAds.framework` and `UserMessagingPlatform.framework` |
| Embedded frameworks | `GoogleMobileAds`, `UserMessagingPlatform` |
| Privacy URL in the binary | `https://ravo-starlane.netlify.app/privacy/` — returns 200 live |

The full test suite passes: **95 tests** — 70 core in 15 suites, 25 app-layer in 3 suites. (The test
log contains two `CoreTelephony` connection errors; those are simulator noise from the ad SDK, not
failures.)

That archive used `CODE_SIGNING_ALLOWED=NO`, so **signing is the one part of the archive path not yet
exercised end to end.** Your first real Archive from Xcode will be the first time the team ID and
provisioning profile are used together.

`actool` still writes an `AppIcon76x76@2x~ipad.png` and a `CFBundleIcons~ipad` key into the bundle.
That is an artefact of the single-size 1024 icon format and is inert — `UIDeviceFamily` is what
determines device compatibility and iPad screenshot requirements.

### Tests

```bash
xcodebuild -project Starlane.xcodeproj -scheme Starlane -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

---

## 11. Testing before you ship

### Purchases

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

### Ads

Debug builds always use Google's public **test** ad units — `AdUnits.unitID(for:)` switches on
`#if DEBUG`. This is deliberate and must stay that way: requesting, let alone tapping, a live ad from
a development build is invalid traffic and gets the AdMob account suspended.

Before shipping, confirm on a real device:

- [ ] The UMP consent form appears where required. Outside the EEA/UK, set `debug.geography = .EEA`
      in `UMPConsentService` and add your device to `AdUnits.testDeviceIdentifiers` to rehearse it.
- [ ] The ATT prompt follows the consent form, not before it.
- [ ] Declining ATT still yields ads — non-personalised ones — rather than no ads.
- [ ] A rewarded video grants its reward **only** when watched to the reward point; closing early
      grants nothing.
- [ ] An interstitial appears between runs, and not twice inside 75 seconds.
- [ ] Buying Remove Ads, or holding VIP, stops the interstitials while leaving rewarded videos.
- [ ] **Settings ▸ Ad privacy options** appears where the consent form applies, and reopens it.

A release build with no fill shows no ad and the game continues — `GoogleAdService` treats every
failure as "nothing to show" rather than blocking play. That makes a misconfigured account look like
a quiet game rather than a crash, so verify fill explicitly rather than assuming it.

---

## 12. Pre-submission checklist

**Verified in the built product — nothing to do**

- [x] Clean Release archive, zero errors
- [x] All three website URLs live and returning 200; privacy URL matches the one in the binary
- [x] AdMob app ID and all six ad units real, cross-checked against one publisher ID
- [x] `app-ads.txt` written with the real publisher ID
- [x] Three privacy manifests in the payload (app + both Google SDKs), declaring `UserDefaults` / `CA92.1`
- [x] `ITSAppUsesNonExemptEncryption = false` — no export-compliance questionnaire
- [x] `LSApplicationCategoryType` reaches the real `Info.plist`
- [x] App icon 1024×1024 with dark and tinted variants, no alpha channel
- [x] Minimum OS 17.0, version 1.0.0 (1)
- [x] iPhone-only (`UIDeviceFamily = [1]`) — **but re-verify each upload, see §2**
- [x] Not available on iPad, Mac (Catalyst or Designed-for-iPhone), Vision Pro or watchOS; embedded Google frameworks are iOS/arm64 only
- [x] `NSUserTrackingUsageDescription` and `NSPhotoLibraryAddUsageDescription` present
- [x] 50 SKAdNetwork IDs
- [x] Full test suite passes (95 tests), and the core package still tests standalone on macOS
- [x] `Starlane.storekit` is *not* bundled into the app
- [x] Crate odds shown in-app match `GachaSystem.rollRarity` exactly
- [x] Subscription price, period, renewal terms, Terms of Use and Privacy Policy links shown next to the VIP row
- [x] Restore Purchases present in both Shop and Settings
- [x] Generated rivals disclosed on the Ranks screen
- [x] AdMob behind UMP consent + ATT; interstitials gated by VIP, Remove Ads, an every-other-transition counter and a 75-second cooldown

**Needs you — AdMob**

- [ ] Publish the GDPR consent message (without it, EEA/UK players see no ads at all)
- [ ] Create the ATT explainer message
- [ ] Cap ad content rating at G or PG
- [ ] Mark the app as not directed at children
- [ ] Complete address verification, tax and payment details
- [ ] Redeploy the site so `/app-ads.txt` serves, then let AdMob verify it

**Needs you — App Store Connect**

- [ ] Activate the Paid Applications Agreement; complete banking and tax
- [ ] Confirm the name "Starlane" is available
- [ ] Register the explicit App ID `com.ravo.skybound`
- [ ] Create the app record (§3)
- [ ] Create the eight IAPs and attach them to build 1 (§8)
- [ ] Capture and upload screenshots (§5)
- [ ] Paste the metadata (§4) — note the description now describes real ads
- [ ] Fill in the App Privacy label from the table in §6 — **not** "Data Not Collected"
- [ ] Complete the age-rating questionnaire (§7), answering **Yes** to third-party advertising
- [ ] Settle the developer name: the pages say "RaVo Solutions", the contact address says *ravostudios*
- [ ] Fill in App Review information and the reviewer notes (§9)
- [ ] Upload a signed build and confirm it appears in TestFlight
- [ ] Sandbox-test a consumable, the non-consumable restore and the subscription lapse
- [ ] Test a real ad on device: consent form, ATT prompt, one rewarded video, one interstitial
- [ ] Submit for Review

---

## 13. Most likely rejection reasons for this specific app

| Risk | Guideline | Mitigation |
|---|---|---|
| Privacy Policy URL dead (site not deployed) | 5.1.1 | Blocker #1 |
| Shop empty during review (products not attached, or agreement inactive) | 2.1 | §2, App Store Connect items |
| Loot box odds not disclosed | 3.1.1 | Already handled — the odds table is on the crate screen |
| Subscription terms not visible | 3.1.2 | Already handled in-app and in the description |
| Missing Restore Purchases | 3.1.1 | Already handled |
| Simulated leaderboard read as real competition | 2.3.1 | Already disclosed on the Ranks screen; also in the review notes |
| Missing API declaration (ITMS-91053) | — | Already handled by the privacy manifest |
| App crash on Save Image | 2.1 | Fixed — Photos usage description added |
| Poor experience on iPad | 2.4.1 / 4.0 | Fixed — shipping iPhone-only |
| App icon alpha channel | ITMS-90717 | Fixed — icon regenerated without alpha |
| App Privacy label says "Data Not Collected" while AdMob is linked | 5.1.1 | Fixed in this document — use the §6 table |
| ATT prompt shown without the usage string, or IDFA used before consent | 5.1.2 | `NSUserTrackingUsageDescription` present; UMP runs before ATT |
| Ads served above the app's age rating | 1.1.4 | `maxAdContentRating = .parentalGuidance` per request — still set the account-level cap |
| EEA/UK reviewers see no ads because the consent message is unpublished | 2.1 | AdMob checklist above |
| iPad regression slips through on a later upload | 2.4.1 | Re-verify `UIDeviceFamily` before each upload (§2) |

---

## Related documents

- [ADMOB.md](ADMOB.md) — the AdMob account setup, what the ad code does, and `app-ads.txt`.
- [IAP.md](IAP.md) — the purchase implementation and StoreKit behaviour. Its screenshot sizes are out
  of date; this document is the authority there.
- [WEBSITE.md](WEBSITE.md) — deploying and editing the Privacy, Support and Marketing pages.
- [ARCHITECTURE.md](ARCHITECTURE.md) — how the app is put together.
- [README.md](README.md) — building and running.

---

*Facts in this document marked "verified" were read out of a clean Release archive built on
17 Sep 2026, not inferred from source. Where a claim could not be verified — signing, and an
`xcodegen` regeneration — that is stated at the point it matters.*
