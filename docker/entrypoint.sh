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

# If no APP_SECRET was provided, generate one once and persist it in the
# secrets volume so it survives container recreation (a changing secret
# would invalidate sessions, remember-me cookies and signed URLs).
if [ -z "${APP_SECRET:-}" ]; then
  if [ ! -s /app/config/secrets/.app_secret ]; then
    php -r 'echo bin2hex(random_bytes(32));' > /app/config/secrets/.app_secret
    chmod 600 /app/config/secrets/.app_secret
  fi
  APP_SECRET="$(cat /app/config/secrets/.app_secret)"
  export APP_SECRET
fi

chown -R www-data:www-data /app/var /app/config/secrets
chown www-data:www-data /app/config/modules.yaml /app/.env.local

# Set CHOWN_MODULES=0 when bind-mounting local folders for development,
# otherwise the ownership of your local files would be changed (see README)
if [ "${CHOWN_MODULES:-1}" = "1" ]; then
  chown -R www-data:www-data /app/modules /app/blueprints
fi

if [ "${RUN_MIGRATIONS:-0}" = "1" ]; then
  echo "Running database migrations..."
  gosu www-data php /app/bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
fi

if [ "${RUN_AS_WWWDATA:-0}" = "1" ]; then
  exec gosu www-data "$@"
fi

exec "$@"
