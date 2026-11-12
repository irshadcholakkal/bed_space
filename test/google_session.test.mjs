import test from 'node:test';
import assert from 'node:assert/strict';
import { refreshGoogleAccess } from '../supabase/functions/_shared/google-session.mjs';
const scope = 'https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file';
const base = { refreshToken: 'saved-refresh', email: 'owner@example.com', clientId: 'client-id', clientSecret: 'server-secret' };
function fixture(overrides = {}, fail = false) {
  let calls = 0;
  return async (url, options) => {
    calls++;
    if (calls === 1) {
      assert.equal(String(url), 'https://oauth2.googleapis.com/token');
      assert.equal(options.body.get('grant_type'), 'refresh_token');
      assert.equal(options.body.get('refresh_token'), 'saved-refresh');
      assert.equal(options.body.get('client_secret'), 'server-secret');
      return Response.json(fail ? { error: 'invalid_grant' } : { access_token: 'renewed', refresh_token: 'rotated' }, { status: fail ? 400 : 200 });
    }
    assert.equal(new URL(url).searchParams.get('access_token'), 'renewed');
    return Response.json({ email: 'owner@example.com', aud: 'client-id', expires_in: '3500', scope, ...overrides });
  };
}
test('Renews access and returns only tokens, after validating owner and scopes', async () => {
  assert.deepEqual(await refreshGoogleAccess({ ...base, fetcher: fixture() }), { access_token: 'renewed', refresh_token: 'rotated' });
});
for (const [label, info] of [
  ['different account', { email: 'other@example.com' }],
  ['different client', { aud: 'other-client' }],
  ['missing scope', { scope: 'openid email' }],
  ['expired token', { expires_in: '30' }],
  ['missing expiry', { expires_in: undefined }],
]) {
  test(`Rejects ${label}`, async () => {
    await assert.rejects(refreshGoogleAccess({ ...base, fetcher: fixture(info) }));
  });
}
test('Revoked Google consent requires reconnection', async () => {
  await assert.rejects(refreshGoogleAccess({ ...base, fetcher: fixture({}, true) }), /reconnected/);
});
