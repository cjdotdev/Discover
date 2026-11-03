# Discover en production (Railway). FrankenPHP sert l'API ; l'ouvrier des tâches et le
# planificateur tournent dans le même conteneur (docker/demarrer.sh) : la file, le cache
# et les envois en cours vivent sur son disque (/app/storage, un volume Railway).
# La base est sur Neon, les photos et les vidéos sur Cloudflare R2.

# Composer a une version fixe : la meme a chaque construction (et une image neuve quand le cache
# du constructeur de Railway s abime sur la precedente).
FROM composer:2.8.9 AS dependances
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction --ignore-platform-reqs
COPY . .
RUN composer dump-autoload --optimize --no-dev --no-scripts

FROM dunglas/frankenphp:1-php8.4

# Postgres (Neon), les images (WebP), les dates, les vidéos des reels (ffmpeg).
RUN install-php-extensions pdo_pgsql gd intl zip bcmath exif pcntl opcache \
    && apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY docker/php.ini $PHP_INI_DIR/conf.d/discover.ini

WORKDIR /app
COPY --from=dependances /app /app
RUN php artisan package:discover --ansi && chmod +x docker/demarrer.sh

ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    FFMPEG=/usr/bin/ffmpeg \
    DB_LOCALE_DATABASE=/app/storage/locale.sqlite

CMD ["docker/demarrer.sh"]
