# SaaS account setup

The Flutter app now opens on a public landing page. Customers create an email
account in Supabase, confirm their email, sign in, and connect Google Sheets
and Drive. No separate landing-page deployment is needed.

## Supabase

1. Create a Supabase project. In its SQL editor, run
   `supabase/migrations/202611090001_accounts.sql` once before accepting signups.
   Start at [Supabase](https://supabase.com/dashboard). Supabase's
   [Flutter account guide](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
   explains project keys, email redirects and row-level security.
2. Enable the email authentication provider and email confirmation. Configure
   production SMTP for customer email delivery.
3. Set the Auth Site URL to `https://rents.thepercentagecompany.com` and allow
   `https://rents.thepercentagecompany.com/` as a redirect URL. Add
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

Register two separate customer accounts, confirm their emails, and connect
different Google accounts. Verify each profile and storage binding can only be
read by its owner; test unauthenticated and cross-account requests using the
public key. Confirm both spreadsheets and folders are private in Google Drive.
Sign out and switch accounts in the same browser to check workspace isolation.
Reload and reconnect Google to verify the existing spreadsheet is reused.

This is the initial owner-only SaaS flow. Billing, staff invitations, account
deletion, password recovery UI, backend Google refresh-token management and
automatic Drive document uploads remain follow-up work. The direct Google API
path remains client-side; this does not implement the full backend architecture
in `ARCHITECTURE.md`. Supabase credentials and a live project are required for
end-to-end validation; no database changes are applied by the Flutter build.
