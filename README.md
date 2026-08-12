# SyncEngine – Docker

Docker setup for [SyncEngine](https://github.com/SyncEngine/SyncEngine): an nginx web server, a php-fpm application container, and a Messenger worker for background jobs. Uses SQLite and PHP 8.4 by default so no external database needed.


## Quick start

```bash
git clone https://github.com/SyncEngine/docker.git
cd docker
docker compose up -d --build
```

Then open http://localhost:8080 in your browser.

On first start the container automatically:

- downloads the latest SyncEngine release (at build time),
- generates an `APP_SECRET` and persists it in the secrets volume,
- creates the SQLite database and runs the database migrations.

## Configuration

Copy `.env.example` to `.env` and adjust as needed:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|---|---|---|
| `HTTP_PORT` | `8080` | Host port for the web UI |
| `APP_ENV` | `prod` | `prod` or `dev` (build-time, requires rebuild) |
| `APP_DEBUG` | `0` | Enable Symfony debug mode |
| `APP_SECRET` | *(auto-generated)* | Symfony application secret |
| `SYNCENGINE_VERSION` | `latest` | Release to install, e.g. `v1.0.0` (build-time) |
| `DATABASE_URL` | SQLite in `db_data` volume | Doctrine connection string |
| `MAILER_DSN` | `sendmail://default` | Mail transport |
| `RUN_MIGRATIONS` | `1` | Run migrations on php container start |
| `TZ` | `UTC` | Container timezone |

### Using MySQL / MariaDB

Set `DATABASE_URL` in your `.env`:

```
DATABASE_URL=mysql://user:password@db-host:3306/syncengine?serverVersion=8&charset=utf8mb4
```

## Updating

```bash
docker compose build --pull --no-cache
docker compose up -d
```

Pending database migrations run automatically on start (disable with `RUN_MIGRATIONS=0`). Your data lives in named volumes and is preserved across updates. To update to a specific release, set `SYNCENGINE_VERSION` in `.env` first.

## Common tasks

```bash
# Run a console command
docker compose exec php php bin/console

# Follow logs
docker compose logs -f php worker server

# Restart the background worker
docker compose restart worker

# Open a shell in the app container
docker compose exec php bash
```

## Data & backups

All persistent data is stored in named Docker volumes:

| Volume | Contents |
|---|---|
| `db_data` | SQLite database (`/app/var/data`) |
| `secrets_data` | Secrets, including the generated `APP_SECRET` |
| `modules_data` | Installed modules |
| `blueprints_data` | Blueprints |

Backup the SQLite database:

```bash
docker compose exec php sh -c 'cat /app/var/data/data.db' > syncengine-backup-$(date +%F).db
```

## Stop

```bash
docker compose down
```

Add `-v` to also delete all data volumes (destructive!).

## For developers

Developing modules with a locally mounted folder, dev mode, Makefile shortcuts, and how this setup works under the hood: see [DEVELOPMENT.md](DEVELOPMENT.md).
