// Node 24+ strips the TypeScript annotations; Deno environment/fetch are mocked.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { signatureInput } from '../supabase/functions/_shared/paymob.mjs';

const originalFetch = globalThis.fetch;
const env = new Map(Object.entries({ SUPABASE_URL: 'https://project.example', SUPABASE_ANON_KEY: 'public-test', SUPABASE_SERVICE_ROLE_KEY: 'server-test', PAYMOB_MODE: 'test', PAYMOB_BASE_URL: 'https://uae.paymob.com', PAYMOB_SECRET_KEY: 'sk_test_example', PAYMOB_PUBLIC_KEY: 'pk_test_example', PAYMOB_HMAC_SECRET: 'hmac-test', PAYMOB_INTEGRATION_ID: '456', PAYMOB_MONTHLY_EXTRA_CENTS: '250', PAYMOB_ANNUAL_EXTRA_CENTS: '500', APP_URL: 'https://app.example' }));
let handler;
globalThis.Deno = { env: { get: (name) => env.get(name) }, serve: fn => { handler = fn; } };
await import('../supabase/functions/create-paymob-checkout/index.ts');
const checkout = handler;
await import('../supabase/functions/paymob-webhook/index.ts');
const webhook = handler;
after(() => { globalThis.fetch = originalFetch; delete globalThis.Deno; });
const json = body => new Response(JSON.stringify(body), { headers: { 'content-type': 'application/json' } });

test('Checkout requires an authenticated customer', async () => {
  globalThis.fetch = async () => new Response('{}', { status: 401 });
  const response = await checkout(new Request('https://project.example/functions/v1/create-paymob-checkout', { method: 'POST', body: '{}' }));
  assert.equal(response.status, 401);
});
test('Administrator-blocked accounts cannot start checkout', async () => {
  globalThis.fetch = async (url) => {
    if(String(url).endsWith('/auth/v1/user'))return json({id:'00000000-0000-4000-8000-000000000001',email:'test@example.com',email_confirmed_at:'2026-11-10'});
    if(String(url).includes('/subscriptions?'))return json([{suspended:false,admin_blocked:true}]);
    assert.fail('Blocked account must not create a payment order or call Paymob');
  };
  const response=await checkout(new Request('https://project.example/functions/v1/create-paymob-checkout',{method:'POST',headers:{authorization:'Bearer test'},body:JSON.stringify({billing_cycle:'monthly',first_name:'Test',last_name:'Customer',phone:'+971500000000'})}));
  assert.equal(response.status,403);
});
test('Checkout ignores a browser amount and binds the server order to Paymob', async () => {
  const orderId = '00000000-0000-4000-8000-000000000001';
  let patched = false;
  globalThis.fetch = async (url, options) => {
    const target = String(url);
    if (target.endsWith('/auth/v1/user')) return json({ id: orderId, email: 'test@example.com', email_confirmed_at: '2026-11-10' });
    if (target.includes('/subscriptions?')) return json([{ user_id: orderId, suspended: false }]);
    if (target.includes('/billing_orders?') && options.method === 'PATCH') { patched = true; assert.equal(JSON.parse(options.body).paymob_order_id, '789'); return json([]); }
    if (target.includes('/billing_orders?')) return json([]);
    if (target.endsWith('/billing_orders')) { assert.equal(JSON.parse(options.body).amount_cents, 5250); return json([{ id: orderId }]); }
    if (target === 'https://uae.paymob.com/v1/intention/') {
      const input = JSON.parse(options.body);
      assert.equal(input.amount, 5250);
      assert.equal(input.currency, 'AED');
      assert.equal(input.notification_url, 'https://project.example/functions/v1/paymob-webhook');
      assert.equal(input.redirection_url, 'https://app.example/?billing=return');
      return json({ client_secret: 'checkout-test', intention_order_id: 789 });
    }
    throw new Error('Unexpected request');
  };
  const response = await checkout(new Request('https://project.example/functions/v1/create-paymob-checkout', { method: 'POST', headers: { authorization: 'Bearer test', origin: 'https://app.example' }, body: JSON.stringify({ billing_cycle: 'monthly', amount: 1, first_name: 'Test', last_name: 'Customer', phone: '+971500000000' }) }));
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.amount_cents, 5250);
  assert.equal(new URL(result.url).hostname, 'uae.paymob.com');
  assert.equal(result.mode, 'test');
  assert.equal(patched, true);
});
const obj = { amount_cents: 5000, created_at: '2026-11-10', currency: 'AED', error_occured: false, has_parent_transaction: false, id: 123, integration_id: 456, is_3d_secure: true, is_auth: false, is_capture: false, is_refunded: false, is_standalone_payment: true, is_voided: false, order: { id: 789, merchant_order_id: 'untrusted-reference' }, owner: 1, pending: false, source_data: { pan: '1234', sub_type: 'Visa', type: 'card' }, success: true };
test('Webhook rejects forged signatures before database access', async () => {
  globalThis.fetch = async () => { assert.fail('No database call allowed'); };
  const response = await webhook(new Request('https://project.example/functions/v1/paymob-webhook?hmac=bad', { method: 'POST', body: JSON.stringify({ type: 'TRANSACTION', obj }) }));
  assert.equal(response.status, 401);
});
test('Verified webhook settles only using signed order ID and amount', async () => {
  const signature = createHmac('sha512', 'hmac-test').update(signatureInput(obj)).digest('hex');
  let settled = false;
  globalThis.fetch = async (url, options) => {
    assert.equal(String(url), 'https://project.example/rest/v1/rpc/settle_paymob_payment');
    const input = JSON.parse(options.body);
    assert.equal(input.p_paymob_order_id, '789');
    assert.equal(input.p_amount_cents, 5000);
    assert.equal(input.p_success, true);
    assert.equal(input.p_mode, 'test');
    settled = true;
    return json('access_extended');
  };
  const response = await webhook(new Request(`https://project.example/functions/v1/paymob-webhook?hmac=${signature}`, { method: 'POST', body: JSON.stringify({ type: 'TRANSACTION', obj }) }));
  assert.equal(response.status, 200);
  assert.equal(settled, true);
});
