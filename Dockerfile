# graham-williams.com — static page on nginx, running as a non-root user.
# Pinned to an exact stable release by tag AND digest; bump both deliberately
# (Dependabot opens the PR).
FROM nginxinc/nginx-unprivileged:1.31.5-alpine@sha256:2ddec616f1cb58bcac057aa388f28cb81e35137641ef4226d321714499329bd1

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
