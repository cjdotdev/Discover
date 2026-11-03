#!/bin/sh
# Le démarrage sur Railway : le disque (un volume monté sur /app/storage) est préparé, la base
# Neon migrée, puis l'ouvrier des tâches et le planificateur partent à côté du serveur web.
set -e
cd /app

mkdir -p storage/app/private storage/app/public storage/framework/cache/data \
    storage/framework/sessions storage/framework/views storage/logs

# Les migrations passent par la connexion directe de Neon (DB_URL_DIRECTE) : le pooler
# (mode transaction) les refuse.
DB_URL="${DB_URL_DIRECTE:-$DB_URL}" php artisan migrate --force
php artisan usw:base-locale
php artisan config:cache
php artisan route:cache
php artisan event:cache

# L'ouvrier se relance toutes les heures (mémoire neuve) ; le planificateur, s'il tombe.
(while true; do php artisan queue:work --tries=3 --timeout=600 --sleep=1 --max-time=3600; sleep 1; done) &
(while true; do php artisan schedule:work; sleep 5; done) &

# Les villes du monde, la première fois seulement (quelques minutes, à côté du serveur).
(nice -n 19 php artisan usw:importer-localites --si-vide || true) &

# Les sons du catalogue pas encore là (database/sons/catalogue.json), à côté aussi.
(nice -n 19 php artisan usw:importer-sons || true) &

exec frankenphp php-server --listen ":${PORT:-8080}" --root public/
