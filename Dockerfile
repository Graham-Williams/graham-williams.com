# graham-williams.com — static page on nginx, running as a non-root user.
# Pinned to an exact stable release by tag AND digest; bump both deliberately
# (Dependabot opens the PR).
FROM nginxinc/nginx-unprivileged:1.30.5-alpine@sha256:ed04ec1ff34502c339ee5c3ae3f855442398edc1d05591e2b98981dcbbd20b1e

USER root
# Drop the stock site and its error page; we ship a complete nginx.conf.
RUN rm -f /etc/nginx/conf.d/default.conf /usr/share/nginx/html/50x.html
COPY nginx.conf /etc/nginx/nginx.conf
COPY snippets/ /etc/nginx/snippets/
COPY index.html 404.html robots.txt /usr/share/nginx/html/
COPY static/ /usr/share/nginx/html/static/
USER 101

EXPOSE 8080
HEALTHCHECK --interval=60s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1
