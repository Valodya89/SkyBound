# Starlane website — publishing and editing

Three URLs are needed before the App Store will accept the app: a **Privacy Policy**, a **Support**
page and a **Marketing** page. All three are written and live in `docs/`, and they are deployed to
**Netlify**, which is free, needs no domain and no credit card.

## The URLs

| App Store Connect field | URL |
|---|---|
| Privacy Policy URL | `https://ravo-starlane.netlify.app/privacy/` |
| Support URL | `https://ravo-starlane.netlify.app/support/` |
| Marketing URL (optional) | `https://ravo-starlane.netlify.app/` |

These are already hardcoded in the app (`LegalLinks.privacy` in `ShopScreen.swift`, and
`Starlane.storekit`), so do not change the paths without updating both.

## Deploy (about two minutes, no git)

1. Go to **[app.netlify.com/drop](https://app.netlify.com/drop)**.
2. Drag the **`docs` folder** onto the drop zone. It goes live immediately at a random address like
   `stellar-marzipan-4f2a91.netlify.app`.
3. Sign in when prompted (email, Google or GitHub) to keep the deploy — an unclaimed drop expires.
4. **Site configuration ▸ Change site name** → `ravo-starlane`, which gives
   `https://ravo-starlane.netlify.app`.
5. Open all three URLs above and confirm they load.

The site is plain static HTML with relative links throughout, so it works at a domain root, in a
subdirectory, or opened from disk. There is no build step and no configuration file — Netlify serves
`privacy/index.html` at `/privacy/` automatically.

### Redeploying after an edit

Drag the `docs` folder onto the site's **Deploys** tab. Each drop is a new immutable deploy and the
URL stays the same; the previous version stays available for rollback.

## app-ads.txt

Once AdMob gives you a publisher ID, save the line from AdMob ▸ Apps ▸ app-ads.txt as
`docs/app-ads.txt` and redeploy. It will be served at `https://ravo-starlane.netlify.app/app-ads.txt`,
which is exactly where the crawler looks now that the site sits at a domain root.

**Do not deploy a placeholder version of that file.** An `app-ads.txt` that exists but declares no
authorised sellers is read as "nobody may sell this inventory" and suppresses demand outright —
worse than having no file. See [ADMOB.md](ADMOB.md).

## What is in `docs/`

```
docs/
  index.html            marketing / landing page  → Marketing URL
  privacy/index.html    Privacy Policy            → App Privacy
  support/index.html    Support and FAQ           → Support URL
  style.css             shared styling, using the game's flight-deck palette
  fonts/                the two OFL fonts, self-hosted, with their licences
```

The fonts are copied from `Starlane/Resources/Fonts/` so the pages match the game's type. They are
self-hosted rather than loaded from Google Fonts deliberately: a privacy policy that calls a third
party to fetch a font undercuts itself, and in some jurisdictions is a real complaint. The pages load
**no external resources at all**, set no cookies and run no analytics — which is exactly what the
policy claims.

Contact address on the pages: **info.ravostudios@gmail.com**.

## Keeping the policy honest

The privacy policy makes specific factual claims about the app. Each was verified against the code;
if any of them change, the page must change with it:

| The policy says | True because |
|---|---|
| The game itself collects nothing | No back end; `FileProfileStore` writes JSON to Application Support |
| A random token goes to Apple with purchases | `StoreKitPurchaseService.appAccountToken` |
| Ads come from Google AdMob | `GoogleAdService` on the Google Mobile Ads SDK |
| Consent form precedes the ATT prompt | `UMPConsentService.gather()` — UMP first, then ATT |
| Declining ATT still shows untargeted ads | `canRequestAds` derives from UMP, not from ATT |
| Ad content capped at parental guidance | `configuration.maxAdContentRating = .parentalGuidance` |
| Remove Ads / VIP drop the breaks, rewarded videos stay | `guard !p.isVIP, !p.adsRemoved` gates only interstitials |
| Rivals are generated on-device | `DuelSystem` and the weekly board, disclosed on the Ranks screen |
| Crate odds are 65 / 25 / 8 / 2% | `Rarity.dropRate`, matching `GachaSystem.rollRarity` |
| The app cannot read your photos | `ShareLink` only; add-only Photos via the system share sheet |

If analytics, a crash reporter, another ad network or cloud saves are ever added, this policy and the
App Store privacy label both become false. Update them in the same change as the code.

## Moving to a real domain later

Buy the domain, add it under **Domain management** in Netlify, then update:

- `LegalLinks.privacy` in `ShopScreen.swift`
- `policyURL` in `Starlane.storekit`
- the three URLs in App Store Connect
- `docs/privacy/index.html`, which names Netlify as the host

Keep `ravo-starlane.netlify.app` alive and redirecting. The privacy URL is compiled into every shipped
build, so an old version of the app will keep sending people there for as long as anyone has it
installed.
