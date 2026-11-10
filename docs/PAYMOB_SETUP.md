# Paymob test payments and membership access

For customer account details, manual cash/bank payment recording and paid/unpaid
administration, also apply the third migration and follow
[Billing administration](BILLING_ADMIN.md).

## Product rules implemented

- One calendar month free from Supabase account creation.
- Monthly base price: **AED 50 + other charges**.
- Annual base price: **AED 540 + other charges**, 10% below AED 600.
- Trial/paid access expires according to Supabase server time. An expired account
  can sign in to pay, but the application workspace is paused.
- A verified successful Paymob payment adds one calendar month or year after
  the later of today, trial expiry or existing paid expiry. Duplicate callbacks
  do not add time twice. A failed payment does not add time.
- Refund/void callbacks for a previously settled transaction suspend the account
  for review. Support must resolve suspension before further checkout.
- Other charges are configured explicitly on the server, not supplied by the
  browser. The checkout review shows the total before opening Paymob.

## Where to put keys

**Flutter `.env` / Cloudflare build variables:** only `SUPABASE_URL`,
`SUPABASE_ANON_KEY` (public publishable/anon key), and `GOOGLE_CLIENT_ID`.

**Supabase > Edge Functions > Secrets:** the Paymob server settings below.
For local storage, copy `supabase/functions/.env.example` to
`supabase/functions/.env`. This local file is ignored by Git and is never
included by the Flutter build allowlist.

```dotenv
PAYMOB_MODE=test
PAYMOB_BASE_URL=https://uae.paymob.com
PAYMOB_SECRET_KEY=YOUR_PAYMOB_TEST_SECRET_KEY
PAYMOB_PUBLIC_KEY=YOUR_PAYMOB_TEST_PUBLIC_KEY
PAYMOB_HMAC_SECRET=YOUR_PAYMOB_HMAC_SECRET
PAYMOB_INTEGRATION_ID=YOUR_TEST_CARD_INTEGRATION_ID
APP_URL=https://bedspace.thepercentagecompany.com
PAYMOB_MONTHLY_EXTRA_CENTS=0
PAYMOB_ANNUAL_EXTRA_CENTS=0
```

Amounts use fils: `250` means AED 2.50. The explicit zero values are for test
setup; decide your actual additional charges before production. Test and live
keys/integration IDs must match. Supabase provides `SUPABASE_URL`,
`SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` to deployed functions;
never put the service-role key in the frontend.

## Database and function deployment

1. In Supabase SQL Editor, run `202611090001_accounts.sql` if not already applied,
   then `supabase/migrations/202611100001_subscriptions.sql` once. Existing
   customers get a trial ending one month after their original signup date.
2. Set the server secrets above in Supabase, or use these commands with your
   ignored server `.env` file:

   ```powershell
   npx supabase login
   npx supabase secrets set --env-file supabase/functions/.env --project-ref YOUR_PROJECT_REF
   npx supabase functions deploy create-paymob-checkout --project-ref YOUR_PROJECT_REF
   npx supabase functions deploy paymob-webhook --project-ref YOUR_PROJECT_REF
   ```

   Keep `supabase/config.toml`: checkout validates the customer JWT using
   Supabase Auth; the webhook validates Paymob HMAC. Platform JWT verification
   is disabled for these two handlers so the provider callback can reach it.
3. Deploy the updated Flutter PWA using the existing Cloudflare build/deploy
   commands. Missing subscription schema fails closed at membership validation.

## Test URLs / callbacks

Replace `YOUR_PROJECT_REF` with the identifier in your Supabase project URL.

| Purpose | Address |
|---|---|
| Signed-in payment-link creation (POST) | `https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-paymob-checkout` |
| Paymob processed callback (POST) | `https://YOUR_PROJECT_REF.supabase.co/functions/v1/paymob-webhook` |
| Browser return | `https://bedspace.thepercentagecompany.com/?billing=return` |
| Hosted test checkout | Created dynamically by Paymob after test keys are configured |

In Paymob's test card integration settings, set the processed callback to the
webhook address and the response callback to the browser return. The intention
request also includes both URLs. Paymob appends `?hmac=...` to the processed
callback. No HMAC is hardcoded in the configured callback URL.

Open **Membership** after signing in, choose monthly/annual, enter billing name
and international phone, and continue. The app shows the server-calculated AED
total and a test-mode label before sending you to Paymob. A hosted checkout URL
cannot be generated until real test credentials are added; no fake successful
payment links or unauthenticated unlock endpoints are included.

## Payment verification and renewal scope

The webhook verifies the transaction HMAC, integration, signed Paymob order ID,
amount, currency, completed payment flags and server mode. An atomic SQL RPC
settles the order and extends access. Browser return parameters never unlock
an account. Payment pages collect card details at Paymob, not in Flutter.

This version uses **customer-initiated monthly/yearly renewal payments**.
It does not automatically debit saved cards. Paymob recurring subscriptions
require merchant enablement and account-specific plan/integration setup. The
published day-based frequencies must be reconciled with the calendar-month/year
product rules before enabling auto-debit; do not silently substitute a 360-day
cycle for an advertised calendar year.

Workspace UI and Supabase storage-reference policies enforce membership. The
existing client-side Google API path remains in place: this does not revoke a
customer's access to their own Google files or implement the complete backend
Google API enforcement planned in `ARCHITECTURE.md`.

## Verification before live payments

Use a staging Supabase project with Paymob test keys. Test success, decline,
abandoned checkout, repeated callbacks, wrong signature, wrong amount, expired
trial, renewal and annual pricing. Returning to the app before a webhook arrives
must not unlock access; use **Already paid? Check payment status** to refresh.
Test callbacks must never be used to activate production customer accounts.

Local checks (Node.js 24+ for the TypeScript endpoint mocks):

```powershell
node --test test/paymob.test.mjs test/paymob_endpoints.test.mjs
npm install --prefix .dart_tool/billing-qa @electric-sql/pglite --ignore-scripts --no-audit --no-fund
node scripts/test_billing_database.mjs
npx deno check --no-lock supabase/functions/create-paymob-checkout/index.ts supabase/functions/paymob-webhook/index.ts
```

No live payment, Supabase deployment or gateway account configuration is performed
by these tests. Paymob test checkout and live delivery need your credentials.

References: [Paymob intentions](https://developers.paymob.com/paymob-docs/intention-apis/create-intention),
[transaction callbacks](https://developers.paymob.com/paymob-docs/developers/transaction-callbacks),
[HMAC](https://developers.paymob.com/paymob-docs/developers/webhook-callbacks-and-hmac/hmac),
[Supabase function configuration](https://supabase.com/docs/guides/functions/function-configuration).
