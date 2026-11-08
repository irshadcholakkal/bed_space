# Bed Space PWA

## Deploy on Vercel

1. Push the project to your Git repository and import it in Vercel.
2. Set **Root Directory** to the folder containing `pubspec.yaml` and
   `vercel.json` (use `bed_space` if the repository contains this app in that folder).
3. Choose the **Other** framework preset. The checked-in configuration sets
   the build command to `bash scripts/vercel-build.sh` and output to `build/web`.
   No Node package installation is required.
4. Add `GOOGLE_CLIENT_ID` in **Settings > Environment Variables**, using a
   Google OAuth **Web application** client ID. Enable it for Production and,
   if needed, Preview. This is a public client ID, not a client secret.
5. Deploy. The script installs Flutter 3.47.2, restores locked dependencies,
   builds the web app and generates its PWA cache manifest. Optionally set
   `FLUTTER_VERSION` to another exact stable version after testing it locally.
6. In Google Cloud Console, add `https://YOUR-PROJECT.vercel.app` and your
   custom domain, if any, under the OAuth client's **Authorized JavaScript
   origins**. Each origin is exact; arbitrary preview URLs will not inherit
   authorization. Use your stable production domain for installed PWAs.

Vercel serves the deployment over HTTPS. The configuration revalidates static
files, prevents service-worker caching by the HTTP cache, sets the WASM MIME
type and routes extensionless app URLs to `index.html`. Missing `.js`, `.wasm`
and other file requests remain 404s rather than receiving HTML.

After deployment, open the production URL in Chrome/Edge and select **Install
app**, or use Safari's **Share > Add to Home Screen**. Check Google sign-in,
then reload offline after the first visit finishes caching. To receive an
update, close all app windows/tabs and reopen. Browser printing may load its
PDF renderer online; PDF downloads use the bundled generator.

The configuration prepares hosting; connecting the repository, setting the
OAuth client ID and deploying are done in your Vercel account.

## Local release build

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
