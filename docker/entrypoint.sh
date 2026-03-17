#!/usr/bin/env sh
set -e

mkdir -p /app/config/secrets /app/modules /app/blueprints /app/var/data /app/var/cache /app/var/log

if [ -z "$(ls -A /app/config/secrets 2>/dev/null)" ]; then
  cp -a /app-default/secrets/. /app/config/secrets/ 2>/dev/null || true
fi

if [ -z "$(ls -A /app/modules 2>/dev/null)" ]; then
  cp -a /app-default/modules/. /app/modules/ 2>/dev/null || true
fi

if [ -z "$(ls -A /app/blueprints 2>/dev/null)" ]; then
  cp -a /app-default/blueprints/. /app/blueprints/ 2>/dev/null || true
fi

if [ ! -e /app/var/data/data.db ]; then
  touch /app/var/data/data.db
fi

touch /app/config/modules.yaml /app/.env.local

chown -R www-data:www-data /app/var
chown -R www-data:www-data /app/config/secrets /app/modules /app/blueprints
chown www-data:www-data /app/config/modules.yaml /app/.env.local

if [ "${RUN_AS_WWWDATA:-0}" = "1" ]; then
  exec gosu www-data "$@"
fi

exec "$@"