# Discover : répartition du MVP

But : présenter le projet à notre chargée de cours avec une application qui fonctionne.

On réalise seulement les écrans de la maquette nécessaires au fonctionnement de l'application : **40 maquettes sur 61**. Rien de plus pour le moment.

Ce document répartit le **frontend Flutter**. Le backend est décrit à la fin pour que chacun sache ce que l'API répondra, mais il n'est pas réparti pour l'instant.

---

## Qui fait quoi

| Membre | Partie | Écrans | Charge |
|---|---|---|---|
| **Siméon** | Socle et compte | Base du projet, E00, E01, E02, E36, E37 communs | Socle + 8 points |
| **Joël** | Découverte | E03, E04, E31, E33, E17, E20 | 13 points |
| **Djamal** | Contenus | E05, E06, E07, E11 | 12 points |
| **Ainé Mao** | Publication et profil | E12, E32, E14, E15, E30, E16, E18, E21 | 12 points |

Charge : S = 1 point (une demi-journée), M = 2 points (1 à 2 jours), L = 4 points (3 à 5 jours).

---

## Siméon : socle et compte

**Le socle, utilisé par tout le monde :** thème, icônes, police, boutons, champs, messages, navigation, barre d'onglets, session et client API.

| Code | Écran | Maquette | Taille |
|---|---|---|---|
| E00 | Ouverture | `01-ouverture` | S |
| E01 | Bienvenue, 3 pages | `02-bienvenue-1` à `04-bienvenue-3` | S |
| E02 | Entrée | `05-entree` | M |
| E02 | Mot de passe et son erreur | `06-mot-de-passe`, `54-mdp-erreur` | S |
| E02 | Créer le mot de passe | `07-creer-mdp` | S |
| E02 | Code reçu par e-mail | `08-code` | S |
| E02 | Mot de passe oublié, nouveau mot de passe | `09-oubli`, `10-nouveau-mdp` | S |
| E36 | Compléter le profil, 3 étapes | `11-completer-1` à `13-completer-3` | M |
| E37 | Hors connexion, introuvable, confirmation, bulle | `55-hors-ligne`, `56-introuvable`, `58-dialogue`, `59-bulles` | Socle |

## Joël : découverte

| Code | Écran | Maquette | Fichier Flutter (`lib/fonctionnalites/decouverte/ecrans/`) | Adresse | Taille |
|---|---|---|---|---|---|
| E03 | Accueil : piles de photos, Découverte, Abonnements, Près de moi | `14-accueil` | `accueil.dart` | `/accueil` | L |
| E04 | Filtres | `15-filtres` | `filtres.dart` | `/filtres` | M |
| E31 | Recherche et recherche vide (E37) | `31-recherche`, `61-recherche-vide` | `recherche.dart` | `/recherche` | M |
| E33 | Lieu : ses photos, ses reels, Y aller | `16-lieu` | `lieu.dart` | `/lieu/:id` | M |
| E17 | Notifications | `42-notifications` | `notifications.dart` | `/notifications` | S |
| E20 | Profil d'un créateur | `47-createur` | `createur.dart` | `/createur/:nom` | M |

## Djamal : contenus

| Code | Écran | Maquette | Fichier Flutter (`lib/fonctionnalites/contenus/ecrans/`) | Adresse | Taille |
|---|---|---|---|---|---|
| E05 | Photo : badge, lieu, téléphone, date, Y aller, j'aime | `17-photo` | `photo.dart` | `/photo/:id` | M |
| E06 | Reels : fil vertical plein écran | `22-reels` | `reels.dart` | `/reels` | L |
| E07 | Commentaires | `18-commentaires` | `commentaires.dart` | `/commentaires/:id` | M |
| E11 | Carte et position refusée (E37) | `30-carte`, `60-position-refusee` | `carte.dart` | `/carte` | L |

## Ainé Mao : publication et profil

