# Discover

Discover est une application mobile participative de photos et de reels touristiques 100 % réels. Chaque contenu dit où, quand et avec quel téléphone il a été pris, et le bouton « Y aller » ouvre l'itinéraire jusqu'au lieu de la prise de vue.

## Le dépôt

| Dossier ou fichier | Contenu |
|---|---|
| `usw_mobile/` | **L'application** (Flutter), version 2026, reliée au serveur en ligne |
| `usw_api/` | **Le serveur** : API Laravel 13, base PostgreSQL (Neon), déployée sur Railway |
| `ia/` | Worker Cloudflare qui décrit les photos pour la recherche |
| `relais-liens/` | Worker Cloudflare du site et des liens partagés |
| `discover_mobile/` | Le MVP réalisé à quatre pour le cours, avec des données simulées |
| [`repartition.md`](repartition.md) | Qui fait quoi dans le MVP, et les spécifications du backend |
| [`docs/Discover_liaisons_application_serveur_base.pdf`](docs/Discover_liaisons_application_serveur_base.pdf) | Comment l'application, le serveur et la base de données sont reliés |
| `docs/maquette/` | Les 40 maquettes du MVP |

## Installer l'application

L'APK signé par l'équipe a tout : connexion avec Google ou par e-mail, carte, notifications. Il parle au serveur en ligne : `https://discover-production-6cca.up.railway.app/api/v1`.

## Compiler l'application soi-même

Il faut Flutter 3.47 ou plus, et un téléphone Android branché ou un émulateur.

```bash
cd usw_mobile
flutter pub get
flutter run
```

L'application parle directement au serveur en ligne : il n'y a rien à régler. Nos fichiers privés ne sont pas dans ce dépôt public, donc une application compilée ainsi a quelques limites :

- la carte Google a besoin d'une clé dans `usw_mobile/cles.json` (modèle : `cles.exemple.json`) ;
- les notifications push ont besoin de `usw_mobile/android/app/google-services.json` ;
- la connexion avec Google n'accepte que l'application signée par l'équipe ; la connexion par e-mail marche partout ;
- l'application signée par l'équipe et celle compilée chez soi ont le même identifiant (`bj.usw`) mais pas la même signature : il faut désinstaller l'une pour installer l'autre.

## Lancer le serveur en local

```bash
cd usw_api
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

Il faut une base PostgreSQL et remplir `.env` (les noms des variables sont dans `.env.example`). On lance alors l'application avec `flutter run --dart-define=API=http://10.0.2.2:8000/api/v1` sur un émulateur Android.

## Le MVP du cours

```bash
cd discover_mobile
flutter pub get
flutter run
```

Il tourne avec des données simulées : compte `membre@discover.bj`, mot de passe `Discover1`, code `123456`.

## Vérifier avant de pousser

```bash
dart format lib test
flutter analyze
flutter test
```

Aucun secret dans ce dépôt public : ni `.env`, ni `cles.json`, ni `google-services.json`, ni clé de signature.

## Licences

La police Wura Mi est sous licence OFL. Les photos de `discover_mobile/assets/images/` sont sous licence CC0 (StockSnap).
