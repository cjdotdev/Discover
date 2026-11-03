# usw_api

L'API de Discover (nom de code USW) : des lieux en vraies photos. Laravel 13, PHP 8.5.12 au
minimum, jetons Sanctum pour l'application mobile (`usw_mobile`). L'architecture est décrite dans
`conception-usw/analyse/ARCHITECTURE.md` ; on avance lot par lot (section 11).

## Démarrer

```sh
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

- `GET /up` : le bilan de santé de Laravel.
- `GET /api/v1/etat` : `{"nom":"Discover","version":"v1"}` (USW est le nom de code du projet).
- Compte (lot 1), sans mot de passe : `POST auth/code/envoyer` (un code à 6 chiffres part à
  l'adresse, valable 10 minutes, 5 essais), puis `POST auth/code` (il ouvre le compte, ou le crée :
  201 et `"nouveau": true`) ; `auth/google`, `auth/deconnexion` ; `GET/PATCH/DELETE moi`,
  `POST moi/avatar`. Tant que Resend n'a pas sa clé, le code est dans `storage/logs/laravel.log`. Un compte supprimé
  est effacé après 30 jours (`usw:purger-comptes`) ; se reconnecter avant annule la suppression.
- Lieux et contenus (lot 2), ouverts aux visiteurs : `GET lieux/{slug}` (avec ses 4 meilleures
  photos), `GET lieux/{slug}/contenus?type=reel&curseur=…` (20 par page), `GET lieux/proche?latitude=…&longitude=…`
  (le lieu connu à moins de 2 km), `GET contenus/{ulid}`. Avec un compte : `GET modeles-telephone?q=…`,
  `POST modeles-telephone`. Aucune donnée de démonstration : `php artisan db:seed` ne crée rien,
  Discover se remplit des vraies publications (`php artisan storage:link` pour le disque public local).
- Publier (lot 3) : `POST contenus` (le brouillon et ses deux envois), `HEAD/PATCH envois/{ulid}`
  (les morceaux, façon tus), `POST envois/{ulid}/terminer`, puis `AnalyserCapture` (file des tâches :
  `php artisan queue:work`) publie avec son badge ou refuse. `GET contenus/{ulid}/original` :
  télécharger (la 2 160 px, ou l'original s'il est gardé). `GET moi/envois`.
- Explorer (lot 4), ouvert aux visiteurs : `GET flux/decouverte?curseur=…&types=…` (les lieux et
  leur pile, 20 par page, gardés 60 s en cache), `GET flux/pres-de-moi?latitude=…&longitude=…&rayon=…`,
  `GET reels?curseur=…` (`latitude`/`longitude` : Près de moi ; `abonnements=1` : les créateurs suivis),
  `GET carte?nord=…&sud=…&est=…&ouest=…`, `GET recherche?q=…` (lieux et créateurs, accents ignorés),
  `GET utilisateurs/{nom}` et `/contenus` ; avec un compte, `GET moi/contenus`.
- Communauté (lot 5) : `PUT/DELETE contenus/{id}/reaction` (cœur, waouh, voyage, merci),
  `GET contenus/{id}/reactions`, `GET/POST contenus/{id}/commentaires` (réponses à un niveau,
  @mentions), `GET commentaires/{id}/reponses`, `PATCH/DELETE commentaires/{id}`,
  `POST commentaires/{id}/epingle`, `PUT/DELETE commentaires/{id}/jaime`,
  `PUT/DELETE utilisateurs/{nom}/abonnement`, `GET moi/abonnements`, `PUT/DELETE utilisateurs/{nom}/blocage`,
  `GET/POST collections`, `PATCH/DELETE collections/{id}`, `GET collections/{id}/contenus`,
  `PUT/DELETE collections/{id}/contenus/{contenu}`, `GET utilisateurs/{nom}/collections`,
  `POST contenus/{id}/partage`, `POST signalements`. Chaque publication renvoyée à un membre porte
  sa part : `moi.reaction`, `moi.enregistre`.
- Modération (lot 6), administrateurs seuls : `GET moderation/file?file=a_verifier|signalements`,
  `POST moderation/contenus/{id}/decision` (publier, refuser avec motif), `POST moderation/contenus/{id}/classer`,
  `POST moderation/commentaires/{id}/masquer`. Le rôle se donne sur le serveur : `php artisan usw:admin e-mail`.
- Notifications (lot 7) : `GET notifications`, `POST notifications/lues` (réactions, commentaires,
  réponses, mentions, abonnés, publication en ligne ou refusée). Le push FCM attend Firebase.
- Google attend `GOOGLE_CLIENT_IDS` (projet Google Cloud à créer).
- Sur le téléphone branché en USB : `adb reverse tcp:8000 tcp:8000`, puis `php artisan serve`.

## Où vivent les données

| Quoi | Où | Réglage |
|---|---|---|
| Comptes, lieux, contenus, envois | Neon (PostgreSQL) | `DB_CONNECTION=pgsql`, `DB_URL` (chaîne de Neon, `sslmode=require`) |
| File des tâches, cache | SQLite du serveur (`database/locale.sqlite`, créée seule) | connexion `locale` : l'ouvrier la lit chaque seconde sans réveiller Neon |
| Tailles d'image, vidéos, avatars | Cloudflare R2, seau public | `DISCOVER_MEDIAS=r2`, `R2_*` |
| Originaux | le téléphone de leur auteur | gardés sur R2 privé seulement si `DISCOVER_GARDER_ORIGINAUX=true` |
| Codes par e-mail | Resend | `MAIL_MAILER=resend`, `RESEND_API_KEY`, `MAIL_FROM_ADDRESS` sur un domaine vérifié |

En local, sans clés : SQLite (`database/database.sqlite`), le disque public, les e-mails dans le
journal. Les tests tournent sur SQLite en mémoire, et passent aussi sur PostgreSQL :
`DB_CONNECTION=pgsql DB_HOST=… DB_DATABASE=… php artisan test`.

Pour que la base reste petite : l'original vérifié n'est pas gardé (seule son empreinte, contre
les doublons), les fichiers de travail sont effacés après l'analyse, et chaque nuit partent les
codes de plus d'un jour (`model:prune`), les jetons muets depuis 6 mois, les notifications de plus
de 60 jours, les envois abandonnés
(`usw:purger-envois`) et les comptes supprimés (`usw:purger-comptes`). Il faut lancer
`php artisan schedule:work` (ou la tâche cron de `schedule:run`) sur le serveur.

Les positions sont en latitude et longitude (index composé) : la proximité se cherche par un
rectangle dans la base, puis par la vraie distance (`App\Support\Geo`), sur SQLite comme sur PostgreSQL.

## Contrôles

```sh
php artisan test           # tous les tests
vendor/bin/pint            # le style de code du groupe
php artisan usw:verifier-php   # échoue si PHP est vulnérable à php2shell (à chaque déploiement)
```

## Conventions

- Toutes les routes de l'application sont sous `/api/v1`, en JSON (`routes/api.php`).
- Une seule forme d'erreur, que l'application affiche telle quelle
  (`app/Exceptions/ErreursApi.php`) :

  ```json
  { "message": "Code incorrect.", "erreurs": { "code": ["Code incorrect. Encore 4 essais."] } }
  ```

  `erreurs` n'apparaît que pour une validation (422). Aucun détail interne hors du poste de
  développement (`APP_DEBUG=false`).
- Les messages sont en français (`lang/fr`).
- Noms métier en français, comme dans le diagramme de classes (`Contenu` → `contenus`).

## Les lots

| Lot | Contenu | État |
|---|---|---|
| 0. Socle | Laravel 13, Sanctum, format d'erreur, Pint, PHPUnit, `usw:verifier-php` | fait |
| 1. Compte | Code par e-mail (sans mot de passe) et Google, profil, déconnexion, suppression | fait et branché sur l'application ; Google attend son identifiant |
| 2. Lieux et contenus | Pays, villes, lieux, contenus, captures, modèles de téléphone, rapprochement d'un lieu | fait |
| 3. Envoi et vérification | Envoi par morceaux, AnalyserCapture, variantes WebP, vidéo des reels | fait et branché (77 tests, SQLite et PostgreSQL) |
| 4. Exploration | Flux, reels, Près de moi, carte, recherche, filtres, profils | fait et branché |
| 5. Communauté | Réactions, commentaires, collections, abonnements, partage, blocages, signalements | fait et branché (100 tests en tout, SQLite et PostgreSQL) |
| 6. Modération | File « à vérifier » et signalements, décisions, commentaires masqués | fait et branché, pour l'administrateur seul (`php artisan usw:admin e-mail`) |
| 7. Notifications | Centre (fait et branché), push FCM | le push attend Firebase |
| 8. Production | Performances, revue de sécurité, déploiement | à faire |
