# syntax=docker/dockerfile:1

FROM php:8.4-fpm AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    libicu-dev \
    libzip-dev \
    libsqlite3-dev \
    libxml2-dev \
 && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install -j$(nproc) \
    intl \
    pdo \
    pdo_sqlite \
    zip \
    soap \
    ftp \
    sockets \
    pcntl \
    opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
ARG ASSET_NAME=release.zip
ARG APP_ENV=prod
# Pin a specific release (e.g. v1.2.3) for reproducible builds. "latest" always
# downloads the newest release; note that Docker caches this layer, so use
# --no-cache (or set a version) to force a re-download.
ARG SYNCENGINE_VERSION=latest

RUN set -e; \
    if [ "$SYNCENGINE_VERSION" = "latest" ]; then \
      url="https://github.com/SyncEngine/SyncEngine/releases/latest/download/${ASSET_NAME}"; \
    else \
      url="https://github.com/SyncEngine/SyncEngine/releases/download/${SYNCENGINE_VERSION}/${ASSET_NAME}"; \
    fi; \
    mkdir -p /tmp/release; \
    curl -fL "$url" -o /tmp/release.zip; \
    unzip -q /tmp/release.zip -d /tmp/release; \
    cp -a /tmp/release/. /app/; \
    rm -rf /tmp/release /tmp/release.zip

RUN if [ "$APP_ENV" = "dev" ]; then \
      composer install --prefer-dist --no-progress --no-interaction; \
    else \
      composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader; \
    fi
RUN if [ -f .env ]; then cp .env .env.local; fi

RUN mkdir -p /app/var/cache /app/var/log /app/var/data
RUN mkdir -p /app-default/secrets /app-default/modules /app-default/blueprints
RUN mkdir -p /app/config/secrets /app/modules /app/blueprints

RUN sh -lc 'cp -a /app/config/secrets/. /app-default/secrets/ 2>/dev/null || true'
RUN sh -lc 'cp -a /app/modules/. /app-default/modules/ 2>/dev/null || true'
RUN sh -lc 'cp -a /app/blueprints/. /app-default/blueprints/ 2>/dev/null || true'

FROM php:8.4-fpm AS fpm

LABEL org.opencontainers.image.title="SyncEngine (php-fpm)" \
      org.opencontainers.image.description="SyncEngine application server" \
      org.opencontainers.image.source="https://github.com/SyncEngine/docker" \
      org.opencontainers.image.url="https://syncengine.io"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev \
    libzip-dev \
    libsqlite3-0 \
    libxml2 \
    ca-certificates \
    gosu \
    libfcgi-bin \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

COPY <<'EOF' /usr/local/etc/php/conf.d/app.ini
expose_php=0
memory_limit=512M
upload_max_filesize=64M
post_max_size=64M
max_execution_time=240
max_input_vars=5000
display_errors=Off
log_errors=On
error_reporting=E_ALL
EOF

# Enable the php-fpm ping endpoint so containers can be health-checked with
# cgi-fcgi (see docker-compose.yml).
COPY <<'EOF' /usr/local/etc/php-fpm.d/zz-monitoring.conf
[www]
ping.path = /ping
pm.status_path = /status
EOF

ARG APP_ENV=prod
RUN if [ "$APP_ENV" = "dev" ]; then \
      { \
        echo "opcache.enable=0"; \
        echo "opcache.enable_cli=0"; \
        echo "realpath_cache_size=0"; \
        echo "realpath_cache_ttl=0"; \
        echo "display_errors=On"; \
      } > /usr/local/etc/php/conf.d/zz-env.ini; \
    else \
      { \
        echo "opcache.enable=1"; \
        echo "opcache.enable_cli=0"; \
        echo "opcache.memory_consumption=192"; \
        echo "opcache.interned_strings_buffer=16"; \
        echo "opcache.max_accelerated_files=20000"; \
        echo "opcache.validate_timestamps=1"; \
        echo "opcache.revalidate_freq=2"; \
      } > /usr/local/etc/php/conf.d/zz-env.ini; \
    fi

WORKDIR /app
COPY --from=build /app /app
COPY --from=build /app-default /app-default
COPY docker/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

RUN mkdir -p /app/var /app/var/cache /app/var/log /app/var/data /app/config /app/modules /app/blueprints
RUN touch /app/config/modules.yaml /app/.env.local
RUN chown -R www-data:www-data /app/var /app/config /app/modules /app/blueprints
RUN chown www-data:www-data /app/.env.local /app/config/modules.yaml

# php-fpm shuts down gracefully on SIGQUIT (SIGTERM is an immediate stop)
STOPSIGNAL SIGQUIT

ENTRYPOINT ["entrypoint"]
CMD ["php-fpm","-F"]

FROM nginx:1.27-alpine AS nginx

LABEL org.opencontainers.image.title="SyncEngine (nginx)" \
      org.opencontainers.image.description="SyncEngine web server" \
      org.opencontainers.image.source="https://github.com/SyncEngine/docker" \
      org.opencontainers.image.url="https://syncengine.io"

WORKDIR /app
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/public /app/public

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO /dev/null http://127.0.0.1/healthz || exit 1
