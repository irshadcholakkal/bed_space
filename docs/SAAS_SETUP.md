# SaaS account setup

The Flutter app now opens on a public landing page. Customers create an email
account in Supabase, confirm their email, sign in, and connect Google Sheets
and Drive. No separate landing-page deployment is needed.

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
3. Set the Auth Site URL to `https://bedspace.thepercentagecompany.com` and allow
   `https://bedspace.thepercentagecompany.com/` as a redirect URL. Add
   `http://localhost:3000/` for development.
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
