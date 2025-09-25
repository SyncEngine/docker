FROM php:8.2-fpm AS build
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libicu-dev libzip-dev libsqlite3-dev libxml2-dev && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install -j$(nproc) intl opcache pdo pdo_sqlite zip soap ftp sockets pcntl
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
ARG REPO=https://github.com/SyncEngine/SyncEngine.git
ARG REF=master
RUN git clone --depth 1 --branch ${REF} ${REPO} /app

RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader
RUN if [ -f .env ]; then cp .env .env.local; fi
RUN mkdir -p var/cache var/log var/data && chown -R www-data:www-data var
RUN mkdir -p /app-default/secrets /app-default/modules /app-default/blueprints
RUN mkdir -p config/secrets modules blueprints
RUN sh -lc 'cp -a config/secrets/. /app-default/secrets/ 2>/dev/null || true'
RUN sh -lc 'cp -a modules/. /app-default/modules/ 2>/dev/null || true'
RUN sh -lc 'cp -a blueprints/. /app-default/blueprints/ 2>/dev/null || true'

FROM php:8.2-fpm AS fpm
RUN apt-get update && apt-get install -y --no-install-recommends libicu-dev libzip-dev libsqlite3-0 libxml2 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
RUN sh -lc 'echo "expose_php=0" > /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "max_execution_time=240" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "max_input_vars=5000" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "realpath_cache_size=4096K" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "realpath_cache_ttl=600" >> /usr/local/etc/php/conf.d/app.ini'
RUN sh -lc 'echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.enable_cli=0" >> /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.jit=1255" >> /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.jit_buffer_size=64M" >> /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini'
RUN sh -lc 'echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini'
WORKDIR /app
COPY --from=build /app /app
COPY --from=build /app-default /app-default
COPY docker/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
RUN chown -R www-data:www-data /app/var
ENTRYPOINT ["entrypoint"]
CMD ["php-fpm","-F"]

FROM nginx:1.27-alpine AS nginx
WORKDIR /app
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/public /app/public
