# Starlane website — publishing and editing

Two pages are required before the App Store will accept the app: a **Privacy Policy** and a
**Support** page. Both are written and live in `docs/`. They are served free from your existing
GitHub repository, so no domain and no hosting bill is needed.

## The URLs

Once Pages is enabled these become live. They are already hardcoded in the app and in
`APP_STORE_SUBMISSION.md`, so do not change the paths without updating both.

| Page | URL |
|---|---|
| Privacy Policy | `https://valodya89.github.io/SkyBound/privacy/` |
| Support | `https://valodya89.github.io/SkyBound/support/` |
| Landing | `https://valodya89.github.io/SkyBound/` |

The capital letters in `SkyBound` matter — GitHub Pages paths are case-sensitive.

## Turn it on (about two minutes)

1. Commit and push `docs/` to `main`.
2. Go to **github.com/Valodya89/SkyBound ▸ Settings ▸ Pages**.
3. Under *Build and deployment*, set **Source** to `Deploy from a branch`, then **Branch** to
   `main` and the folder to **`/docs`**. Save.
4. Wait a minute or two for the first build, then open both URLs in a browser and confirm they load.

This works because the repository is public. (If you ever make it private, Pages requires a paid
plan — see *Alternatives* below.)

## Before you submit: replace the placeholder email

Both pages carry `you@example.com` as the contact address. Apple requires a working contact on the
support page, so this must be a real inbox you actually read:

```bash
grep -rl "you@example.com" docs | xargs sed -i '' 's|you@example.com|YOUR_REAL_ADDRESS|g'
```

A free address is fine. If you would rather not publish a personal one, create a dedicated
`starlane.support@…` mailbox — it also keeps app mail out of your main inbox. The pages already link
to GitHub Issues as a second channel, but an email address should stay: Apple sometimes flags a
support page with no direct contact method.

Also check the developer name. Both pages and the footers say **RaVo Solutions**; that should match
the legal entity on your Apple Developer account, since it is the name shown as the rights holder.

## What is in `docs/`

```
docs/
  index.html            landing page
  privacy/index.html    Privacy Policy      → App Store Connect ▸ App Privacy
  support/index.html    Support and FAQ     → App Store Connect ▸ Support URL
  style.css             shared styling, using the game's flight-deck palette
  fonts/                the two OFL fonts, self-hosted, with their licences
  .nojekyll             serve the files as-is, no Jekyll processing
```

The fonts are copied from `Starlane/Resources/Fonts/` so the pages match the game's type. They are
self-hosted rather than loaded from Google Fonts deliberately: a privacy policy that makes
third-party requests to fetch a font is a bad look, and in some jurisdictions a real complaint. As a
result these pages load **no external resources at all**, set no cookies and run no analytics — which
is exactly what the policy claims.

## Keeping the policy honest

The privacy policy makes specific factual claims about the app. If any of these change, the page must
change with it:

| The policy says | True because |
|---|---|
| No data is collected | No `URLSession`, no `Network`, no analytics or ad SDK anywhere in the tree |
| Progress is local only | `FileProfileStore` writes JSON to Application Support |
| A random token goes to Apple with purchases | `StoreKitPurchaseService.appAccountToken`, stored in `UserDefaults` |
| Ads are simulated | `MockAdService` draws a local placeholder labelled "Simulated ad" |
| Rivals are generated on-device | `DuelSystem` / the weekly board, disclosed on the Ranks screen |
| Crate odds are 65 / 25 / 8 / 2% | `Rarity.dropRate`, matching `GachaSystem.rollRarity` |
| The app cannot read your photos | `ShareLink` only; add-only Photos access, via the system share sheet |

The last row assumes `NSPhotoLibraryAddUsageDescription` is added to `Info.plist` — see blocker #2 in
`APP_STORE_SUBMISSION.md`. It is accurate either way, but without the key the app is terminated
rather than prompting.

If you ever add analytics, a crash reporter, an ad network or cloud saves, this policy becomes false
and the App Store privacy label becomes wrong. Update both at the same time as the code.

## Editing

The pages are plain HTML with one shared stylesheet — no build step, no dependencies. Edit, push, and
Pages redeploys within a minute. To preview locally:

```bash
python3 -m http.server 8000 --directory docs
```

then open `http://localhost:8000/`. Paths are relative, so the local preview and the live site behave
identically.

## Alternatives, if you would rather not use GitHub Pages

- **Cloudflare Pages / Netlify / Vercel** — free tiers, connect the same repo, point them at `docs/`.
  You get a nicer hostname (`starlane.pages.dev`) and can attach a real domain later.
- **A real domain** — when you buy one, point it at whichever host you chose, update `LegalLinks.privacy`
  in `ShopScreen.swift`, `Starlane.storekit`, and the Support URL in App Store Connect. Keep the old
  URLs redirecting: the privacy link is baked into every shipped build, so an old version of the app
  will keep sending people to the old address for as long as anyone still has it installed.
