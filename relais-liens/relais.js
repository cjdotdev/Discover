// Le relais de discover.simeonamoussou.com : les pages des liens partagés (/l/ un lieu, /p/ une
// publication, /@ un créateur, /c/ une collection), la page d'accueil, le logo et
// /.well-known/assetlinks.json (Android ouvre ces liens dans Discover) et les images des aperçus
// (/apercu/…, en JPEG, gardées par Cloudflare) viennent du serveur Railway. Le reste (l'API) ne
// passe pas par ici.
const ORIGINE = 'https://discover-production-6cca.up.railway.app';
const CHEMINS = /^\/(?:$|l\/|p\/|@|c\/|marque\/|apercu\/|\.well-known\/assetlinks\.json$)/;

export default {
  async fetch(requete) {
    const url = new URL(requete.url);
    if (requete.method !== 'GET' && requete.method !== 'HEAD') return new Response(null, { status: 405 });
    if (!CHEMINS.test(url.pathname)) return new Response('Introuvable', { status: 404 });

    const entetes = new Headers();
    for (const nom of ['accept', 'accept-language', 'user-agent']) {
      const v = requete.headers.get(nom);
      if (v) entetes.set(nom, v);
    }
    // Le serveur limite les visites par adresse : celle du visiteur, pas celle du relais.
    const ip = requete.headers.get('cf-connecting-ip');
    if (ip) entetes.set('x-forwarded-for', ip);

    // Une image d'aperçu ne change jamais (son adresse change avec elle) : Cloudflare la garde une semaine.
    const image = url.pathname.startsWith('/apercu/');
    const reponse = await fetch(ORIGINE + url.pathname + url.search, {
      method: requete.method,
      headers: entetes,
      redirect: 'manual',
      ...(image ? { cf: { cacheEverything: true, cacheTtl: 604800 } } : {}),
    });
    return new Response(reponse.body, reponse);
  },
};
