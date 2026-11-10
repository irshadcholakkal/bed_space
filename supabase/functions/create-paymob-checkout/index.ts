import { database, required } from '../_shared/backend.ts';
import { amountFor } from '../_shared/paymob.mjs';

Deno.serve(async (request: Request) => {
  const appUrl = Deno.env.get('APP_URL') || 'https://rents.thepercentagecompany.com';
  const origin = new URL(appUrl).origin;
  const headers = { 'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json',
    'Cache-Control': 'no-store' };
  const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed' }, 405);
  if (request.headers.get('origin') && request.headers.get('origin') !== origin) return reply({ error: 'Origin not allowed' }, 403);
  let orderId: string | undefined;
  try {
    const auth = await fetch(`${required('SUPABASE_URL')}/auth/v1/user`, {
      headers: { apikey: required('SUPABASE_ANON_KEY'), Authorization: request.headers.get('authorization') || '' },
    });
    if (!auth.ok) return reply({ error: 'Sign in before continuing to payment.' }, 401);
    const user = await auth.json();
    if (!user.email || !user.email_confirmed_at) return reply({ error: 'Confirm your email before paying.' }, 403);
    const input = await request.json();
    if (!['monthly', 'annual'].includes(input.billing_cycle)) return reply({ error: 'Choose monthly or annual billing.' }, 400);
    if (typeof input.phone !== 'string' || !/^\+[1-9]\d{7,14}$/.test(input.phone)) return reply({ error: 'Enter a phone number with country code.' }, 400);
    const firstName = String(input.first_name || '').trim();
    const lastName = String(input.last_name || '').trim();
    if (!firstName || !lastName || firstName.length > 50 || lastName.length > 50) return reply({ error: 'Enter your first and last name.' }, 400);
    const mode = Deno.env.get('PAYMOB_MODE') || 'test';
    const secret = required('PAYMOB_SECRET_KEY');
    const publicKey = required('PAYMOB_PUBLIC_KEY');
    required('PAYMOB_HMAC_SECRET');
    if (!['test', 'live'].includes(mode) || !secret.startsWith(`sk_${mode}_`)) throw new Error('Paymob mode/key mismatch');
    const base = required('PAYMOB_BASE_URL');
    if (!['https://uae.paymob.com', 'https://accept.paymob.com', 'https://ksa.paymob.com', 'https://oman.paymob.com'].includes(base)) throw new Error('Invalid Paymob region');
    const integration = Number(required('PAYMOB_INTEGRATION_ID'));
    if (!Number.isSafeInteger(integration) || integration <= 0) throw new Error('Invalid integration ID');
    const amount = amountFor(input.billing_cycle, required(input.billing_cycle === 'annual' ? 'PAYMOB_ANNUAL_EXTRA_CENTS' : 'PAYMOB_MONTHLY_EXTRA_CENTS'));
    const subscriptions = await database(`subscriptions?user_id=eq.${user.id}&select=user_id,suspended,admin_blocked`);
    if (subscriptions.length !== 1) throw new Error('Apply subscription migration before checkout');
    if (subscriptions[0].suspended || subscriptions[0].admin_blocked) return reply({ error: 'Please contact support to review your account before making another payment.' }, 403);
    const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const recent = await database(`billing_orders?user_id=eq.${user.id}&created_at=gte.${encodeURIComponent(since)}&select=id&limit=5`);
    if (recent.length >= 5) return reply({ error: 'Please wait a few minutes before requesting another payment link.' }, 429);
    const orders = await database('billing_orders', { method: 'POST', body: JSON.stringify({ user_id: user.id, billing_cycle: input.billing_cycle, amount_cents: amount, mode }) });
    orderId = orders[0].id;
    const callback = `${required('SUPABASE_URL')}/functions/v1/paymob-webhook`;
    const response = await fetch(`${base}/v1/intention/`, {
      method: 'POST', headers: { Authorization: `Token ${secret}`, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(20000),
      body: JSON.stringify({ amount, currency: 'AED', payment_methods: [integration],
        items: [{ name: input.billing_cycle === 'annual' ? 'Bedspace annual membership' : 'Bedspace monthly membership', amount, quantity: 1 }],
        billing_data: { first_name: firstName, last_name: lastName, email: user.email, phone_number: input.phone, country: 'AE' },
        special_reference: orderId, expiration: 3600,
        notification_url: callback, redirection_url: `${origin}/?billing=return`,
      }),
    });
    if (!response.ok) throw new Error('Paymob intention failed');
    const intention = await response.json();
    if (!intention.client_secret || !intention.intention_order_id) throw new Error('Invalid intention response');
    await database(`billing_orders?id=eq.${orderId}`, { method: 'PATCH', body: JSON.stringify({ paymob_order_id: String(intention.intention_order_id) }) });
    const url = new URL('/unifiedcheckout/', base);
    url.searchParams.set('publicKey', publicKey);
    url.searchParams.set('clientSecret', intention.client_secret);
    return reply({ url: url.toString(), amount_cents: amount, currency: 'AED', mode, order_id: orderId });
  } catch (_) {
    if (orderId) { try { await database(`billing_orders?id=eq.${orderId}`, { method: 'PATCH', body: JSON.stringify({ status: 'failed' }) }); } catch { /* retain pending for reconciliation */ } }
    return reply({ error: 'Payment checkout is unavailable. Please try again later or contact support.' }, 503);
  }
});
