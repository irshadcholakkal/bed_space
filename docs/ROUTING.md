# Bedspace routing

The public Next.js page is `/`. Flutter uses path-based routing beneath `/app/`.
Each screen has its own URL; refreshing does not fall back to the dashboard.

| URL | Screen |
| --- | --- |
| `/` | Next.js landing page |
| `/#features`, `/#pricing`, `/#guides` | Landing sections |
| `/app/login` | Email/Google sign-in |
| `/app/signup?billing=annual` | Signup with selected billing cycle |
| `/app/dashboard` | Dashboard |
| `/app/rooms` | Room overview |
| `/app/rooms/manage` | Manage rooms and subrooms |
| `/app/buildings` | Manage buildings |
| `/app/tenants` | Manage tenants |
| `/app/vacant-beds` | Available beds |
| `/app/financials` | Rent, payments and expenses |
| `/app/settings` | Workspace settings |
| `/app/rooms/:roomId/expenses` | Room expenses; room is loaded by ID |
| `/app/tenants/:tenantId/rent-balance` | Tenant rent balance |
| `/app/connect-google` | Google storage connection; opens dashboard when ready |
| `/app/billing` | Membership and payment status |
| `/app/admin` | Billing administration, authorized admins only |
| `/app/auth/callback` | Alternate callback entry; normally callbacks use `/app/` |

Public shortcuts such as `/login`, `/signup`, `/dashboard`, `/rooms`, `/settings`,
`/billing`, `/admin` and room/tenant detail paths redirect to their `/app/` URLs.
`/features`, `/pricing` and `/guides` redirect to the relevant landing anchor.
Unknown pages show a not-found screen; missing JS/WASM assets remain HTTP 404.

## Access and navigation

Signed-out visitors opening a protected screen go to
`/app/login?from=<internal path>`. The intended path is retained when switching
between signup and login and across the Google OAuth round trip. Only known
internal app paths are accepted; external destinations and OAuth fields are
discarded. Signed-in users leave login/signup for their destination or dashboard.

Workspace screens still require membership and a connected Google workspace.
Providers live above the routed workspace Navigator, so screens share the same
customer data session. Direct room expense URLs load the room from that session,
not an in-memory navigation argument. Missing room IDs show not-found.

Billing is reachable for signed-in customers whose membership has expired.
Administration retains its server-checked admin authorization and does not
depend on the customer's Google storage connection. Both have a return-to-workspace
action, including when opened directly. Browser Back/Forward and the bottom
navigation update the route; page links use the router rather than anonymous
MaterialPageRoutes. Dialogs and temporary PDF previews remain transient UI.

## Compatibility and deployment

Old `/app/?view=login`, `/app/?view=signup&billing=annual`, root OAuth callbacks,
hash-style bookmarks and `?billing=return` links remain supported. New landing
buttons link directly to `/app/login` and `/app/signup`.

Keep the Supabase callback allowlist at
`https://bedspace.thepercentagecompany.com/app/`; Google still redirects to the
Supabase `/auth/v1/callback` URL. Routing does not repair invalid Google secrets.

Build with `./scripts/build_pwa.ps1` or `bash scripts/cloudflare-build.sh`.
Deploy `build/site` with the committed `wrangler.json` and `cloudflare/worker.mjs`.
The Worker routes app navigation to the Flutter shell while public pages stay
in Next.js. Do not replace it with a blanket fallback to the public index.
