# SyncEngine Docker

A [Docker](https://www.docker.com/)-based installer and runtime for [SyncEngine](https://syncengine.io/) with [FrankenPHP](https://frankenphp.dev) and [Caddy](https://caddyserver.com/) inside!

## Getting Started

1. If not already done, [install Docker Compose](https://docs.docker.com/compose/install/) (v2.10+)
2. Donwload SyncEngine and copy this repo inside the root folder
3. Run `docker compose build --no-cache` to build fresh images
4. Run `docker compose up --pull always -d --wait` to set up and start a fresh SyncEngine project
5. Open `https://localhost` in your favorite web browser and [accept the auto-generated TLS certificate](https://stackoverflow.com/a/15076602/1352334)
   1. As default DATABASE set `sqlite:///%kernel.project_dir%/var/data.db` 
   2. Other installation options are optional 
6. Run `docker compose down --remove-orphans` to stop the Docker containers.

## Features

* Production, development and CI ready
* Just 1 service by default
* Blazing-fast performance thanks to [the worker mode of FrankenPHP](https://github.com/dunglas/frankenphp/blob/main/docs/worker.md) (automatically enabled in prod mode)
* [Installation of extra Docker Compose services](docs/extra-services.md) with Symfony Flex
* Automatic HTTPS (in dev and prod)
* HTTP/3 and [Early Hints](https://symfony.com/blog/new-in-symfony-6-3-early-hints) support
* Real-time messaging thanks to a built-in [Mercure hub](https://symfony.com/doc/current/mercure.html)
* [Vulcain](https://vulcain.rocks) support
* Native [XDebug](docs/xdebug.md) integration
* Super-readable configuration
* Including [PHP GD](https://www.php.net/manual/en/book.image.php) extension for spreadsheet support

**Enjoy!**

## Docs

1. [Options available](https://github.com/dunglas/symfony-docker/blob/main/docs/options.md)
2. [TLS Certificates](https://github.com/dunglas/symfony-docker/blob/main/docs/tls.md)