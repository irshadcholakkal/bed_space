import { database, required } from '../_shared/backend.ts';
import { successfulCharge, verifyHmac } from '../_shared/paymob.mjs';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  try {
    const body = await request.json();
    if (body.type !== 'TRANSACTION' || !body.obj) return new Response('Unsupported callback', { status: 400 });
    const obj = body.obj;
    const signature = new URL(request.url).searchParams.get('hmac');
    if (!await verifyHmac(obj, signature, required('PAYMOB_HMAC_SECRET'))) return new Response('Invalid signature', { status: 401 });
    if (Number(obj.integration_id) !== Number(required('PAYMOB_INTEGRATION_ID'))) return new Response('Wrong integration', { status: 403 });
    if (obj.pending === true || obj.is_auth === true) return new Response('Awaiting capture', { status: 200 });
    if (!Number.isSafeInteger(obj.amount_cents) || obj.amount_cents <= 0 || obj.currency !== 'AED') return new Response('Invalid payment amount', { status: 400 });
    // Correlate only using signed order.id, never an unsigned customer/reference field.
    await database('rpc/settle_paymob_payment', { method: 'POST', body: JSON.stringify({
      p_paymob_order_id: String(obj.order.id), p_transaction_id: String(obj.id),
      p_amount_cents: obj.amount_cents, p_currency: obj.currency,
      p_success: successfulCharge(obj), p_refunded: obj.is_refunded === true || obj.is_voided === true,
      p_mode: Deno.env.get('PAYMOB_MODE') || 'test',
    }) });
    return new Response('Received', { status: 200 });
  } catch (_) {
    // Non-2xx allows Paymob retry; do not log raw billing/card callback data.
    return new Response('Callback could not be processed', { status: 500 });
  }
});
