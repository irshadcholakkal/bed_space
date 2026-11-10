# Customer accounts and subscription administration

Apply these migrations in order, once each:

1. `supabase/migrations/202611090001_accounts.sql`
2. `supabase/migrations/202611100001_subscriptions.sql`
3. `supabase/migrations/202611100002_billing_administration.sql`

Do not rerun an already-applied migration. Deploy the updated Flutter app and
`create-paymob-checkout` function after applying the third migration. Paymob
keys and webhook setup remain in [PAYMOB_SETUP.md](PAYMOB_SETUP.md).

## Authorize your administrator account

First register and confirm the email you will use as the administrator. In
Supabase SQL Editor, replace the example with that email and run:

```sql
insert into public.billing_admins(user_id)
select id from auth.users where email = 'YOUR_ADMIN_EMAIL'
on conflict (user_id) do update set enabled = true
returning user_id, enabled;
```

Only the trusted database operator can assign administrators. Email domains,
frontend environment variables and editable user metadata do not grant this
role. No account is promoted automatically. Disable an administrator by updating
their `billing_admins.enabled` to false in SQL Editor.

Reload and sign in. Authorized admins see **Administration** even when their
own workspace membership is expired. The admin page is also available at
`https://bedspace.thepercentagecompany.com/#/admin`. It checks authorization on every
RPC; knowing the URL does not grant access.

## What the admin page handles

- Customer auth ID, email, verification date, registration and last sign-in.
- Name and business profile.
- Trial, paid, unpaid, blocked and not-configured membership states.
- Monthly/annual cycle, trial end and paid-through date.
- Paymob and manually recorded payment history, including status, amounts,
  provider IDs, references and internal notes.
- An audit trail of subscription changes and manual actions.
- Search by email/name/business and filter the loaded accounts by status.
  Up to 500 matching accounts are returned; narrow search for larger datasets.
  The list refreshes every 30 seconds.

## Manual payments

Use **Record payment** only after verifying a cash/bank/offline payment was
actually received. Enter the cycle, total AED amount, unique receipt/bank
reference and optional internal notes. This does not charge a card.

The server validates the minimum base price (AED 50 monthly / AED 540 annual),
records the payment, extends access after the later of today, trial end or
existing paid-through date, and removes access blocks. A retry with the exact
same reference and amount does not grant another month/year. Reusing a reference
for different payment details is rejected. Cash discounts/partial payments are
not implemented; a payment below the plan base price cannot activate access.

Do not manually change Paymob transactions to paid. Confirm gateway payments
through the signed webhook; use manual recording for independently verified
offline payments. Refund execution and reversal of an incorrect manual payment
are not provided by this screen; block access and review the audit trail.

## Automatic changes

A verified successful Paymob webhook records the paid transaction and extends
access once. Failed/pending payments do not activate membership. Trial or paid
access becomes unpaid automatically when its server-side expiry passes; no
browser-written paid flag or scheduled expiry job is required.

The workspace checks membership periodically and on resume. Customers can view
their account details and payment history under **Membership > Account & payment
history**. They see only their own transactions and cannot read internal notes,
assign an admin role, write paid status or edit expiry dates.

**Block** is an explicit administrator restriction and is kept separate from
unpaid expiry and gateway refund suspension. An automatic callback does not
remove an admin block. **Remove block** only removes that restriction; it does
not extend an expired subscription or clear a gateway refund review. A newly
recorded, verified manual payment explicitly activates access and clears both.

Paymob renewals remain customer-initiated. This feature does not enable automatic
card debits; those require the separate recurring-gateway setup noted in
`PAYMOB_SETUP.md`. Live database changes, administrator assignment and payments
are not performed by the repository build or automated tests.
