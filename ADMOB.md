# AdMob

Everything that used to draw the "Simulated ad" placeholder now goes through Google AdMob. The code
is finished and builds; what is left is account work that only you can do — creating the app and its
ad units in the AdMob dashboard, then pasting the IDs into two files.

Until you do, nothing breaks: **Debug builds always use Google's test units**, and a Release build
with unreplaced IDs simply shows no ads rather than serving test creatives to players.

---

## 1. What to create in the AdMob dashboard

### The app

AdMob ▸ **Apps ▸ Add app ▸ iOS**. The app is not on the App Store yet, so answer "No" to "Is your app
listed on a supported app store?" and link it later — an unlinked app serves at a reduced rate, so
come back and link it the day 1.0 goes live.

That gives you an **app ID** shaped `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (tilde). It goes in
[project.yml](project.yml), under the `Release` config:

```yaml
      configs:
        Debug:
          ADMOB_APP_ID: ca-app-pub-3940256099942544~1458002511
        Release:
          ADMOB_APP_ID: <your app ID here>
```

Then `xcodegen generate`. The value is written into `Info.plist` as `GADApplicationIdentifier`; the
SDK throws on launch if it is missing or malformed, so don't blank it out.

### The six ad units

One unit per placement. They cost nothing extra and they are the only way to see which surface
actually earns — a revive video and a shop video have very different values, and a single shared unit
hides that. Create each under **Apps ▸ Starlane ▸ Ad units ▸ Add ad unit**.

| # | Format | Name to use in AdMob | Where it appears in the game | `AdPlacement` case |
|---|---|---|---|---|
| 1 | Rewarded | `Starlane · Rewarded · Revive` | Results screen, "Revive" | `.revive` |
| 2 | Rewarded | `Starlane · Rewarded · Double Coins` | Results screen, "2× coins" | `.doubleCoins` |
| 3 | Rewarded | `Starlane · Rewarded · Free Gems` | Supply, "Free gems · Watch" (3×/day) | `.freeGems` |
| 4 | Rewarded | `Starlane · Rewarded · Wheel Spin` | Daily, paid fortune-wheel spin | `.wheelSpin` |
| 5 | Interstitial | `Starlane · Interstitial · Run End` | "Play again" between runs | `.runEnd` |
| 6 | Interstitial | `Starlane · Interstitial · Return To Hub` | Leaving results for the hub | `.returnToHub` |

Settings per unit:

- **Rewarded units** ask for a reward item and amount. Put `reward` / `1` and leave it — the game
  ignores the value the SDK reports and uses its own economy constants
  (`DailySystem.freeGemAdReward`, the run's coin total, and so on). A rewarded unit that trusted the
  dashboard would let anyone with a proxy rewrite your economy.
- **Frequency capping**: leave it off on the rewarded units (the player asked for those). On the two
  interstitial units, a cap of roughly 1 per 2 minutes is a sensible backstop; the app already
  enforces its own gate, described below.
- Leave **eCPM floors** alone until you have a few weeks of data.

Each unit gives you an ID shaped `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` (slash). Paste them into
the `production` table in [AdUnits.swift](Starlane/Services/AdUnits.swift), replacing `placeholder`.

### Account settings that are not optional

| Where | What to do |
|---|---|
| **Privacy & messaging ▸ European regulations** | Create and **publish** a GDPR consent message. Without it, `ConsentInformation` reports that ads cannot be requested in the EEA/UK and those users see nothing at all. |
| **Privacy & messaging ▸ ATT** | Create the IDFA explainer message. The app shows Apple's prompt itself, after the consent form; this message is the screen that precedes it. |
| **Privacy & messaging ▸ Test devices** | Add your iPhone so you can rehearse the consent form from outside Europe. |
| **Blocking controls ▸ Ad content rating** | Cap at **G** or **PG** to match the 4+/9+ App Store rating. The app also asks for `parentalGuidance` on every request, but the account-level cap is what actually binds. |
| **App settings ▸ COPPA / target audience** | Mark Starlane as **not** directed at children. It is a general-audience game outside the Kids category; tagging it as child-directed kills personalised demand and is not accurate here. |
| **Payments** | Address verification (a PIN arrives by post), then tax details and a payment method. Earnings are held until all three are done. |
| **app-ads.txt** | See below — the path problem is gone now the site is at a domain root. |

### app-ads.txt

AdMob crawls `https://<developer domain>/app-ads.txt`, where the domain comes from the developer
website on your App Store listing. The site is hosted at the root of `ravo-starlane.netlify.app`, so the
file lands exactly where the crawler looks:

```
https://ravo-starlane.netlify.app/app-ads.txt
```

(This was a real problem while the site was a GitHub *project* page: it served from
`valodya89.github.io/SkyBound/`, so the file could only ever appear at `/SkyBound/app-ads.txt` — a
path the crawler never checks. Moving to Netlify removed the obstacle.)

It is advisory rather than blocking — ads serve without it — but some buyers will not bid on
unverified inventory, so publish it once you have the publisher ID. Copy the line from AdMob ▸ Apps ▸
app-ads.txt:

