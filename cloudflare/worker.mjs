// Public marketing HTML lives at /. Flutter and its SPA fallback live at /app/.
const appAliases = new Set(['login', 'signup', 'dashboard', 'rooms', 'financials',
  'settings', 'buildings', 'tenants', 'vacant-beds', 'billing', 'admin', 'connect-google']);
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const segments = url.pathname.split('/').filter(Boolean);
    if (url.pathname === '/auth/callback') {
      url.pathname = '/app/auth/callback';
      return Response.redirect(url.href, 308);
    }
    if (appAliases.has(segments[0])) {
      url.pathname = '/app/' + segments.join('/');
      return Response.redirect(url.href, 308);
    }
    if (['features', 'pricing', 'guides'].includes(segments[0]) && segments.length === 1) {
      url.pathname = '/';
      url.hash = segments[0];
      return Response.redirect(url.href, 308);
    }
    if (url.pathname === '/app') {
      url.pathname = '/app/';
      return Response.redirect(url.href, 308);
    }
    const response = await env.ASSETS.fetch(request);
    const lastSegment = url.pathname.split('/').at(-1);
    if (response.status === 404 && url.pathname.startsWith('/app/') &&
        ['GET', 'HEAD'].includes(request.method) && !lastSegment.includes('.')) {
      // Keep OAuth query/fragment in the browser; only rewrite the asset lookup.
      // Directory URL avoids the static host's index.html canonical redirect.
      url.pathname = '/app/';
      url.search = '';
      return env.ASSETS.fetch(new Request(url, request));
    }
    return response;
  },
};
