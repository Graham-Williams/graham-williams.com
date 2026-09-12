#!/usr/bin/env bash
# Smoke test: build the image, run it on a random local port with the same
# hardening flags as production, and check the page, headers, and links.
# Used locally and by CI.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="homepage-test:$$"
docker build -q -t "$IMG" . >/dev/null
CID=""
cleanup() { [ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true; docker rmi -f "$IMG" >/dev/null 2>&1 || true; }
trap cleanup EXIT
CID=$(docker run -d --rm --read-only --tmpfs /tmp:mode=1777,size=16m --cap-drop ALL \
        --security-opt no-new-privileges:true -p 127.0.0.1:0:8080 "$IMG")

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
[ "$(status "$BASE/robots.txt")" = 200 ]             && ok "robots.txt served"     || bad "robots.txt served"
[ "$(status "$BASE/50x.html")" = 404 ]               && ok "stock 50x page gone"   || bad "stock 50x page gone"
[ "$(status -H 'Host: evil.com' "$BASE/static")" = 301 ] && ok "directory redirect is 301" || bad "directory redirect is 301"
dirloc=$(hdr -H 'Host: evil.com' "$BASE/static" | grep -i '^location:' | awk '{print $2}' || true)
[ "$dirloc" = "/static/" ] && ok "directory redirect is relative" || bad "directory redirect is relative (got: $dirloc)"

hdr "$BASE/static/fonts/outfit-700.woff2" | grep -qi '^content-type: font/woff2' && ok "woff2 mime type" || bad "woff2 mime type"
hdr "$BASE/static/fonts/outfit-700.woff2" | grep -qi 'immutable'                && ok "fonts cached immutable" || bad "fonts cached immutable"
hdr "$BASE/" | grep -qi '^cache-control: no-cache'                              && ok "html no-cache"         || bad "html no-cache"

check_headers() {  # $1 = label, rest = curl args
  local label=$1; shift
  local h; h=$(hdr "$@")
  grep -qi "^content-security-policy: default-src 'none'"          <<<"$h" && ok "CSP on $label"        || bad "CSP on $label"
  grep -qi '^x-content-type-options: nosniff'                       <<<"$h" && ok "nosniff on $label"    || bad "nosniff on $label"
  grep -qi '^x-frame-options: DENY'                                 <<<"$h" && ok "XFO on $label"        || bad "XFO on $label"
  grep -qi '^referrer-policy: strict-origin-when-cross-origin'      <<<"$h" && ok "referrer on $label"   || bad "referrer on $label"
  grep -qi '^permissions-policy: camera=()'                         <<<"$h" && ok "permissions on $label"|| bad "permissions on $label"
  grep -qi '^strict-transport-security: max-age=31536000$'          <<<"$h" && ok "HSTS on $label"       || bad "HSTS on $label"
}
for path in / /healthz /static/style.css /static/fonts/outfit-700.woff2 /does-not-exist /static /.hidden; do
  check_headers "$path" "$BASE$path"
done
check_headers "www redirect" -H 'Host: www.graham-williams.com' "$BASE/"
! hdr "$BASE/" | grep -qiE '^server: nginx/'  && ok "server version hidden" || bad "server version hidden"
[ "$(status "$BASE/.hidden")" = 404 ] && ok "dotfiles are 404" || bad "dotfiles are 404"

[ "$(status -H 'Host: www.graham-williams.com' "$BASE/x?y=1")" = 301 ] && ok "www redirect is 301" || bad "www redirect is 301"
redir=$(curl -s -o /dev/null -w '%{redirect_url}' -H 'Host: www.graham-williams.com' "$BASE/x?y=1")
[ "$redir" = "https://graham-williams.com/x?y=1" ] && ok "www redirects to apex" || bad "www redirects to apex (got: $redir)"

HTML=$(curl -fsS "$BASE/")
! grep -qiE '<script|<style| style=' <<<"$HTML" && ok "no inline script/style" || bad "no inline script/style"
for host in km todoist-points taste-twin jjho dashboard; do
  grep -q "https://$host.graham-williams.com/" <<<"$HTML" && ok "links $host" || bad "links $host"
done
grep -q 'https://github.com/Graham-Williams/gremlins-minecraft-mods' <<<"$HTML" && ok "links gremlins repo" || bad "links gremlins repo"

# Every href on both pages must be site-relative or on the allowlist.
hrefs() { grep -oiE 'href[[:space:]]*=[[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]>]+)' <<<"$1" \
          | sed -E 's/^[Hh][Rr][Ee][Ff][[:space:]]*=[[:space:]]*//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/'; }
NOTFOUND=$(curl -s "$BASE/does-not-exist")
for page in index 404; do
  body=$HTML; [ "$page" = 404 ] && body=$NOTFOUND
  stray=$(hrefs "$body" \
    | grep -vE '^/([^/\\]|$)' \
    | grep -vE '^https://([a-z0-9-]+\.)?graham-williams\.com/' \
    | grep -vE '^https://github\.com/Graham-Williams(/|$)' \
    | grep -vE '^https://www\.linkedin\.com/in/graham-williams/?$' || true)
  [ -z "$stray" ] && ok "hrefs allowlisted ($page)" || bad "hrefs allowlisted ($page): $stray"
  [ "$(hrefs "$body" | wc -l)" -ge 3 ] && ok "hrefs extracted ($page)" || bad "hrefs extracted ($page): none found"
done
! grep -qiE '<meta[^>]+http-equiv' <<<"$HTML" && ok "no meta refresh" || bad "no meta refresh"
! grep -qE 'url\(["'"'"']?https?:' static/style.css && ok "no remote assets in CSS" || bad "no remote assets in CSS"

exit $fail
