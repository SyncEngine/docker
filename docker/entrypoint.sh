#!/usr/bin/env sh
set -e
mkdir -p /app/config/secrets /app/modules /app/blueprints /app/var/data
if [ -z "$(ls -A /app/config/secrets 2>/dev/null)" ]; then cp -a /app-default/secrets/. /app/config/secrets/ 2>/dev/null || true; fi
if [ -z "$(ls -A /app/modules 2>/dev/null)" ]; then cp -a /app-default/modules/. /app/modules/ 2>/dev/null || true; fi
if [ -z "$(ls -A /app/blueprints 2>/dev/null)" ]; then cp -a /app-default/blueprints/. /app/blueprints/ 2>/dev/null || true; fi
if [ ! -e /app/var/data/data.db ]; then touch /app/var/data/data.db; fi
chown -R www-data:www-data /app/var /app/config/secrets /app/modules /app/blueprints
exec "$@"
