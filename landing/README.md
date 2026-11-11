# Bedspace public landing

Next.js statically exports the public marketing page. The existing Flutter
workspace lives at `/app/`; plain anchors intentionally do not prefetch it.
No Supabase client, Flutter engine, CanvasKit or app database code is imported
by the landing page. Content remains readable before JavaScript executes.

```powershell
npm ci --prefix landing
npm run dev --prefix landing
```

The dev command defaults to `http://127.0.0.1:3000`. It previews only the landing
page. To test account links and callbacks, build the combined site:

```powershell
./scripts/build_pwa.ps1
node scripts/preview-site.mjs
```

Combined preview: `http://127.0.0.1:4173`. Cloudflare serves `build/site`, assembled
from `landing/out` and `build/web`. See [deployment setup](../docs/PWA.md).

`npm run build` converts the shared landscape images to desktop/mobile WebP,
copies the existing Hedvig serif and a compact Inter WOFF2 font, then exports
HTML/CSS/JS to `out`. Do not commit generated media, `.next`, `out` or node_modules.

The small client islands handle billing selection, workflow controls, role tabs
and legacy callback/service-worker migration. Guide disclosures work as native
HTML without JavaScript. Reduced motion and keyboard focus styles are included.
