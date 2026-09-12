#!/usr/bin/env bash
# Stamp index.html and 404.html with the current content hash of the stylesheet
# and favicon (?v=<sha256 prefix>). Run after editing either asset; tests fail
# if the stamps are stale. Cloudflare's edge floors short browser-cache TTLs at
# 4 h, so a changing URL is what makes a CSS edit visible immediately.
set -euo pipefail
cd "$(dirname "$0")/.."
css=$(shasum -a 256 static/style.css | cut -c1-8)
ico=$(shasum -a 256 static/favicon.svg | cut -c1-8)
for f in index.html 404.html; do
  sed -E -i.bak "s#/static/style\.css(\?v=[^"]*)?#/static/style.css?v=$css#g; s#/static/favicon\.svg(\?v=[^"]*)?#/static/favicon.svg?v=$ico#g" "$f"
  rm -f "$f.bak"
done
echo "style.css?v=$css  favicon.svg?v=$ico"
