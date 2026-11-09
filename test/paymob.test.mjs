import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { amountFor, signatureInput, successfulCharge, verifyHmac } from '../supabase/functions/_shared/paymob.mjs';

const transaction = {
  amount_cents: 5000, created_at: '2026-11-10T12:00:00', currency: 'AED',
  error_occured: false, has_parent_transaction: false, id: 123, integration_id: 456,
  is_3d_secure: true, is_auth: false, is_capture: false, is_refunded: false,
  is_standalone_payment: true, is_voided: false, order: { id: 789 }, owner: 1,
  pending: false, source_data: { pan: '1234', sub_type: 'Visa', type: 'card' }, success: true,
};
test('Monthly and annual prices are server calculated in fils', () => {
  assert.equal(amountFor('monthly', '0'), 5000);
  assert.equal(amountFor('annual', '0'), 54000);
  assert.equal(amountFor('monthly', '250'), 5250);
  assert.equal(amountFor('annual', '500'), 54500);
  assert.throws(() => amountFor('monthly', undefined));
  assert.throws(() => amountFor('monthly', '-1'));
  assert.throws(() => amountFor('free', '0'));
});
test('Valid callback signature is accepted; tampering and missing fields fail', async () => {
  const expectedInput = '50002026-11-10T12:00:00AEDfalsefalse123456truefalsefalsefalsetruefalse7891false1234Visacardtrue';
  assert.equal(signatureInput(transaction), expectedInput);
  const signature = createHmac('sha512', 'test-secret').update(expectedInput).digest('hex');
  assert.equal(await verifyHmac(transaction, signature, 'test-secret'), true);
  assert.equal(await verifyHmac({ ...transaction, amount_cents: 1 }, signature, 'test-secret'), false);
  assert.equal(await verifyHmac({ ...transaction, order: { id: 999 } }, signature, 'test-secret'), false);
  assert.equal(await verifyHmac(transaction, '', 'test-secret'), false);
  assert.equal(await verifyHmac({ ...transaction, source_data: null }, signature, 'test-secret'), false);
});
test('Only completed captured or standalone payments may extend access', () => {
  assert.equal(successfulCharge(transaction), true);
  for (const override of [{ pending: true }, { is_auth: true }, { is_refunded: true }, { is_voided: true }, { success: false }, { success: 'true' }, { error_occured: true }, { is_standalone_payment: false }]) {
    assert.equal(successfulCharge({ ...transaction, ...override }), false);
  }
});
