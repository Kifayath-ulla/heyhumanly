// Serves the static site (site/) and the opt-in online coaching API (worker/coach.js). Keeps preview hosts out of search and sends www to the apex.
import { handleCoach } from './coach.js';
export { Allowance } from './coach.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol === 'http:' && !url.hostname.endsWith('.workers.dev')) {
      return Response.redirect('https://' + (url.hostname === 'www.heyhumanly.com' ? 'heyhumanly.com' : url.hostname) + url.pathname + url.search, 301);
    }
    if (url.hostname === 'www.heyhumanly.com') {
      return Response.redirect('https://heyhumanly.com' + url.pathname + url.search, 301);
    }
    if (url.pathname.startsWith('/api/')) return handleCoach(request, env);
    const res = await env.ASSETS.fetch(request);
    const r = new Response(res.body, res);
    // no-transform stops Cloudflare from injecting its Web Analytics beacon; the site promises no analytics.
    if ((r.headers.get('Content-Type') || '').startsWith('text/html')) {
      r.headers.set('Cache-Control', 'public, max-age=0, must-revalidate, no-transform');
    }
    if (url.hostname.endsWith('.workers.dev')) r.headers.set('X-Robots-Tag', 'noindex, nofollow');
    return r;
  },
};
