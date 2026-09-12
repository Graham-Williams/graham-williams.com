# graham-williams.com

The landing page at the root of `graham-williams.com`: a short index of the
web apps hosted under the domain, plus links out to GitHub and LinkedIn.

Static HTML + CSS served by nginx in a small container. No JavaScript, no
build step, no third-party requests (fonts are self-hosted).

- `index.html`, `static/` — the page
- `nginx.conf`, `Dockerfile`, `docker-compose.yml` — how it is served
- `tests/check.sh` — smoke test run locally and in CI
- `DEPLOY.md` — how it reaches the server

See `CLAUDE.md` for how to work in this repo.
