import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../cloudflare/worker.mjs';

test('App entry gets a trailing slash without losing signup or billing choice', async () => {
  const response = await worker.fetch(new Request('https://example.com/app?view=signup&billing=annual'), {});
  assert.equal(response.status, 308);
  assert.equal(response.headers.get('location'), 'https://example.com/app/?view=signup&billing=annual');
});
test('App deep links fall back to the Flutter shell', async () => {
  const calls = [];
  const env = { ASSETS: { fetch: async request => {
    calls.push(request.url);
    return request.url.endsWith('/app/')
      ? new Response('flutter-shell') : new Response('Not Found', { status: 404 });
  } } };
  const response = await worker.fetch(new Request('https://example.com/app/rooms?code=private'), env);
  assert.equal(await response.text(), 'flutter-shell');
  assert.equal(calls[1], 'https://example.com/app/');
});
test('Missing JavaScript remains a 404 rather than receiving HTML', async () => {
  let calls = 0;
  const response = await worker.fetch(new Request('https://example.com/app/missing.js'),
    { ASSETS: { fetch: async () => { calls++; return new Response('Missing', { status: 404 }); } } });
  assert.equal(response.status, 404);
  assert.equal(calls, 1);
});
test('Public root serves Next HTML and never invokes the app fallback', async () => {
  const response = await worker.fetch(new Request('https://example.com/'),
    { ASSETS: { fetch: async () => new Response('next-landing') } });
  assert.equal(await response.text(), 'next-landing');
});
