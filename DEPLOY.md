# Deploy

The page runs on the home server as the `homepage` container, behind the
existing `km-tracker` Cloudflare tunnel. There are no secrets and no state.

## First-time setup on the server

```bash
git clone https://github.com/Graham-Williams/graham-williams.com ~/homepage
cd ~/homepage
docker compose up -d --build
docker exec homepage wget -qO- http://127.0.0.1:8080/healthz   # -> ok
```

Then, once, in Cloudflare (done via the API):

1. Tunnel ingress: add `graham-williams.com -> http://homepage:8080` and
   `www.graham-williams.com -> http://homepage:8080` before the catch-all 404.
2. DNS: proxied CNAMEs for `graham-williams.com` (apex; Cloudflare flattens it)
   and `www` pointing at `<tunnel-id>.cfargotunnel.com`.

The Universal SSL certificate already covers the apex and one label below it,
so no certificate work is needed. `www` is 301-redirected to the apex by nginx.

## Updating

```bash
cd ~/homepage && git pull && docker compose up -d --build
```

Only this container is rebuilt and restarted; nothing else on the server is
touched. Verify:

```bash
docker exec homepage wget -qO- http://127.0.0.1:8080/healthz
curl -s -o /dev/null -w '%{http_code}\n' https://graham-williams.com/            # 200
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' http://graham-williams.com/  # 301 https://…
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://www.graham-williams.com/  # 301 apex
# Edge-only check: Cloudflare's analytics beacon must not be injected (expect 0)
curl -s -A 'Mozilla/5.0 Chrome/128' -H 'Accept: text/html' https://graham-williams.com/ | grep -c cloudflareinsights
```

## Previewing a branch

There is no staging instance. To preview a feature branch, check it out on the
server and rebuild:

```bash
cd ~/homepage && git fetch && git checkout <branch> && git reset --hard origin/<branch> && docker compose up -d --build
```

After the PR merges, realign to `main`:

```bash
cd ~/homepage && git checkout main && git pull && docker compose up -d --build
```
