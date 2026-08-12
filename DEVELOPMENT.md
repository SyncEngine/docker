# SyncEngine Docker – Developer guide

Everything in this document is optional — the [README](README.md) covers normal usage. This guide is for people who want to develop SyncEngine modules, work on this Docker setup itself, or understand what happens under the hood.

## How the setup works

The stack consists of three services built from one multi-stage `Dockerfile`:

| Service | Image stage | Description |
|---|---|---|
| `server` | `nginx` | nginx, serves static assets and proxies PHP requests to php-fpm |
| `php` | `fpm` | php-fpm application server (runs migrations on start) |
| `worker` | `fpm` | Symfony Messenger consumer for background/async jobs (`messenger:consume async`), restarts automatically |

The `build` stage downloads a SyncEngine release from GitHub, installs Composer dependencies, and stashes copies of the default `secrets`, `modules` and `blueprints` in `/app-default`. On container start the entrypoint (`docker/entrypoint.sh`):

1. seeds empty `secrets`/`modules`/`blueprints` volumes from `/app-default`,
2. creates the SQLite database file if missing,
3. generates an `APP_SECRET` (persisted in the secrets volume) if none is set,
4. fixes file ownership for `www-data`,
5. runs database migrations (php service only, `RUN_MIGRATIONS=1`),
6. starts php-fpm — or, for the worker, the console command as `www-data`.

The `php` and `server` containers have healthchecks; `docker compose ps` shows their status. The worker waits for `php` to be healthy so migrations are done before it starts consuming.

### Build arguments

| Arg | Default | Description |
|---|---|---|
| `SYNCENGINE_VERSION` | `latest` | Release tag to download, e.g. `v1.0.0` |
| `APP_ENV` | `prod` | `dev` installs dev dependencies and disables opcache |
| `ASSET_NAME` | `release.zip` | Name of the release asset on GitHub |

## Dev mode

Set in `.env`, then rebuild:

```bash
APP_ENV=dev
APP_DEBUG=1
```

```bash
docker compose build && docker compose up -d
```

Dev builds install Composer dev dependencies and get dev PHP settings (opcache off, no realpath cache, `display_errors=On`). Prod builds run with opcache enabled; changed files are still picked up within ~2 seconds (`opcache.revalidate_freq=2`).

## Developing modules locally

By default, modules live in the `modules_data` volume. If you are developing a module, you can mount a local folder into the containers instead, so you can edit the code with your own editor and see the changes immediately.

Create a `docker-compose.override.yml` next to `docker-compose.yml` (it is picked up automatically by `docker compose` and ignored by git):

```yaml
services:
  php:
    volumes:
      - ./modules:/app/modules
    environment:
      CHOWN_MODULES: "0"
  worker:
    volumes:
      - ./modules:/app/modules
    environment:
      CHOWN_MODULES: "0"
```

Then restart:

```bash
docker compose up -d
```

Notes:

- `./modules` is a folder on your machine (adjust the path to wherever your module code lives). Mounting to the same container path `/app/modules` replaces the `modules_data` volume for these services.
- If the folder is empty on first start, the default modules that ship with the release are copied into it, giving you a working starting point. Note that these seeded files are created by the container and end up owned by root on Linux hosts — run `sudo chown -R $USER: ./modules` once to take ownership, or simply start with your own module code already in the folder.
- `CHOWN_MODULES: "0"` stops the container from changing the ownership of your local files to `www-data` on start. This means the application itself cannot *write* to the modules folder (e.g. installing modules through the UI) — for module development that is usually what you want. Leave it at `1` if the app must be able to write there.
- The same pattern works for `blueprints`: mount a local folder to `/app/blueprints`.

## Makefile shortcuts

If you have `make` installed, common tasks are available as short commands:

```bash
make help     # list all available targets
make env      # create .env from .env.example
make up       # build + start everything
make update   # update to the newest SyncEngine release
make logs     # follow logs (make logs S=php for a single service)
make shell    # shell into the php container
make console CMD="cache:clear"
make backup   # dump the SQLite database to ./backups/
make down     # stop (data is kept)
```

`make` is preinstalled on most Linux servers and comes with the Xcode Command Line Tools on macOS (`xcode-select --install`). On Debian/Ubuntu it's `apt install make`, on Fedora `dnf install make`. On Windows it isn't available natively — use WSL, or `winget install GnuWin32.Make`. The Makefile is only a convenience: every target is a plain `docker compose` command, and everything can be done without it using the commands in the README.
