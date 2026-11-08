# Bed Space PWA

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
