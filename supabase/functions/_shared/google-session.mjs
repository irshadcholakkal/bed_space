export async function refreshGoogleAccess({ refreshToken, email, clientId, clientSecret, fetcher = fetch }) {
  const response = await fetcher('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    signal: AbortSignal.timeout(15000),
    body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: refreshToken,
      client_id: clientId, client_secret: clientSecret }),
  });
  if (!response.ok) throw new Error('Google authorization must be reconnected.');
  const result = await response.json();
  if (typeof result.access_token !== 'string' || !result.access_token) throw new Error('Invalid Google response.');
  const url = new URL('https://oauth2.googleapis.com/tokeninfo');
  url.searchParams.set('access_token', result.access_token);
  const checked = await fetcher(url, { signal: AbortSignal.timeout(10000) });
  if (!checked.ok) throw new Error('Could not validate Google authorization.');
  const info = await checked.json();
  const scopes = String(info.scope || '').split(' ');
  if (String(info.email || '').toLowerCase() !== email.toLowerCase() || info.aud !== clientId ||
      !Number.isFinite(Number(info.expires_in)) || Number(info.expires_in) <= 60 ||
      !['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive.file'].every(s => scopes.includes(s))) {
    throw new Error('Google authorization does not match this account.');
  }
  return { access_token: result.access_token,
    ...(typeof result.refresh_token === 'string' && result.refresh_token ? { refresh_token: result.refresh_token } : {}) };
}
