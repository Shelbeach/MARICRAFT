FROM nginx:1.30.6-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/web/ /usr/share/nginx/html/

# Keep precompressed companions for gzip_static, and originals for clients/ranges.
RUN set -eu; \
    cd /usr/share/nginx/html; \
    sha256sum -c SHA256SUMS; \
    for file in *.gz; do gzip -dc "$file" > "${file%.gz}"; done; \
    test -s index.html && test -s index.js && test -s index.wasm && test -s index.pck; \
    nginx -t

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