| Code | Écran | Maquette | Fichier Flutter (`lib/fonctionnalites/`) | Adresse | Taille |
|---|---|---|---|---|---|
| E12 | Créer : prendre une photo, importer, rappel « pas d'IA » | `32-creer` | `publication/ecrans/creer.dart` | `/creer` | S |
| E32 | Autorisations, une seule fois | `33-autoriser` | `publication/ecrans/autorisations.dart` | `/creer/autorisations` | S |
| E14 | Détails : légende, lieu, aperçu | `39-details` | `publication/ecrans/details.dart` | `/creer/details` | M |
| E15 | Compléter : téléphone, date, lieu | `37-completer-capture` | `publication/ecrans/completer_capture.dart` | `/creer/completer` | S |
| E30 | Indiquer le lieu | `38-indiquer-lieu` | `publication/ecrans/indiquer_lieu.dart` | `/creer/lieu` | S |
| E16 | En route, et publication refusée (E37) | `40-en-route`, `57-refusee` | `publication/ecrans/en_route.dart` | `/creer/en-route` | M |
| E18 | Mon profil | `43-profil` | `profil/ecrans/profil.dart` | `/profil` | M |
| E21 | Modifier le profil, réglages | `45-modifier`, `46-reglages` | `profil/ecrans/modifier_profil.dart`, `reglages.dart` | `/profil/modifier`, `/profil/reglages` | M |

---

## Ce qu'on ne fait pas pour le moment

Ces 21 maquettes restent hors du MVP :

