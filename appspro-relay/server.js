/**
 * Static-IP relay for AppsPro's Bearer-authed SDK API.
 *
 * Why this exists: AppsPro's dashboard restricts those endpoints
 * (`/api/v1/sdk/otp/request`, `/otp/verify`, `/verify/{id}`, ...) to an
 * "Allowed Host Address(es)" list — but Cloudflare Workers (this app's
 * backend, see `worker/src/subscription.ts`) don't call out from one
 * fixed IP. Confirmed live: three different diagnostic calls returned
 * three different Cloudflare edge IPs depending on which of Cloudflare's
 * global PoPs handled the request — there was never going to be one
 * address to put in that field.
 *
 * This is the fix: a tiny always-on server with ONE real, static IP,
 * sitting between the Worker and AppsPro. The Worker sends its AppsPro
 * calls here instead of directly to api.appspro.dev; this forwards them
 * to the real AppsPro API and streams the response straight back.
 *
 * What this deliberately does NOT do:
 *   - It never sees or stores AppsPro's secret_key. The Worker still
 *     attaches `Authorization: Bearer <secret_key>` itself — this relay
 *     just passes that header through untouched, the same as any other
 *     header, without ever parsing or logging it.
 *   - It never forwards anywhere except api.appspro.dev. There's no
 *     "target URL" parameter to abuse — the destination is hardcoded
 *     below, so even a leaked RELAY_SHARED_SECRET only grants "can call
 *     AppsPro's API," not "can make this server call anything."
 *   - It has no other dependency than Node's own built-in `http`/`https`
 *     — nothing to `npm install`, nothing else on this VM that could
 *     have its own vulnerabilities to worry about.
 *
 * Its own auth: every request must carry `X-Relay-Secret` matching this
 * process's `RELAY_SHARED_SECRET` env var — a secret shared only between
 * this relay and the Worker (see `APPSPRO_RELAY_SECRET`, set via
 * `wrangler secret put`), unrelated to AppsPro's own secret_key. Without
 * it, this would be an open proxy anyone could point at AppsPro's API
 * using nothing but this server's IP.
 *
 * Deployment: see README.md in this directory. In short — a plain Linux
 * VM (Oracle Cloud's Always Free tier works well; any host with a static
 * public IP does), Caddy in front for automatic HTTPS (this relay itself
 * only ever listens on localhost, plain HTTP — Caddy is what's actually
 * reachable from the internet), and this script run under systemd so it
 * survives reboots/crashes.
 */

const http = require('http');
const https = require('https');

const PORT = process.env.PORT || 8787;
const RELAY_SHARED_SECRET = process.env.RELAY_SHARED_SECRET;
const APPSPRO_HOST = 'api.appspro.dev';

if (!RELAY_SHARED_SECRET) {
  console.error('RELAY_SHARED_SECRET env var is required — refusing to start as an open proxy.');
  process.exit(1);
}

// Only listens on localhost — Caddy (see Caddyfile) is the only thing
// with a socket actually reachable from the public internet. If this
// relay is ever run without Caddy in front, plain HTTP here means
// AppsPro's secret_key would cross the network unencrypted — don't do
// that; always keep a TLS-terminating reverse proxy in front of this.
const HOST = '127.0.0.1';

const server = http.createServer((req, res) => {
  if (req.headers['x-relay-secret'] !== RELAY_SHARED_SECRET) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Missing or wrong relay secret' }));
    return;
  }

  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    const body = Buffer.concat(chunks);

    // Strip hop-specific headers before forwarding: `x-relay-secret` is
    // this hop's own auth and means nothing to AppsPro; `host` has to be
    // AppsPro's own hostname, not this relay's; `content-length` gets
    // recomputed correctly by Node for the new request either way.
    const forwardHeaders = { ...req.headers };
    delete forwardHeaders['x-relay-secret'];
    delete forwardHeaders.host;
    delete forwardHeaders['content-length'];

    const upstreamReq = https.request(
      {
        hostname: APPSPRO_HOST,
        path: req.url,
        method: req.method,
        headers: forwardHeaders,
      },
      (upstreamRes) => {
        res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
        upstreamRes.pipe(res);
      },
    );

    upstreamReq.on('error', (err) => {
      console.error('Relay upstream error:', err);
      if (!res.headersSent) {
        res.writeHead(502, { 'Content-Type': 'application/json' });
      }
      res.end(JSON.stringify({ error: `Relay upstream error: ${err.message}` }));
    });

    if (body.length > 0) upstreamReq.write(body);
    upstreamReq.end();
  });
});

server.listen(PORT, HOST, () => {
  console.log(`AppsPro relay listening on ${HOST}:${PORT}, forwarding to https://${APPSPRO_HOST}`);
});
