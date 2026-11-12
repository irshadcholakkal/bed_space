import { required } from '../_shared/backend.ts';
import { refreshGoogleAccess } from '../_shared/google-session.mjs';

Deno.serve(async (request: Request) => {
  const origin = new URL(Deno.env.get('APP_URL') || 'https://bedspace.thepercentagecompany.com').origin;
  const headers = { 'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
  const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed' }, 405);
  if (request.headers.get('origin') && request.headers.get('origin') !== origin) return reply({ error: 'Origin not allowed' }, 403);
  try {
    const auth = await fetch(`${required('SUPABASE_URL')}/auth/v1/user`, {
      headers: { apikey: required('SUPABASE_ANON_KEY'), Authorization: request.headers.get('authorization') || '' },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return reply({ error: 'Sign in to restore your Google connection.' }, 401);
    const user = await auth.json();
    if (!user.email || !user.email_confirmed_at) return reply({ error: 'A verified account is required.' }, 403);
    const clientId = Deno.env.get('GOOGLE_OAUTH_CLIENT_ID');
    const clientSecret = Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET');
    if (!clientId || !clientSecret) return reply({ error: 'Automatic Google reconnection has not been configured.' }, 503);
    const input = await request.json();
    if (typeof input.refresh_token !== 'string' || !input.refresh_token || input.refresh_token.length > 4096) {
      return reply({ error: 'Reconnect Google once to enable automatic renewal.' }, 400);
    }
    const tokens = await refreshGoogleAccess({ refreshToken: input.refresh_token, email: user.email, clientId, clientSecret });
    return reply(tokens);
  } catch (_) {
    // Never return Google response bodies, client secrets or refresh tokens.
    return reply({ error: 'Could not renew Google access. Reconnect Google and try again.' }, 502);
  }
});
