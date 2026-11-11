# Bed Space PWA

## Deploy on Cloudflare Workers

The repository's `wrangler.json` serves static files from `build/web`. Flutter
must generate that directory before Wrangler deploys it; it is intentionally
excluded from Git.

In **Workers & Pages > your Worker > Settings > Builds**, set:

| Setting | Value |
| --- | --- |
| Root directory | Folder containing `pubspec.yaml` and `wrangler.json` (repository root for this project) |
| Build command | `bash scripts/cloudflare-build.sh` |
| Deploy command | `npx wrangler deploy` |

Set build variables `NODE_VERSION=22`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY`.
Enable Google in Supabase and configure callback URLs as described in the
[single sign-in setup](../README.md#single-google-sign-in-supabase-deployments).
`GOOGLE_CLIENT_ID` is only needed for the legacy Google-only authentication flow.
Keep the Google client secret in Supabase, outside these public build variables.

Save the settings and retry the deployment. The build log should show Flutter
installation, `flutter build web`, and PWA preparation **before** Wrangler runs.
Messages about having no dependencies or build output to cache are informational.
An error stating that `assets.directory` does not exist means the build did not
run or did not finish successfully. Check the earlier build log for the cause.

Workers Builds requires its build command to be configured in the dashboard;
do not rely on a Wrangler custom-build setting for this Git-integrated flow.
See [Cloudflare build configuration](https://developers.cloudflare.com/workers/ci-cd/builds/configuration/).

## Deploy on Cloudflare Pages

1. Push the project to your Git repository and import it in Cloudflare Pages.
2. Create a **Pages** project under **Workers & Pages** and connect the Git
   repository. Set **Root directory** to the folder containing `pubspec.yaml`
   (leave blank if it is at the repository root).
3. Set **Framework preset: None**, **Build command:
   `bash scripts/cloudflare-build.sh`**, and **Build output directory:
   `build/web`**. No deploy command is needed for a Git-integrated Pages project.
   If the setup asks for a Workers deploy command, use the Workers instructions
   above instead. No Node package installation is required.
4. Add `GOOGLE_CLIENT_ID` in **Settings > Environment Variables**, using a
   Google OAuth **Web application** client ID. Enable it for Production and,
   if needed, Preview. This is a public client ID, not a client secret.
   Without this variable the PWA still builds, but Google sign-in is unavailable.
   Redeploy after adding or changing the variable because it is compiled into
   the Flutter web bundle.
   Set `NODE_VERSION=22` and `SKIP_DEPENDENCY_INSTALL=true`; the script installs
   Flutter dependencies itself. Configure variables for Production and Preview
   separately as needed.
5. Deploy. The script installs Flutter 3.47.2, restores locked dependencies,
   builds the web app and generates its PWA cache manifest. Optionally set
   `FLUTTER_VERSION` to another exact stable version after testing it locally.
6. In Google Cloud Console, add `https://YOUR-PROJECT.pages.dev` and your
   custom domain, if any, under the OAuth client's **Authorized JavaScript
   origins**. Each origin is exact; arbitrary preview URLs will not inherit
   authorization. Use your stable production domain for installed PWAs.

Cloudflare Pages serves the deployment over HTTPS. `web/_headers` is copied
into the output to revalidate static files and set WASM/manifest MIME types.
Pages' built-in SPA fallback serves `index.html` for unmatched paths because
the build has no top-level `404.html`. Do not add a blanket `_redirects` rule.
Missing files may also receive the SPA fallback, so check resource MIME types
when diagnosing a failed asset request.

After deployment, open the production URL in Chrome/Edge and select **Install
app**, or use Safari's **Share > Add to Home Screen**. Check Google sign-in,
then reload offline after the first visit finishes caching. To receive an
update, close all app windows/tabs and reopen. Browser printing may load its
PDF renderer online; PDF downloads use the bundled generator.

The configuration prepares hosting; connecting the repository, setting the
OAuth client ID and deploying are done in your Cloudflare Pages account.

