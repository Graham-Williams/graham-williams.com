#!/usr/bin/env bash
# Smoke test: build the image, run it on a random local port with the same
# hardening flags as production, and check the page, headers, and links.
# Used locally and by CI.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="homepage-test:$$"
docker build -q -t "$IMG" . >/dev/null
CID=$(docker run -d --rm --read-only --tmpfs /tmp --cap-drop ALL \
        --security-opt no-new-privileges:true -p 127.0.0.1:0:8080 "$IMG")
cleanup() { docker rm -f "$CID" >/dev/null 2>&1 || true; docker rmi -f "$IMG" >/dev/null 2>&1 || true; }
trap cleanup EXIT

PORT=$(docker port "$CID" 8080/tcp | head -1 | awk -F: '{print $NF}')
BASE="http://127.0.0.1:$PORT"
for _ in $(seq 1 40); do curl -fsS "$BASE/healthz" >/dev/null 2>&1 && break; sleep 0.25; done

fail=0
ok()   { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
hdr()    { curl -sI "$@" | tr -d '\r'; }

[ "$(curl -fsS "$BASE/healthz")" = "ok" ] && ok "healthz" || bad "healthz"
[ "$(status "$BASE/")" = 200 ]                       && ok "GET / is 200"          || bad "GET / is 200"
[ "$(status "$BASE/static/style.css")" = 200 ]       && ok "stylesheet served"     || bad "stylesheet served"
[ "$(status "$BASE/static/favicon.svg")" = 200 ]     && ok "favicon served"        || bad "favicon served"
[ "$(status "$BASE/does-not-exist")" = 404 ]         && ok "unknown path is 404"   || bad "unknown path is 404"
curl -s "$BASE/does-not-exist" | grep -q "Nothing"   && ok "404 page renders"      || bad "404 page renders"

hdr "$BASE/static/fonts/outfit-700.woff2" | grep -qi '^content-type: font/woff2' && ok "woff2 mime type" || bad "woff2 mime type"
hdr "$BASE/static/fonts/outfit-700.woff2" | grep -qi 'immutable'                && ok "fonts cached immutable" || bad "fonts cached immutable"
hdr "$BASE/" | grep -qi '^cache-control: no-cache'                              && ok "html no-cache"         || bad "html no-cache"

for path in / /static/style.css /static/fonts/outfit-700.woff2 /does-not-exist; do
  h=$(hdr "$BASE$path")
  grep -qi "^content-security-policy: default-src 'none'" <<<"$h" && ok "CSP on $path"     || bad "CSP on $path"
  grep -qi '^x-content-type-options: nosniff'              <<<"$h" && ok "nosniff on $path" || bad "nosniff on $path"
  grep -qi '^x-frame-options: DENY'                        <<<"$h" && ok "XFO on $path"     || bad "XFO on $path"
done
! hdr "$BASE/" | grep -qiE '^server: nginx/'  && ok "server version hidden" || bad "server version hidden"

redir=$(curl -s -o /dev/null -w '%{redirect_url}' -H 'Host: www.graham-williams.com' "$BASE/x?y=1")
[ "$redir" = "https://graham-williams.com/x?y=1" ] && ok "www redirects to apex" || bad "www redirects to apex (got: $redir)"

HTML=$(curl -fsS "$BASE/")
! grep -qiE '<script|<style| style=' <<<"$HTML" && ok "no inline script/style" || bad "no inline script/style"
for host in km todoist-points taste-twin jjho dashboard; do
  grep -q "https://$host.graham-williams.com/" <<<"$HTML" && ok "links $host" || bad "links $host"
done
grep -q 'https://github.com/Graham-Williams/gremlins-minecraft-mods' <<<"$HTML" && ok "links gremlins repo" || bad "links gremlins repo"

# Every absolute URL on the page must be on the allowlist.
stray=$(grep -oE 'https?://[^"'"'"' <>]+' <<<"$HTML" \
  | grep -vE '^https://([a-z0-9-]+\.)?graham-williams\.com/' \
  | grep -vE '^https://github\.com/Graham-Williams(/|$)' \
  | grep -vE '^https://www\.linkedin\.com/in/graham-williams/?$' || true)
[ -z "$stray" ] && ok "outbound links allowlisted" || bad "outbound links allowlisted: $stray"
! grep -qE 'url\(["'"'"']?https?:' static/style.css && ok "no remote assets in CSS" || bad "no remote assets in CSS"

exit $fail
