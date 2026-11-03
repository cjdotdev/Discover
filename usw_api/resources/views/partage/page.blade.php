<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ $titre }}{{ $titre === 'Discover' ? '' : ' · Discover' }}</title>
  <meta name="description" content="{{ $description }}">
  <link rel="canonical" href="{{ $url }}">
  <link rel="icon" href="/marque/logo.svg" type="image/svg+xml">
  <meta property="og:site_name" content="Discover">
  <meta property="og:type" content="{{ empty($profil) ? 'website' : 'profile' }}">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:title" content="{{ $titre }}">
  <meta property="og:description" content="{{ $description }}">
  <meta property="og:url" content="{{ $url }}">
  @if (! empty($og))
  <meta property="og:image" content="{{ $og['url'] }}">
  <meta property="og:image:type" content="image/jpeg">
  <meta property="og:image:width" content="{{ $og['largeur'] }}">
  <meta property="og:image:height" content="{{ $og['hauteur'] }}">
  <meta property="og:image:alt" content="{{ $titre }}">
  <meta name="twitter:card" content="{{ $og['carre'] ? 'summary' : 'summary_large_image' }}">
  @endif
  <meta name="color-scheme" content="light dark">
  <style>
    :root { --fond: #f4f4f6; --carte: #ffffff; --texte: #121212; --discret: #6b6f80; --filet: #e2e3ea; --ocean: #5d7cfb; --vert: #1f9d55; }
    @media (prefers-color-scheme: dark) {
      :root { --fond: #000000; --carte: #1a1a1a; --texte: #e3e3e3; --discret: #828282; --filet: #2c2c2e; --vert: #4cc38a; }
    }
    * { box-sizing: border-box; }
    [hidden] { display: none !important; }
    body { margin: 0; background: var(--fond); color: var(--texte); font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
    main { max-width: 520px; margin: 0 auto; padding: 20px 16px 32px; }
    header { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; font-weight: 700; font-size: 16px; }
    header img { width: 34px; height: 34px; }
    .logo-nuit { display: none; }
    @media (prefers-color-scheme: dark) { .logo-jour { display: none; } .logo-nuit { display: block; } }
    .photo { display: block; width: 100%; height: auto; border-radius: 14px; background: var(--carte); }
    .grille { display: grid; grid-template-columns: repeat(2, 1fr); gap: 6px; }
    .grille.trois { grid-template-columns: repeat(3, 1fr); }
    .grille img { width: 100%; aspect-ratio: 3 / 4; object-fit: cover; border-radius: 10px; display: block; background: var(--carte); }
    .case { position: relative; }
    .reel { position: absolute; left: 8px; bottom: 8px; color: #fff; font-size: 12px; font-weight: 600; background: rgba(0, 0, 0, .55); border-radius: 8px; padding: 1px 7px; }
    h1 { font-size: 22px; line-height: 1.25; margin: 18px 0 4px; }
    .sous { color: var(--discret); margin: 0; }
    .legende { margin: 12px 0 0; white-space: pre-line; }
    .badge { display: inline-flex; align-items: center; gap: 6px; margin-top: 12px; font-size: 13px; font-weight: 600; color: var(--vert); }
    .bouton { display: block; margin-top: 22px; padding: 13px 16px; border-radius: 12px; background: var(--ocean); color: #fff; text-align: center; font-weight: 600; text-decoration: none; }
    .auteur { display: flex; align-items: center; gap: 10px; margin-top: 14px; color: inherit; text-decoration: none; }
    .auteur img, .auteur .initiales { width: 36px; height: 36px; font-size: 13px; }
    .auteur strong { display: block; font-size: 15px; }
    .auteur span { display: block; font-size: 13px; color: var(--discret); }
    .profil { display: flex; flex-direction: column; align-items: center; text-align: center; margin-bottom: 18px; }
    .profil h1 { margin-top: 14px; }
    .avatar { width: 104px; height: 104px; border-radius: 50%; object-fit: cover; display: block; background: var(--carte); }
    .initiales { width: 104px; height: 104px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 35px; font-weight: 700; }
    footer { margin-top: 28px; padding-top: 14px; border-top: 1px solid var(--filet); font-size: 13px; color: var(--discret); text-align: center; }
    footer a { color: inherit; }
  </style>
</head>
<body>
  <main>
    <header>
      <img class="logo-jour" src="/marque/logo.svg" alt="">
      <img class="logo-nuit" src="/marque/logo-sombre.svg" alt="">
      <span>Discover</span>
    </header>

    @if (! empty($profil))
      {{-- Un créateur : sa photo de profil et son nom d'abord, ses publications ensuite. --}}
      <div class="profil">
        @if ($profil['photo'])
          <img class="avatar" src="{{ $profil['photo'] }}" width="104" height="104" alt="{{ $titre }}">
        @else
          <div class="initiales" style="background: hsl({{ $profil['teinte'] }}, 55%, 48%)" aria-hidden="true">{{ $profil['initiales'] }}</div>
        @endif
        <h1>{{ $titre }}</h1>
        @if (! empty($sousTitre))<p class="sous">{{ $sousTitre }}</p>@endif
        @if (! empty($legende))<p class="legende">{{ $legende }}</p>@endif
      </div>
    @endif

    @if (! empty($seule) && ! empty($images))
      <div class="case">
        <img class="photo" src="{{ $images[0]['url'] }}" width="{{ $images[0]['largeur'] }}" height="{{ $images[0]['hauteur'] }}" alt="{{ $titre }}">
        @if ($images[0]['reel'])<span class="reel">Reel</span>@endif
      </div>
    @elseif (! empty($images))
      <div class="grille {{ count($images) > 4 ? 'trois' : '' }}">
        @foreach ($images as $image)
          <div class="case">
            <img src="{{ $image['url'] }}" alt="" loading="lazy">
            @if ($image['reel'])<span class="reel">Reel</span>@endif
          </div>
        @endforeach
      </div>
    @endif

    @if (empty($profil))
      <h1>{{ $titre }}</h1>
      @if (! empty($sousTitre))<p class="sous">{{ $sousTitre }}</p>@endif
      @if (! empty($legende))<p class="legende">{{ $legende }}</p>@endif
    @endif
    @if (! empty($auteur))
      <a class="auteur" href="/{{ '@'.$auteur['pseudo'] }}">
        @if ($auteur['photo'])
          <img class="avatar" src="{{ $auteur['photo'] }}" width="36" height="36" alt="">
        @else
          <div class="initiales" style="background: hsl({{ $auteur['teinte'] }}, 55%, 48%)" aria-hidden="true">{{ $auteur['initiales'] }}</div>
        @endif
        <div><strong>{{ $auteur['nom'] }}</strong><span>{{ '@'.$auteur['pseudo'] }}</span></div>
      </a>
    @endif
    @if (! empty($verifiee))
      <div class="badge">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 4.5 6v5.5c0 4.4 3.1 8.3 7.5 9.5 4.4-1.2 7.5-5.1 7.5-9.5V6z"/><path d="m8.8 12 2.2 2.2 4.2-4.4"/></svg>
        Capture vérifiée
      </div>
    @endif

    @if ($lienApplication)
      <a class="bouton" id="ouvrir" href="{{ $lienApplication }}" hidden>Ouvrir dans Discover</a>
      <script>
        // Le bouton n'a de sens que sur Android, où l'application peut s'ouvrir.
        if (/Android/i.test(navigator.userAgent)) document.getElementById('ouvrir').hidden = false;
      </script>
    @endif

    <footer><a href="mailto:{{ $support }}">{{ $support }}</a></footer>
  </main>
</body>
</html>
