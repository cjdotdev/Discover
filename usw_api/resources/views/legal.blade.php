<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ $titre }} · Discover</title>
  <link rel="icon" href="/marque/logo.svg" type="image/svg+xml">
  <meta name="color-scheme" content="light dark">
  <style>
    :root { --fond: #f4f4f6; --carte: #ffffff; --texte: #121212; --discret: #6b6f80; --filet: #e2e3ea; }
    @media (prefers-color-scheme: dark) { :root { --fond: #000000; --carte: #1a1a1a; --texte: #e3e3e3; --discret: #828282; --filet: #2c2c2e; } }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--fond); color: var(--texte); font: 15px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
    main { max-width: 640px; margin: 0 auto; padding: 24px 16px 40px; }
    h1 { font-size: 24px; line-height: 1.25; margin: 0 0 4px; }
    h2 { font-size: 17px; margin: 26px 0 6px; }
    .sous { color: var(--discret); margin: 0 0 18px; }
    .carte { background: var(--carte); border: 1px solid var(--filet); border-radius: 14px; padding: 14px 16px; }
    ul, ol { padding-left: 20px; margin: 6px 0; }
    li { margin: 4px 0; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 8px 6px; border-top: 1px solid var(--filet); vertical-align: top; }
    tr:first-child td { border-top: 0; }
    td:last-child { color: var(--discret); white-space: nowrap; }
    a { color: inherit; }
    footer { margin-top: 32px; padding-top: 14px; border-top: 1px solid var(--filet); font-size: 13px; color: var(--discret); }
  </style>
</head>
<body>
<main>
  <h1>{{ $titre }}</h1>
  <p class="sous">Discover · en vigueur depuis le 22 octobre 2026</p>
  @if ($page === 'confidentialite')
    <div class="carte">
      <strong>En bref</strong>
      <ul>
        <li>Nous ne vendons pas vos données et n’affichons pas de publicités ciblées.</li>
        <li>Votre position n’est utilisée que si vous l’autorisez : pour la carte, les lieux à proximité et vos publications.</li>
        <li>Vous pouvez télécharger ou supprimer toutes vos données, à tout moment.</li>
      </ul>
    </div>
    <h2>Les données que nous conservons, et pourquoi</h2>
    <div class="carte">
      <table>
        <tr><td><strong>E-mail</strong><br>Vous envoyer les codes de connexion</td><td>Tant que le compte existe</td></tr>
        <tr><td><strong>Position de la prise de vue</strong><br>Afficher le lieu, Y aller</td><td>Tant que la publication existe</td></tr>
        <tr><td><strong>Modèle du téléphone, date</strong><br>Les informations de capture</td><td>Tant que la publication existe</td></tr>
        <tr><td><strong>Fichiers originaux</strong><br>Vérifier la photo (EXIF, IA)</td><td>Supprimés après la vérification</td></tr>
        <tr><td><strong>Vues</strong><br>Compter les vues. L’auteur d’une publication voit les membres qui l’ont vue</td><td>Tant que la publication existe</td></tr>
        <tr><td><strong>Signalements</strong><br>La modération</td><td>Supprimés après 1 an</td></tr>
      </table>
    </div>
    <h2>1. Ce que les autres membres voient</h2>
    <p>Votre nom, votre photo de profil, vos publications et leurs informations de capture. Une collection secrète, et votre lifestyle tant que vous ne l’avez pas rendu visible, ne sont visibles que par vous.</p>
    <h2>2. Les copies affichées</h2>
    <p>Les versions affichées dans l’application ne contiennent aucune information du fichier. Seul le fichier d’origine, resté sur votre téléphone, les conserve.</p>
    <h2>3. Les services qui nous aident</h2>
    <p>Les photos et vidéos sont stockées chez Cloudflare (R2), la base de données chez Neon, l’application tourne chez Railway. Une intelligence artificielle (Cloudflare Workers AI) décrit ce qu’on voit sur les publications en ligne, pour la recherche. Les notifications passent par Firebase (Google).</p>
    <h2>4. Vos droits</h2>
    <p>Vous pouvez consulter, corriger, télécharger ou supprimer vos données, depuis l’application (Profil › Réglages › Confidentialité › Mes données) ou en écrivant à <a href="mailto:support@discover.simeonamoussou.com">support@discover.simeonamoussou.com</a>. Vous pouvez aussi saisir l’Autorité de protection des données personnelles (APDP).</p>
    <p>Pour supprimer votre compte : <a href="/supprimer-mon-compte">la marche à suivre</a>.</p>
  @else
    <div class="carte">
      <strong>Depuis l’application Discover</strong>
      <ol>
        <li>Ouvrez Discover et allez sur votre <strong>Profil</strong>.</li>
        <li>Touchez <strong>Réglages</strong>, puis <strong>Confidentialité</strong>.</li>
        <li>Touchez <strong>Supprimer mon compte</strong> et confirmez.</li>
      </ol>
    </div>
    <h2>Sans l’application</h2>
    <p>Écrivez à <a href="mailto:support@discover.simeonamoussou.com?subject=Supprimer%20mon%20compte">support@discover.simeonamoussou.com</a> depuis l’adresse e-mail de votre compte, avec pour objet « Supprimer mon compte ». Nous le supprimons et vous le confirmons par e-mail.</p>
    <h2>Ce qui est supprimé</h2>
    <p>Votre compte, votre profil, vos publications, votre lifestyle, vos collections, vos commentaires et réactions, et les fichiers de vos photos et vidéos. Le compte est d’abord désactivé, puis effacé définitivement au bout de 30 jours.</p>
    <h2>Ce qui est gardé</h2>
    <p>Les signalements, jusqu’à 1 an, pour la modération.</p>
  @endif
  <footer><a href="/confidentialite">Confidentialité</a> · <a href="/supprimer-mon-compte">Supprimer mon compte</a> · Discover</footer>
</main>
</body>
</html>
