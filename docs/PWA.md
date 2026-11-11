# Bedspace landing and installable workspace

## Routes and build output

- `/`: Next.js static marketing page, immediately readable HTML. No Flutter,
  CanvasKit, database initialization or Google SDK downloads on the public page.
- `/app/`: Flutter account screens and workspace; install the PWA from this URL.
- `/app/?view=login` and `/app/?view=signup&billing=annual`: account entry points.

Run `./scripts/build_pwa.ps1` locally. It builds Flutter with base href `/app/`,
prepares the app's offline manifest, builds the Next.js static export, then
combines both into `build/site`. Intermediate outputs are `build/web` (Flutter)
and `landing/out` (Next.js). Deploy the combined output, not either intermediate.
To preview both together, run `node scripts/preview-site.mjs` and open
`http://127.0.0.1:4173`. Landing-only development is described in
[landing/README.md](../landing/README.md).

## Cloudflare Workers deployment

The existing custom domain and Worker remain in `wrangler.json`. Its asset
binding serves `build/site`; `cloudflare/worker.mjs` handles app deep-link
fallbacks. Unknown public paths and missing JS/WASM files remain genuine 404s.
Do not configure a blanket SPA fallback to the public landing page.

In **Workers & Pages > bed-space > Settings > Builds**, use:

| Setting | Value |
| --- | --- |
| Root directory | Repository folder containing pubspec.yaml and wrangler.json |
| Build command | `bash scripts/cloudflare-build.sh` |
| Deploy command | `npx wrangler deploy` |

Set build variables `NODE_VERSION=22`, `SUPABASE_URL` and
`SUPABASE_ANON_KEY` (or `SUPABASE_PUBLISHABLE_KEY`).
`SKIP_DEPENDENCY_INSTALL=true` is supported: the script restores locked Flutter
and Next.js dependencies explicitly. Flutter is installed at the exact version
specified by `FLUTTER_VERSION` (default 3.47.2). Next.js uses its committed lockfile.

A missing `build/site` error means the combined build did not complete. Check
earlier errors in the log. Cache-not-found messages are informational.
Use Workers for this combined deployment; the Worker implements app routing.
Previous Flutter-only Pages instructions pointing at `build/web` no longer apply.

## OAuth and email callback URLs

Set Supabase Authentication > URL Configuration **Site URL** to
`https://bedspace.thepercentagecompany.com/app/` and add that exact URL under
**Redirect URLs**. For local combined preview add `http://127.0.0.1:4173/app/`.
New app sign-ins and email confirmations request the app callback directly.
Keep the old root redirect allowed for previously sent links; the Next.js page
forwards legacy OAuth, email and billing return parameters to `/app/`, preserving
their query and fragment. Avoid sharing callback URLs containing codes or tokens.

Google's authorized redirect URI stays the **Supabase** callback, unchanged:
`https://wyojharbgdxtiobwxvbf.supabase.co/auth/v1/callback`. Google returns to
Supabase, which then returns to the app. See [SaaS setup](SAAS_SETUP.md) for the
matching Google Web client ID/secret and troubleshooting token exchange errors.
The Google client secret belongs only in Supabase, never in Flutter/Next builds.

Email login uses a Bedspace password, including when the email is Gmail. Enable
Email authentication in Supabase. Email users authorize Google for storage
separately. `GOOGLE_CLIENT_ID` is only required by the legacy Google-only flow.

## Caching and upgrade from the old landing page

The public Next.js page has no offline service worker. Hashed Next.js assets use
long-lived immutable cache headers; public HTML revalidates. Flutter's offline
worker is scoped to `/app/` with independent `bed-space-app-` release caches.
It validates the release manifest and rejects HTML masquerading as JS/WASM.
It fetches the app root if a navigation cache entry is evicted; offline users
without a cached shell receive a reconnect message.

A retirement worker remains at `/pwa-sw.js` for existing root-level installs.
It removes only old public app-file caches, unregisters itself, and reloads its
controlled windows. It does not clear auth sessions, IndexedDB, or local records.
Keep this migration file and `/pwa-precache.json` in releases for returning users.
After deployment, close all old Bedspace tabs and installed app windows, then
reopen. Install the new app from `/app/`; old root-level PWA shortcuts open the
marketing page. Do not clear all site data to fix caching: pending local records
may be stored there.

## Offline behavior

Only the workspace is installable/offline-capable. After its first complete
online load, static app files are cached and SQLite persists in IndexedDB.
Google sign-in, Sheets synchronization and payment operations need internet.
Printing may load an external PDF renderer. Cached releases activate after old
app windows close to avoid mixing versions.

If SQLite web dependencies change, regenerate their binaries with
`dart run sqflite_common_ffi_web:setup --force`, then rebuild. Verify the workspace
manifest, service worker scope, cache storage and IndexedDB in browser DevTools.
