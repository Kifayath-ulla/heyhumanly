// Serves the static site (site/). Keeps preview hosts out of search and sends www to the apex.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol === 'http:' && !url.hostname.endsWith('.workers.dev')) {
      return Response.redirect('https://' + (url.hostname === 'www.heyhumanly.com' ? 'heyhumanly.com' : url.hostname) + url.pathname + url.search, 301);
    }
    if (url.hostname === 'www.heyhumanly.com') {
      return Response.redirect('https://heyhumanly.com' + url.pathname + url.search, 301);
    }
    const res = await env.ASSETS.fetch(request);
    if (url.hostname.endsWith('.workers.dev')) {
      const r = new Response(res.body, res);
      r.headers.set('X-Robots-Tag', 'noindex, nofollow');
      return r;
    }
    return res;
  },
};
