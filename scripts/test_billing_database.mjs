// Test-only in-memory PostgreSQL. Install the QA dependency using PAYMOB_SETUP.md.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { PGlite } from '../.dart_tool/billing-qa/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const owner = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create table auth.users(id uuid primary key, created_at timestamptz not null default now(), raw_user_meta_data jsonb not null default '{}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to authenticated;
    grant execute on function auth.uid() to authenticated;
    set timezone = 'UTC';
  `);
  for (const file of ['202611090001_accounts.sql', '202611100001_subscriptions.sql']) {
    await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
  }
  await db.query('insert into auth.users(id) values ($1),($2)', [owner, other]);
  const account = async () => (await db.query('select public.account_access() as result')).rows[0].result;
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [owner]);
  await db.exec('set role authenticated');
  assert.equal((await account()).allowed, true, 'New customer gets a trial');
  assert.equal((await db.query('select * from public.subscriptions')).rows.length, 1, 'RLS hides other customers');
  await assert.rejects(db.query("update public.subscriptions set paid_until = now() + interval '100 years'"), /permission denied/, 'Customer cannot grant access');
  await assert.rejects(db.query("select public.settle_paymob_payment('1','1',5000,'AED',true,false,'test')"), /permission denied/, 'Customer cannot call settlement RPC');
  await db.exec('reset role');
  await db.query("update public.subscriptions set trial_ends_at = now() - interval '1 day' where user_id = $1", [owner]);
  await db.exec('set role authenticated');
  assert.equal((await account()).allowed, false, 'Expired trial blocks access');
  await db.exec('reset role');
  const order = (await db.query("insert into public.billing_orders(user_id,billing_cycle,amount_cents,mode,paymob_order_id) values ($1,'monthly',5000,'test','101') returning id", [owner])).rows[0];
  const settle = async (amount = 5000, success = true) => db.query("select public.settle_paymob_payment('101','201',$1,'AED',$2,false,'test')", [amount, success]);
  await assert.rejects(settle(1), /do not match/, 'Wrong amount never activates access');
  await settle(5000, false);
  await db.exec('set role authenticated');
  assert.equal((await account()).allowed, false, 'Failed payment does not unlock account');
  await db.exec('reset role');
  await settle();
  const paidUntil = (await db.query('select paid_until from public.subscriptions where user_id=$1', [owner])).rows[0].paid_until;
  await settle();
  assert.deepEqual((await db.query('select paid_until from public.subscriptions where user_id=$1', [owner])).rows[0].paid_until, paidUntil, 'Duplicate callback does not extend twice');
  await db.exec('set role authenticated');
  assert.equal((await account()).allowed, true, 'Verified payment restores access');
  await db.exec('reset role');
  await db.query("update public.subscriptions set paid_until='2027-01-31T12:00:00Z',trial_ends_at='2026-01-01T12:00:00Z' where user_id=$1", [owner]);
  await db.query("insert into public.billing_orders(user_id,billing_cycle,amount_cents,mode,paymob_order_id) values ($1,'annual',54000,'test','102')", [owner]);
  await db.query("select public.settle_paymob_payment('102','202',54000,'AED',true,false,'test')");
  const annual = (await db.query('select paid_until::text as paid_until from public.subscriptions where user_id=$1', [owner])).rows[0].paid_until;
  assert.match(annual, /^2028-01-31 12:00:00/, 'Annual renewal adds a calendar year to existing access');
  await db.query("select public.settle_paymob_payment('101','201',5000,'AED',true,true,'test')");
  await db.exec('set role authenticated');
  assert.equal((await account()).allowed, false, 'Refund suspends access for review');
  await db.exec('reset role');
  assert.ok(order.id);
  console.log('Billing database checks passed: trial, RLS, privileged writes, failed payments, amount validation, duplicate callbacks, monthly unlock, annual extension and refunds.');
} finally { await db.close(); }