```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

Save that as `docs/app-ads.txt` and redeploy.

> **Do not deploy a placeholder version of this file.** An `app-ads.txt` that exists but declares no
> authorised sellers is read as "nobody may sell this inventory" and suppresses demand outright —
> strictly worse than having no file. Publish it only once the real publisher ID is in it. For the
> same reason the file is deliberately absent from the site bundle today.

---

## 2. What the code does

### Where ads appear

| Placement | Trigger | Code |
|---|---|---|
| `.revive` | Results ▸ Revive | `GameCoordinator.revive()` |
| `.doubleCoins` | Results ▸ 2× coins | `GameCoordinator.doubleCoins()` |
| `.freeGems` | Supply ▸ Free gems | `GameCoordinator.watchFreeGemAd()` |
| `.wheelSpin` | Daily ▸ paid spin | `GameCoordinator.spinWheel(free: false)` |
| `.runEnd` | Play again | `GameCoordinator.playAgain()` |
| `.returnToHub` | Back to the hub | `GameCoordinator.returnToHub()` |

### When an interstitial is allowed

All four conditions must hold (`GameCoordinator.maybeInterstitial`):

1. the player is not VIP and has not bought Remove Ads;
2. no other ad is on screen or loading;
3. at least **75 seconds** since the last full-screen ad of any kind — which also stops an
   interstitial landing straight after a rewarded video;
4. it is an even-numbered eligible transition (every other one).

### When a reward is paid

A rewarded video pays out only when the SDK reports the reward point was reached. Closing early is
`.abandoned`: the player gets a "Closed too early — no reward" toast and nothing else.

If **no ad is available at all** — no fill, no network, consent withheld, unit not configured — the
outcome depends on what the placement hands out (`AdPlacement.grantsWhenUnavailable`):

- **Revive and 2× coins pay out anyway.** Both give away something that costs you nothing, and
  refusing a revive because Google had no inventory punishes the player for Google's problem.
- **Free gems and the wheel spin do not.** Those are hard currency the shop sells, so they stay
  locked to a real impression.
- Interstitials never block anything: the game continues either way.

### Consent, in order

`UMPConsentService.gather()` runs once, when the launch splash clears:

1. `requestConsentInfoUpdate` — asks Google whether this user needs a form;
2. `loadAndPresentIfRequired` — shows the GDPR/US-state form where it applies, and returns
   immediately where it does not;
3. Apple's **ATT** prompt, but only if the status is still `.notDetermined` and the app is frontmost.

Google requires its form before the ATT prompt, and it is also the right order for opt-in rates. If
any step fails the game carries on: the SDK falls back to non-personalised ads rather than none.

Where the law requires a standing way to change that decision, Settings grows an **Ad privacy
options** row (`GameCoordinator.showsPrivacyOptions`). It is hidden everywhere else.

### Preloading

An ad requested at the moment it is needed makes the button feel broken. So:

- a run launching warms `.revive` and `.doubleCoins`, plus the interstitials if the next transition
  is going to show one (`preloadRunAds`);
- opening Supply warms `.freeGems`; opening Daily warms `.wheelSpin`;
- every presentation warms its own replacement on the way out.

A failed load backs off — 2, 4, 8 … up to 64 seconds — so a plane-mode session does not sit in a
request loop. A player tapping "watch" bypasses the backoff and gets the `AdLoadingOverlay` while the
request runs.

### Files

| File | Role |
|---|---|
| [AdService.swift](Starlane/Services/AdService.swift) | `AdPlacement`, `AdOutcome`, the protocol, and the simulated service used by previews and tests |
| [AdUnits.swift](Starlane/Services/AdUnits.swift) | **The IDs you have to fill in.** Test units in Debug, production in Release |
| [GoogleAdService.swift](Starlane/Services/GoogleAdService.swift) | Load, cache, present, back off, report the outcome |
| [ConsentService.swift](Starlane/Services/ConsentService.swift) | Protocol plus the no-op used in previews |
| [UMPConsentService.swift](Starlane/Services/UMPConsentService.swift) | The real UMP + ATT flow, and the view-controller lookup |
| [GameCoordinator.swift](Starlane/App/GameCoordinator.swift) | Every call site, the interstitial gate, the reward rules |

---

## 3. Testing before you ship

- **Test ads**: automatic in Debug. Simulators always count as test devices; for a physical device in
  a Release build, add the hash the SDK prints on first launch to `AdUnits.testDeviceIdentifiers`.
- **Never tap a live ad in your own app.** It is invalid traffic and it gets accounts suspended.
- **Rehearse the consent form** from anywhere: set `debug.geography = .EEA` in
  `UMPConsentService.requestConsentInfoUpdate()` and list your device in the AdMob test devices.
- **Rehearse ATT twice**: allow once, then delete the app, reinstall and deny. Personalised and
  non-personalised requests are different paths.
- **Rehearse an empty network**: airplane mode, then try each of the four rewarded buttons. Revive
  and 2× coins should still pay; gems and the wheel should refuse with a toast.
- **Rehearse the purchases**: buy Remove Ads, confirm the interstitials stop and the rewarded videos
  keep working. Then restore on a second device.
- `xcodebuild … test` covers the reward rules (`AppLayerTests`: gems paid on completion, nothing paid
  on an abandoned video, no interstitial for a Remove Ads owner).

## 4. Before the first App Store build

- [ ] Real app ID in `project.yml` ▸ `Release` ▸ `ADMOB_APP_ID`, then `xcodegen generate`
- [ ] Six real unit IDs in `AdUnits.swift`
- [ ] GDPR message and ATT message published in AdMob
- [ ] Ad content rating capped in AdMob's blocking controls
- [ ] App Privacy answers in App Store Connect updated to cover the SDK's collection — the table in
      [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md) §6
- [ ] Payment and tax details completed in AdMob
- [ ] AdMob app linked to the App Store listing once 1.0 is live
