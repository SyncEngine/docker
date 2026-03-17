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
    pcntl

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
ARG ASSET_NAME=release.zip
ARG APP_ENV=prod

RUN set -e; \
    mkdir -p /tmp/release; \
    curl -fL "https://github.com/SyncEngine/SyncEngine/releases/latest/download/${ASSET_NAME}" -o /tmp/release.zip; \
    unzip /tmp/release.zip -d /tmp/release; \
    cp -a /tmp/release/. /app/

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

RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev \
    libzip-dev \
    libsqlite3-0 \
    libxml2 \
    ca-certificates \
    gosu \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
RUN sh -lc 'echo "expose_php=0" > /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "max_execution_time=240" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "max_input_vars=5000" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "display_errors=Off" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "log_errors=On" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "error_reporting=E_ALL" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "realpath_cache_size=0" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "realpath_cache_ttl=0" >> /usr/local/etc/php/conf.d/app.ini'

RUN sh -lc 'echo "opcache.enable=0" > /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.enable_cli=0" >> /usr/local/etc/php/conf.d/opcache.ini'

WORKDIR /app
COPY --from=build /app /app
COPY --from=build /app-default /app-default
COPY docker/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

RUN mkdir -p /app/var /app/var/cache /app/var/log /app/var/data /app/config /app/modules /app/blueprints
RUN touch /app/config/modules.yaml /app/.env.local
RUN chown -R www-data:www-data /app/var /app/config /app/modules /app/blueprints
RUN chown www-data:www-data /app/.env.local /app/config/modules.yaml

ENTRYPOINT ["entrypoint"]
CMD ["php-fpm","-F"]

FROM nginx:1.27-alpine AS nginx
WORKDIR /app
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/public /app/public