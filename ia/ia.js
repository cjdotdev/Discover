// L IA de Discover : POST /decrire {"image": "https://medias.discover.simeonamoussou.com/contenus/…/1080.webp"}
// rend {"description": "…", "mots": ["…"]} : ce qu on voit sur l image, en francais, pour la recherche
// (« nourriture » trouve un plat meme si la legende dit « chez maman »).
//
// Pas de cle : seules les images publiques de Discover passent, et chaque reponse se garde 30 jours.
// Au pire, quelqu un fait decrire une fois nos propres images.

const MEDIAS = 'https://medias.discover.simeonamoussou.com/contenus/';
const MODELE = '@cf/mistralai/mistral-small-3.1-24b-instruct';
const SECOURS = '@cf/meta/llama-4-scout-17b-16e-instruct';

const CONSIGNE = `Tu décris des photos pour le moteur de recherche d'une application de voyage et de lieux (Bénin, Afrique de l'Ouest).
Réponds seulement en JSON, en français :
- "description" : une ou deux phrases, ce qu'on voit (lieu, paysage, bâtiments, nourriture, objets, animaux, plantes, personnes sans les identifier, moment de la journée, ambiance).
- "mots" : 10 à 25 mots-clés en minuscules, au singulier, du plus précis au plus général. Mets toujours les grandes catégories qui conviennent parmi : nourriture, boisson, nature, paysage, plage, mer, eau, arbre, plante, fleur, animal, bâtiment, ville, rue, route, voiture, moto, personne, fête, musique, sport, marché, art, culture, religion, nuit, coucher de soleil, ciel, intérieur, extérieur.
Si tu n'es pas sûr d'une chose, ne la mets pas.`;

const FORME = {
  type: 'object',
  properties: {
    description: { type: 'string' },
    mots: { type: 'array', items: { type: 'string' } },
  },
  required: ['description', 'mots'],
};

export default {
  async fetch(requete, env, ctx) {
    const url = new URL(requete.url);
    if (requete.method !== 'POST' || url.pathname !== '/decrire') return Response.json({ erreur: 'introuvable' }, { status: 404 });
    let image;
    try {
      image = String((await requete.json()).image || '');
    } catch {
      return Response.json({ erreur: 'corps' }, { status: 400 });
    }
    if (!image.startsWith(MEDIAS) || !/\.(webp|jpe?g|png)$/.test(image) || image.includes('..')) {
      return Response.json({ erreur: 'image refusee' }, { status: 422 });
    }

    // Deja decrite : la meme reponse, sans repasser par l IA.
    const cache = caches.default;
    const cle = new Request(`${url.origin}/cache?image=${encodeURIComponent(image)}`);
    const gardee = await cache.match(cle);
    if (gardee) return gardee;

    const fichier = await fetch(image);
    if (!fichier.ok) return Response.json({ erreur: 'image absente' }, { status: 404 });
    const octets = new Uint8Array(await fichier.arrayBuffer());
    if (octets.length > 6 * 1024 * 1024) return Response.json({ erreur: 'image trop lourde' }, { status: 413 });
    const type = fichier.headers.get('content-type') || 'image/webp';
    const donnees = `data:${type};base64,${base64(octets)}`;

    let resultat = null;
    for (const modele of [MODELE, SECOURS]) {
      try {
        resultat = lire(await env.AI.run(modele, {
          messages: [
            { role: 'system', content: CONSIGNE },
            {
              role: 'user',
              content: [
                { type: 'text', text: 'Décris cette image.' },
                { type: 'image_url', image_url: { url: donnees } },
              ],
            },
          ],
          guided_json: FORME,
          max_tokens: 500,
          temperature: 0.1,
        }));
        if (resultat) break;
      } catch (e) {
        console.log(`${modele} : ${e}`);
      }
    }
    if (!resultat) return Response.json({ erreur: 'ia indisponible' }, { status: 503 });

    const reponse = Response.json(resultat, { headers: { 'cache-control': 'public, max-age=2592000' } });
    ctx.waitUntil(cache.put(cle, reponse.clone()));
    return reponse;
  },
};

// La reponse du modele : un objet, ou du texte JSON (parfois entoure de ```).
function lire(sortie) {
  let r = sortie?.response ?? sortie;
  if (typeof r === 'string') {
    const debut = r.indexOf('{');
    const fin = r.lastIndexOf('}');
    if (debut < 0 || fin <= debut) return null;
    try {
      r = JSON.parse(r.slice(debut, fin + 1));
    } catch {
      return null;
    }
  }
  if (!r || typeof r.description !== 'string' || !Array.isArray(r.mots)) return null;
  const mots = [...new Set(r.mots.map((m) => String(m).toLowerCase().trim()).filter((m) => m && m.length <= 40))].slice(0, 30);
  return { description: r.description.trim().slice(0, 600), mots };
}

function base64(octets) {
  let texte = '';
  for (let i = 0; i < octets.length; i += 0x8000) texte += String.fromCharCode(...octets.subarray(i, i + 0x8000));
  return btoa(texte);
}
