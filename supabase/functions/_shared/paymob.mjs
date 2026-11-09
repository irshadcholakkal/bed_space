export function amountFor(cycle, extra) {
  if (!['monthly', 'annual'].includes(cycle)) throw new Error('Invalid billing cycle');
  if (!/^\d+$/.test(String(extra))) throw new Error('Charges must be configured in whole fils');
  const amount = (cycle === 'annual' ? 54000 : 5000) + Number(extra);
  if (!Number.isSafeInteger(amount) || amount > 10000000) throw new Error('Invalid amount');
  return amount;
}

export function signatureInput(obj) {
  const values = [obj.amount_cents, obj.created_at, obj.currency, obj.error_occured,
    obj.has_parent_transaction, obj.id, obj.integration_id, obj.is_3d_secure,
    obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment,
    obj.is_voided, obj.order?.id, obj.owner, obj.pending, obj.source_data?.pan,
    obj.source_data?.sub_type, obj.source_data?.type, obj.success];
  if (values.some(v => v === null || v === undefined || typeof v === 'object')) {
    throw new Error('Unsupported callback fields');
  }
  return values.map(String).join('');
}

export async function verifyHmac(obj, received, secret) {
  if (!secret || !/^[a-f0-9]{128}$/i.test(received || '')) return false;
  let input;
  try { input = signatureInput(obj); } catch { return false; }
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const signed = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(input)));
  const computed = Array.from(signed, b => b.toString(16).padStart(2, '0')).join('');
  let difference = 0;
  for (let i = 0; i < computed.length; i++) difference |= computed.charCodeAt(i) ^ received.toLowerCase().charCodeAt(i);
  return difference === 0;
}

export function successfulCharge(obj) {
  return obj.success === true && obj.pending === false && obj.error_occured === false &&
    obj.is_auth === false && obj.is_refunded === false && obj.is_voided === false &&
    (obj.is_capture === true || obj.is_standalone_payment === true);
}
