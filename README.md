# Discover

Discover est une application mobile participative de photos et de reels touristiques 100 % réels. Chaque contenu dit où, quand et avec quel téléphone il a été pris, et le bouton « Y aller » ouvre l'itinéraire jusqu'au lieu de la prise de vue.

Ce dépôt contient le MVP présenté au cours de développement d'applications mobiles.

## Le dépôt

| Dossier ou fichier | Contenu |
|---|---|
| [`repartition.md`](repartition.md) | Qui fait quoi, les écrans du MVP, les règles de travail, les spécifications du backend |
| `discover_mobile/` | L'application Flutter |
| `docs/maquette/` | Les 40 maquettes du MVP |

## Lancer l'application

Il faut Flutter 3.47 ou plus.

```bash
cd discover_mobile
flutter pub get
flutter run
```

Sans backend, l'application tourne avec des données simulées :

| Cas | Valeur |
|---|---|
| Compte déjà inscrit | `membre@discover.bj` |
| Son mot de passe | `Discover1` |
| Code reçu par e-mail | `123456` |

Une autre adresse e-mail ouvre le parcours d'inscription.

Pour utiliser une vraie API, on donne son adresse au lancement :

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
```

## Vérifier avant de pousser

```bash
dart format lib test
flutter analyze
flutter test
```

## Licences

La police Wura Mi est sous licence OFL (`discover_mobile/assets/polices/OFL-WuraMi.txt`). Les photos de `discover_mobile/assets/images/` sont sous licence CC0 (StockSnap).