## Local release build

Copy `.env.example` to `.env` and fill in `GOOGLE_CLIENT_ID`. Both build scripts
load `.env` and optional `.env.local` automatically (Node.js 22+ required).
Precedence: explicit PowerShell client-ID argument, process/Cloudflare Pages environment,
`.env.local`, then `.env`. Only the public Google client ID is passed to Flutter;
other keys are never included in the PWA. The files are excluded from Git and
live outside `build/web`, the only uploaded directory. In Cloudflare Pages, set
the `.env` values through **Settings >
Environment Variables** instead, then redeploy. Never upload `.env` into `web/`.

There is no backend client secret in this app. OAuth access tokens and Sheet IDs
are maintained for each signed-in user rather than shared through `.env`.

Build the installable release from the project root (Flutter and Node.js required):

```powershell
./scripts/build_pwa.ps1 -GoogleClientId 'YOUR_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com'
```

For hosting in a subdirectory, add `-BaseHref '/bed-space/'`.
The build creates `build/web`, including a content-versioned service worker and
precache manifest. Use this script for PWA releases; a plain Flutter build does
not generate the custom offline manifest.

Serve all of `build/web` over HTTPS (localhost also works). Serve `.wasm` as
`application/wasm`, `.js` as JavaScript, and `.json` as JSON. Set
`Cache-Control: no-cache` for `index.html`, `pwa.js`, `pwa-sw.js`,
`flutter_bootstrap.js`, and `pwa-precache.json` so deployments are discovered.
Register the exact deployment origin in your Google Cloud web OAuth client's
Authorized JavaScript origins. The OAuth client ID is public configuration.

In Chrome or Edge, use the address bar's install action or the browser menu's
Install app option. On iPhone/iPad, open in Safari, then Share → Add to Home Screen.
PWA caching is enabled only for prepared release builds, not `flutter run`.

The app files are cached after the first successful online visit. Browser SQLite
persists in IndexedDB. Google sign-in and Sheets synchronization still need an
internet connection; mobile background sync and local notifications do not run
in the browser. Clearing site data removes the local database and pending edits.
Updates activate after all open app windows/tabs close, then the app is reopened.

When upgrading SQLite dependencies, regenerate the browser binaries using the
Flutter SDK's Dart executable:

```powershell
dart run sqflite_common_ffi_web:setup --force
```

To check an installation in Chrome DevTools, inspect Application → Manifest,
Service workers, Cache storage, and IndexedDB. After the service worker has
installed, enable Network → Offline and reload to verify the cached app loads.

### Email sign-in and unavailable sign-in

The auth page also supports a Bedspace email/password account (including Gmail
addresses). This uses Supabase Email authentication, which must be enabled in
Authentication / Sign In / Providers. It never accepts or verifies a Google
account password. Email signup asks the user to confirm their email when email
confirmation is enabled in Supabase. Email users authorize Google separately
before opening customer-owned Sheets and Drive storage.

If the page says account sign-in is not configured, set `SUPABASE_URL` and
`SUPABASE_ANON_KEY` (or `SUPABASE_PUBLISHABLE_KEY`) under Cloudflare **Settings >
Builds > Variables and secrets**. Then rebuild and redeploy. Setting Worker
runtime variables alone cannot change Flutter's compiled configuration. The
Cloudflare build now stops early when these required public values are missing.

### Refresh or callback intermittently displays Not Found

Keep `assets.not_found_handling` set to `single-page-application` in
`wrangler.json`, and keep the custom domain bound to the same Worker. The
service worker now validates release assets before caching them and fetches
the root app shell if its local navigation cache has been evicted. Callback
query parameters stay in the browser URL for Supabase to process.

Deploy the updated release, then close all Bedspace browser tabs and installed
app windows before reopening, allowing the waiting service worker to activate.
If an older broken cache remains, use browser DevTools > Application > Service
Workers > Unregister, then reload online. Avoid clearing all site data: it can
remove pending local records and interrupt an OAuth flow in progress.
