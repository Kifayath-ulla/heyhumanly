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
    if (url.hostname.endsWith('.workers.dev')) {
      const r = new Response(res.body, res);
      r.headers.set('X-Robots-Tag', 'noindex, nofollow');
      return r;
    }
    return res;
  },
};
