# SaaS account setup

The public Next.js landing page is at `/`; Flutter account screens and the
workspace are at `/app/`. Customers sign in with Google or create an email
account in Supabase and connect Google Sheets and Drive. Both are published
in the same Cloudflare deployment.

For one-month trials, AED 50 monthly / AED 540 annual pricing, membership access
and Paymob test payments, also follow [Paymob setup](PAYMOB_SETUP.md).
Apply its subscription migration before deploying the updated app.

## Supabase

1. Create a Supabase project. In its SQL editor, run
   `supabase/migrations/202611090001_accounts.sql` once before accepting signups.
   Start at [Supabase](https://supabase.com/dashboard). Supabase's
   [Flutter account guide](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
   explains project keys, email redirects and row-level security.
2. Enable the email authentication provider and email confirmation. Configure
   production SMTP for customer email delivery.
3. Set the Auth Site URL to `https://bedspace.thepercentagecompany.com/app/` and
   allow that exact URL as a redirect. Keep the old root URL allowed for old
   email links; Next.js forwards those callbacks to the app. Add
   `http://127.0.0.1:4173/app/` for combined local preview.
4. Add the following public build variables to `.env` locally and to Cloudflare
   **Builds > Variables and secrets** for production:

   ```dotenv
   SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   SUPABASE_ANON_KEY=YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY
   GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

   Never use a Supabase service-role/secret key or Google client secret.
5. Rebuild and deploy using the existing Cloudflare commands. Without Supabase
   configuration the landing page loads, but registration is disabled.

## Data boundaries

- Supabase Auth stores login identities and manages passwords and sessions.
- `profiles` stores the customer's name and business name, created by an Auth
  trigger even when email confirmation is required.
- `storage_bindings` stores the connected Google email, spreadsheet ID and
  document folder ID. Row-level security restricts rows to their account owner.
- A customer-owned spreadsheet holds buildings, rooms, beds, tenants, payments
  and expenses. New SaaS spreadsheet names include the Supabase user ID.
- A private Google Drive folder is created for documents. Invoice and receipt
  screens offer **Save copy to Drive**, alongside local download and printing.
  Each click creates a new PDF copy; there is no automatic upload or deduplication.
- New spreadsheets are no longer automatically shared with the developer.
  Previously granted Google permissions must be reviewed manually in Drive.
- SQLite caches are separated by Supabase user and spreadsheet. Legacy local
  data is not automatically imported. Google access tokens stay in memory in
  SaaS mode; Google reconnection may be needed after reloading or expiry.

## Verify before opening registration

### Verification link says Page unavailable

Check that `https://bedspace.thepercentagecompany.com/` opens without any query
parameters first. A DNS `NXDOMAIN` response means the custom hostname is missing;
the app and Supabase callback code cannot run until that hostname is restored.
In Cloudflare, open **Workers & Pages > bed-space > Settings > Domains & Routes**
and add `bedspace.thepercentagecompany.com` as a **Custom Domain**. Cloudflare
manages its DNS record and certificate. `wrangler.json` also declares the custom
domain so future deployments retain the binding; the deployment token needs
permission to manage it. The `workers.dev` fallback remains enabled.

Keep the Supabase Auth Site URL and allowed redirect URL set to
`https://bedspace.thepercentagecompany.com/`. A callback containing `?code=...` is
normal for PKCE and is handled by the Flutter SDK. Open the link in the browser
used for registration, since the code verifier is stored there. Do not clear
site storage during this step. After fixing DNS, try signing in normally; if
verification is still required, request a fresh link rather than reusing an old
or consumed code.

### Membership cannot be verified

The landing page and registration can work before the billing schema exists,
but membership validation also requires `public.subscriptions`,
`public.account_access()` and the trial trigger. Run
`supabase/check_membership_setup.sql` in Supabase SQL Editor for a read-only
check. If these are missing, apply
`supabase/migrations/202611100001_subscriptions.sql` after the accounts migration.
Do not rerun an already-applied migration blindly. The subscriptions migration
creates trial records for existing registered users as well as future signups.
If all setup checks pass but the API still reports a missing function, run
`notify pgrst, 'reload schema';` in SQL Editor to refresh the API schema cache.

The app distinguishes `MEMBERSHIP_SETUP` (missing database setup/permissions),
`MEMBERSHIP_RECORD` (no visible customer membership), `MEMBERSHIP_SESSION`
(sign-in needs renewal), and `MEMBERSHIP_CONNECTION` (lookup unavailable).
Membership is never granted locally when verification fails.

### Account isolation checks

Register two separate customer accounts, confirm their emails, and connect
different Google accounts. Verify each profile and storage binding can only be
read by its owner; test unauthenticated and cross-account requests using the
public key. Confirm both spreadsheets and folders are private in Google Drive.
Sign out and switch accounts in the same browser to check workspace isolation.
Reload and reconnect Google to verify the existing spreadsheet is reused.

This is the initial owner-only SaaS flow. Paymob checkout and subscription access
are prepared separately in `PAYMOB_SETUP.md`. Automatic card debits, staff invitations, account
deletion, password recovery UI, backend Google refresh-token management and
automatic Drive document uploads remain follow-up work. The direct Google API
path remains client-side; this does not implement the full backend architecture
in `ARCHITECTURE.md`. Supabase credentials and a live project are required for
end-to-end validation; no database changes are applied by the Flutter build.

## Google sign-in: redirect_uri_mismatch

For this project, the Google authorization request currently uses OAuth client
`70192161390-94371ulkmu9qt4i26d01vp89220rsiia.apps.googleusercontent.com` and this
exact Google callback:

```text
https://wyojharbgdxtiobwxvbf.supabase.co/auth/v1/callback
```

In Google Cloud Console > Google Auth Platform > Clients (or APIs & Services >
Credentials), open that **Web application** OAuth client and add the callback
above under **Authorized redirect URIs**, then save. The client ID and secret
in Supabase Authentication > Sign In / Providers > Google must belong to that
same client. If using a custom Supabase Auth domain, copy its actual callback
from Supabase instead.

Set `https://bedspace.thepercentagecompany.com` under Google's **Authorized
JavaScript origins**. In Supabase Authentication > URL Configuration, use
`https://bedspace.thepercentagecompany.com/` for Site URL and allowed Redirect
URLs. These are different settings: Google returns to Supabase, then Supabase
returns to Bedspace. Changing `android/app/google-services.json` cannot fix the
Supabase web OAuth callback mismatch.

After saving, start a fresh sign-in. If it still fails, Google error details
show the actual `redirect_uri` and client ID to compare exactly. See
[Supabase Google setup](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).

## Google callback: Unable to exchange external code

This error means Supabase received Google's authorization code but its
server-side token exchange failed. It is separate from app hosting and occurs
before new-user profile/trial triggers. The underlying Google token-endpoint
error appears in Supabase Authentication logs for `/callback`.

1. In Google Cloud Console > Google Auth Platform > Clients, open the **Web
   application** client used by Supabase. The last inspected live request used
   `70192161390-94371ulkmu9qt4i26d01vp89220rsiia.apps.googleusercontent.com`.
2. In Supabase Authentication > Sign In / Providers > Google, verify the client
   ID and re-enter an active **client secret from that same Web client**. A
   Firebase API key, Android OAuth client, Supabase key or client ID is not a
   Google client secret. Keep this secret only in Supabase.
3. Keep the exact Google authorized redirect URI:
   `https://wyojharbgdxtiobwxvbf.supabase.co/auth/v1/callback`.
4. Save, open the plain Bedspace home URL, and start a fresh Google sign-in.
   Do not reload or reuse the failed callback URL; codes are short-lived and
   single-use. No Flutter rebuild is needed just to update the provider secret.
5. If the problem continues, inspect the failed `/callback` Auth log for
   Google's response: `invalid_client` points to client credentials;
   `invalid_grant` calls for checking code reuse/expiry and redirect consistency.
   Network or provider failures need to be resolved from that log's specific
   error. Share only the error category, without codes, tokens or secrets.

The app now recognizes error callbacks at startup and shows a retryable sign-in
screen instead of silently returning to the landing page. This improves error
handling but cannot repair Google/Supabase server credentials.
