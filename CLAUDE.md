# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

The landing page served at `https://graham-williams.com` — a single static page
listing the apps hosted under the domain, with GitHub and LinkedIn links. It is
deliberately tiny: no JavaScript, no framework, no build step, no analytics, no
third-party requests (typefaces are self-hosted under `static/fonts/`).

## Layout

- `index.html` — the page. Content lives here; keep copy short.
- `static/style.css` — all styling. The page ships with a strict
  Content-Security-Policy (`style-src 'self'`), so **no inline styles or
  scripts** — keep everything in this file.
- `static/fonts/` — self-hosted woff2 subsets (SIL OFL; see `OFL.txt` there).
- `static/favicon.svg`
- `404.html`
- `nginx.conf` — the full nginx config (security headers, cache policy,
  `/healthz`, `www` → apex redirect).
- `Dockerfile` — `nginxinc/nginx-unprivileged` (runs as a non-root user on 8080).
- `docker-compose.yml` — joins the external `km-tracker_default` network so the
  existing Cloudflare tunnel can route to it by service name; read-only rootfs.
- `tests/check.sh` — builds the image, runs it on a random local port, and
  asserts the page, `/healthz`, security headers, and the outbound-link
  allowlist. CI runs the same script.

## Run locally

```bash
docker compose up --build
# then: docker compose exec homepage wget -qO- http://127.0.0.1:8080/
```

There is no host port mapping by design (the tunnel is the only entry point in
production). For a quick local look without Docker:

```bash
python3 -m http.server 8090   # then open http://127.0.0.1:8090/
```

## Test

```bash
tests/check.sh
```

Run it before opening a PR; CI runs it on every push and PR.

## Editing the app list

Each app is one `<a class="tile">` in `index.html` with a `--c` color
variable, a two-letter mark, a name, a one-line description, and the hostname.
Keep descriptions to one sentence. New apps get a new color that reads on the
dark ground; existing marks/colors stay stable so returning visitors recognize
them.

Outbound links are allowlisted in `tests/check.sh` (`*.graham-williams.com`,
`github.com/Graham-Williams/*`, `linkedin.com/in/graham-williams`). Adding a
link to any other host must be a deliberate change to that list.

## Git workflow

- `main` is protected: changes land only via a pull request that Graham
  reviews and merges himself. Never push to `main` directly.
- Work on feature branches; commit and push freely there. Merged branches are
  deleted automatically.
- Before pushing, the security gate runs (secrets/PII, injection/headers,
  dependency pins, data exposure). Keep the base image pinned to a specific
  version tag.

## Secret safety

The site needs no secrets and reads no environment variables. `.env*` is
gitignored anyway. Never add analytics, tracking pixels, or third-party
scripts — the CSP would block them, and that is intentional.

## Deploy

See `DEPLOY.md`. Production runs `main`; a feature branch may be deployed for
preview and is realigned to `main` after merge.

## Keep this file current

When you add or change a capability, dependency, command, or architectural
decision in this repo, update this `CLAUDE.md` (and `DEPLOY.md` if the deploy
recipe changes) before the task is considered done. This is how context
persists for the next session.