- les six variantes de E06 : réagir, réactions, commentaires, partager, enregistrer, télécharger (dans les reels, on garde le j'aime et on réutilise E07) ;
- E08 Télécharger l'original, E09 Enregistrer, E10 Partager, E19 Collection ;
- E22 Signaler, E23 Règles, E24 et E25 Modération ;
- E26 Mes envois ;
- E27 Caméra de reels, E28 Montage, E29 Son (un reel se publie par import depuis la galerie) ;
- E34 Conditions générales, E35 Aide, E38 Confidentialité.

Les fonctions ajoutées ensuite dans l'application et absentes de la maquette ne sont pas à refaire ici.

---

## Comment travailler

### Quand commencer

Siméon pousse le socle sur la branche `simeon`. Une fois la demande de fusion acceptée dans `main`, chacun part de `main`.

**En attendant :** lisez cette répartition, regardez vos maquettes, et préparez vos écrans (ce qu'ils affichent, leurs états vide, chargement et erreur).

### Arborescence

```text
discover_mobile/lib/
├── main.dart                  Point de départ
├── app.dart                   L'application
├── socle/                     Commun à tous : Siméon
│   ├── api/                   Client API et erreurs
│   ├── navigation/            Adresses, routeur, barre d'onglets
│   ├── session/               Jeton et état du compte
│   ├── theme/                 Couleurs, mesures, textes, thème
│   └── widgets/               Boutons, champs, messages, icônes
└── fonctionnalites/
    ├── compte/                Siméon
    ├── decouverte/            Joël
    ├── contenus/              Djamal
    ├── publication/           Ainé Mao
    └── profil/                Ainé Mao
```

Chaque écran à réaliser existe déjà sous forme de fichier d'attente, relié à la navigation. Il suffit de remplacer son contenu, sans changer le nom de la classe.

### Règles

1. Une branche à son nom, partie de `main` : `joel`, `djamal`, `aine-mao`.
2. Chacun modifie seulement son dossier. Pour changer le socle, on prévient Siméon.
3. On réutilise le socle : pas de couleur, de taille de texte ou de bouton écrits à la main dans un écran.
4. Chaque écran suit sa maquette : mêmes textes, mêmes espacements, mêmes couleurs.
5. Avant de pousser : `dart format lib test`, `flutter analyze` et `flutter test` doivent passer.
6. On ouvre une demande de fusion vers `main`. Personne ne pousse directement sur `main`.
7. Aucun secret dans le dépôt : ni `.env`, ni clé, ni `google-services.json`. Le dépôt est public.

### Sans attendre le backend

Chacun travaille avec des données simulées, au format de l'API décrit ci-dessous. Le dossier `fonctionnalites/compte/donnees/` donnera l'exemple : une interface, une version simulée et une version API. Les écrans ne changent pas quand on branche la vraie API.

---

## Spécifications du backend (non réparties)

**Technique :** Laravel 13, PHP 8.5.12 au minimum, MySQL 8.4, Sanctum pour les jetons. Les médias sont sur un stockage compatible S3.

**Règles communes :**

- toutes les routes commencent par `/api/v1` et répondent en JSON ;
- une route marquée ✓ exige le jeton : `Authorization: Bearer <jeton>` ;
- sans ✓, elle est ouverte aux visiteurs, qui peuvent regarder sans compte ;
- une erreur a toujours la forme `{ "message": "...", "erreurs": { "champ": ["..."] } }` ;
- une connexion réussie renvoie `{ "jeton": "...", "profil_complet": true }`.

| Domaine | Routes | Écrans |
|---|---|---|
| Compte | `POST auth/email` (répond seulement `existe`), `POST auth/inscription`, `POST auth/code`, `POST auth/code/renvoyer`, `POST auth/connexion`, `POST auth/google`, `POST auth/oubli`, `POST auth/nouveau-mot-de-passe`, ✓ `POST auth/deconnexion` | E02 |
| Mon profil | ✓ `GET moi`, ✓ `PATCH moi`, ✓ `POST moi/avatar`, ✓ `DELETE moi`, ✓ `GET moi/contenus` | E36, E18, E21 |
| Exploration | `GET flux/decouverte`, ✓ `GET flux/abonnements`, `GET flux/pres-de-moi`, `GET reels`, `GET carte`, `GET recherche?q=` | E03, E04, E06, E11, E31 |
| Lieux et contenus | `GET lieux/{lieu}`, `GET lieux/{lieu}/contenus`, `GET contenus/{contenu}`, `GET utilisateurs/{nom}`, `GET utilisateurs/{nom}/contenus` | E05, E33, E20 |
| Publication | ✓ `POST contenus`, ✓ `PATCH contenus/{contenu}`, ✓ `DELETE contenus/{contenu}`, ✓ `POST envois`, ✓ `HEAD envois/{envoi}`, ✓ `PATCH envois/{envoi}`, ✓ `POST envois/{envoi}/terminer`, ✓ `GET modeles-telephone?q=`, ✓ `POST modeles-telephone` | E12 à E16, E30 |
| Communauté | ✓ `PUT contenus/{contenu}/reaction`, ✓ `DELETE contenus/{contenu}/reaction`, `GET contenus/{contenu}/commentaires`, ✓ `POST contenus/{contenu}/commentaires`, ✓ `PUT utilisateurs/{nom}/abonnement`, ✓ `DELETE utilisateurs/{nom}/abonnement` | E05, E06, E07, E20 |
| Notifications | ✓ `GET notifications`, ✓ `POST notifications/lues` | E17 |

**Règles métier à respecter :**

- `POST auth/email` ne révèle ni le nom ni la photo du compte ;
- le code e-mail a 6 chiffres, reste valable 10 minutes, et il est gardé haché ;
- après 5 essais de mot de passe manqués, le compte attend 15 minutes (réponse 429) ;
- chaque contenu porte un téléphone, une date et un lieu, ce qui garantit que « Y aller » fonctionne ;
- un fichier qui porte des signes d'IA est refusé, et rien n'est refusé parce qu'une information manque ;
- deux badges : « Capture vérifiée » si le téléphone et le lieu viennent du fichier, « Informations déclarées » si l'auteur les a complétés ;
- « Y aller » ouvre l'application de cartes du téléphone : le serveur n'intervient pas.
