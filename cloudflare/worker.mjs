// Public marketing HTML lives at /. Flutter and its SPA fallback live at /app/.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
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
