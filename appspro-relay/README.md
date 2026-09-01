# AppsPro static-IP relay

Why this exists: see the doc comment at the top of `server.js`, and
`docs/ARCHITECTURE.md` → "Decision: AppsPro for bdapps DCB". Short version —
AppsPro's dashboard requires a fixed "Allowed Host Address(es)" for its
Bearer-authed SDK API, but the Cloudflare Worker that needs to call it
doesn't have one fixed outbound IP. This relay does.

This directory deploys to a separate always-on VM — **not** to Cloudflare,
and not part of the Flutter app or Worker's own deploy step. Follow this
once, then the Worker talks to this relay instead of AppsPro directly.

## 1. Create the VM (Oracle Cloud Always Free)

1. Sign up at [cloud.oracle.com](https://cloud.oracle.com) (a card is
   required for identity verification; the Always Free shapes below never
   auto-charge unless you explicitly upgrade the account).
2. Create a Compute Instance:
   - **Shape**: any Always-Free-eligible shape — `VM.Standard.E2.1.Micro`
     (AMD, always free) or an Ampere `VM.Standard.A1.Flex` (ARM, also
     always free, more headroom). This relay is trivially light; the
     smallest shape is plenty.
   - **Image**: Ubuntu (22.04 or newer) — the commands below assume
     Ubuntu/Debian (`apt`).
   - Leave "Assign a public IPv4 address" **on**.
3. Once it's running, note its **public IP address** — you'll need it
   twice (the Caddyfile, and telling me so I can point the Worker at it).
4. Open the port Caddy needs in Oracle's own firewall (separate from the
   VM's internal one):
   - Networking → Virtual Cloud Networks → (your VCN) → Security Lists →
     Default Security List → Add Ingress Rules:
     - Source `0.0.0.0/0`, IP Protocol TCP, Destination Port **443**
     - Source `0.0.0.0/0`, IP Protocol TCP, Destination Port **80** (Caddy
       needs this briefly for the Let's Encrypt HTTP challenge)

## 2. SSH in and install Node.js + Caddy

```bash
ssh ubuntu@<your-vm-ip>

# Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Caddy (official repo)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy

# Also open the VM's own firewall (separate from Oracle's Security List
# above — Ubuntu images on Oracle Cloud ship with iptables rules that
# block everything not explicitly allowed)
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || sudo apt install -y iptables-persistent && sudo netfilter-persistent save
```

## 3. Deploy this directory to the VM

From your own machine (not the VM):

```bash
scp -r appspro-relay ubuntu@<your-vm-ip>:/tmp/appspro-relay
```

Back on the VM:

```bash
sudo mkdir -p /opt/appspro-relay
sudo cp /tmp/appspro-relay/server.js /opt/appspro-relay/
sudo useradd --system --no-create-home appspro-relay

# Generate the shared secret — copy this value, you'll need to give it
# to me (or set it directly as the Worker's APPSPRO_RELAY_SECRET) too
openssl rand -hex 32
```

Edit `/tmp/appspro-relay/appspro-relay.service`, replacing `REPLACE_ME`
with the secret you just generated, then:

```bash
sudo cp /tmp/appspro-relay/appspro-relay.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now appspro-relay
sudo systemctl status appspro-relay   # should show "active (running)"
```

Edit `/tmp/appspro-relay/Caddyfile`, replacing
`REPLACE_WITH_YOUR_VM_IP.sslip.io` with your actual VM IP in that same
dotted form (e.g. `130.61.20.5.sslip.io`), then:

```bash
sudo cp /tmp/appspro-relay/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Caddy fetches a real Let's Encrypt certificate automatically the first
time it's requested — no manual cert setup.

## 4. Verify it works

From your own machine:

```bash
curl -i https://<your-vm-ip>.sslip.io/api/v1/sdk/app-info?publishable_key=pk_7c0c2508506cbddfa66c6731
# Expect a 401/error about the relay secret, NOT a connection error or a
# Caddy default page — that confirms Caddy → relay is wired correctly.

curl -i https://<your-vm-ip>.sslip.io/api/v1/sdk/app-info?publishable_key=pk_7c0c2508506cbddfa66c6731 \
  -H "X-Relay-Secret: <the secret you generated>"
# Expect AppsPro's own JSON response (app-info is a no-auth endpoint, so
# this should succeed end-to-end: Worker-shaped request -> this relay ->
# AppsPro -> back).
```

## 5. Tell AppsPro and the Worker about it

1. AppsPro dashboard → this app → BDApps/API settings → **Allowed Host
   Address(es)** → set to your VM's public IP (the plain IP, not the
   sslip.io hostname).
2. Give me (or set directly):
   - `https://<your-vm-ip>.sslip.io` as `APPSPRO_RELAY_URL`
   - the `RELAY_SHARED_SECRET` you generated, as `APPSPRO_RELAY_SECRET`

   ```bash
   cd worker
   npx wrangler secret put APPSPRO_RELAY_SECRET   # paste the shared secret
   # APPSPRO_RELAY_URL is not sensitive — it's added to wrangler.jsonc's
   # plain vars once you give me the real hostname.
   ```

Once both are set and the Worker's redeployed, every AppsPro API call
(`requestOtp`, `verifyOtpAndSignIn`, `refreshSubscriptionStatus`) routes
through this relay instead of calling AppsPro directly — see
`worker/src/subscription.ts`'s `callAppsPro`.

## Maintaining it

- Logs: `sudo journalctl -u appspro-relay -f`
- Restart after editing `server.js`: `sudo systemctl restart appspro-relay`
  (re-`scp` the updated file to `/opt/appspro-relay/server.js` first)
- Caddy renews its certificate automatically — nothing to do there.
- If the VM ever gets a new IP (a reboot shouldn't change it on Oracle
  Cloud, but a re-provision would), update the Caddyfile's hostname, the
  AppsPro dashboard's allowlist, and `APPSPRO_RELAY_URL` all three.
