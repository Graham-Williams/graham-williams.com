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
  scripts** — keep everything in this file. **After editing it (or the
  favicon), run `scripts/asset-version.sh`** — it re-stamps the `?v=<hash>`
  on the `<link>`s in `index.html`/`404.html`; the tests fail if the stamp is
  stale. The stamp exists because Cloudflare's edge floors short browser-cache
  TTLs at 4 h, so only a changed URL makes a CSS edit visible immediately.
- `static/fonts/` — self-hosted woff2 Latin subsets (SIL OFL; `OFL.txt` there
  carries each project's notice plus the full license text). IBM Plex Sans is
  one variable file covering weights 400–500.
- `static/favicon.svg`
- `404.html`
- `robots.txt` — allow-all; the homepage is meant to be indexable.
- `nginx.conf` + `snippets/security-headers.conf` — the full nginx config
  (security headers, cache policy, `/healthz`, `www` → apex redirect,
  plain-http → https redirect keyed on the tunnel's `X-Forwarded-Proto`,
  dotfiles 404, relative directory redirects). HSTS is set for this host only —
  deliberately no `includeSubDomains` (each app owns its own policy) and never
  `preload`.
- `Dockerfile` — `nginxinc/nginx-unprivileged`, pinned by tag **and digest**,
  running as a non-root user on 8080. Dependabot (`.github/dependabot.yml`)
  opens weekly PRs for the base image and the pinned GitHub Action; bump both
  the tag and the digest together.
- `docker-compose.yml` — joins the external `km-tracker_default` network so the
  existing Cloudflare tunnel can route to it by service name; read-only rootfs.
- `tests/check.sh` — builds the image, runs it on a random local port with the
  production hardening flags, and asserts the page, `/healthz`, all six security
  headers on every response path (including the www redirect), cache policy,
  and the href allowlist. CI runs the same script.

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

## Cloudflare zone settings that affect this page

Two zone-wide toggles were found off during the first QA pass (2026-09-12) and
are owned in the Cloudflare dashboard, not this repo: **Always Use HTTPS**
(without it, plain `http://` reaches the origin — this repo bounces it itself
via `X-Forwarded-Proto`, but the other apps on the domain don't) and **Web
Analytics automatic injection**, which appends a `cloudflareinsights.com`
beacon `<script>` to every HTML response; this page's CSP blocks it, so it only
produces a console error. Do not loosen the CSP to admit it.

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
