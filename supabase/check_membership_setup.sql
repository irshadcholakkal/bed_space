-- Read-only diagnostic. Run in Supabase SQL Editor before reapplying migrations.
select
  to_regclass('public.subscriptions') is not null as subscriptions_table_exists,
  to_regprocedure('public.account_access()') is not null as membership_function_exists,
  exists (
    select 1 from pg_trigger
    where tgname = 'start_customer_trial' and not tgisinternal
  ) as trial_trigger_exists;

-- If any check is false, apply the missing migrations in order:
-- 1. migrations/202611090001_accounts.sql (if accounts schema is not installed)
-- 2. migrations/202611100001_subscriptions.sql
-- The subscription migration also backfills trials for existing auth users.
