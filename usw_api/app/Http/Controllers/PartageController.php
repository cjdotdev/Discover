<?php

namespace App\Http\Controllers;

use App\Enums\TypeContenu;
use App\Enums\UsageVariante;
use App\Models\Collection;
use App\Models\Contenu;
use App\Models\Lieu;
use App\Models\Utilisateur;
use App\Models\Variante;
use App\Support\Medias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Illuminate\Support\Str;

/**
 * Les pages des liens partagés (WhatsApp, SMS...) sur le domaine de Discover : un lieu (/l/…),
 * une photo ou un reel (/p/…), un créateur (/@…), une collection (/c/…). Elles donnent l'aperçu
 * du lien (Open Graph) et, sur Android, ouvrent l'application si elle est là
 * (/.well-known/assetlinks.json). Seul ce qui est public s'y montre.
 */
class PartageController extends Controller
{
    public function accueil(): Response
    {
        return $this->page([
            'titre' => 'Discover',
            'sousTitre' => 'Des photos et des reels de lieux, pris sur place et vérifiés.',
            'chemin' => '/',
            'images' => [],
        ], application: false);
    }

    /** GET l/{slug} */
    public function lieu(string $slug): Response
    {
        // Un lieu nommé sans position se partage aussi ; « Sans lieu » n'est pas un lieu.
        $lieu = Lieu::where('slug', $slug)->where('slug', '!=', Lieu::SANS_LIEU)->with('ville.pays')->first() ?? abort(404);
        $photos = $lieu->meilleures()->with('variantes')->limit(4)->get();

        return $this->page([
            'titre' => $lieu->nom,
            'sousTitre' => trim(implode(' · ', array_filter([$lieu->region(), $this->nombre($lieu->nombre_contenus)]))),
            'chemin' => '/l/'.$lieu->slug,
            'images' => $photos->map(fn (Contenu $c) => $this->image($c))->filter()->values()->all(),
        ]);
    }

    /** GET p/{ulid} : une photo ou un reel publié. */
    public function contenu(string $ulid): Response
    {
        $c = Contenu::publies()->where('ulid', $ulid)->with(['auteur', 'lieu.ville.pays', 'variantes'])->first() ?? abort(404);
        $lieu = $c->lieu?->estSitue() ? $c->lieu->nom : ($c->nom_lieu ?: null);
        $auteur = $c->auteur?->nom_utilisateur;

        return $this->page([
            'titre' => $c->titre ?: ($lieu ?? ($c->type === TypeContenu::Reel ? 'Un reel' : 'Une photo')),
            'sousTitre' => trim(implode(' · ', array_filter([$auteur ? '@'.$auteur : null, $c->lieu?->estSitue() ? $c->lieu->region() : null]))),
            'legende' => $c->legende,
            'verifiee' => $c->badge?->value === 'verifiee',
            'chemin' => '/p/'.$c->ulid,
            'images' => array_filter([$this->image($c)]),
            'seule' => true,
            // Qui l'a prise : sa photo de profil (ou ses initiales) et son nom, sous la photo.
            'auteur' => $c->auteur === null ? null : [
                'nom' => $c->auteur->nom_affiche ?: '@'.$c->auteur->nom_utilisateur,
                'pseudo' => $c->auteur->nom_utilisateur,
                'photo' => $c->auteur->avatar ? Medias::public()->url($c->auteur->avatar) : null,
                'initiales' => $this->initiales($c->auteur->nom_affiche ?: $c->auteur->nom_utilisateur),
                'teinte' => $this->teinte($c->auteur->nom_affiche ?: $c->auteur->nom_utilisateur),
            ],
        ]);
    }

    /** GET @{nom} : un créateur, sa photo de profil et ses dernières publications. */
    public function createur(string $nom): Response
    {
        $u = Utilisateur::where('nom_utilisateur', mb_strtolower($nom))->whereNull('suspendu_le')->whereNull('suppression_demandee_le')->first() ?? abort(404);
        $photos = $u->contenus()->publies()->with('variantes')->orderByDesc('publie_le')->limit(6)->get();
        $nom = $u->nom_affiche ?: $u->nom_utilisateur;

        return $this->page([
            'titre' => $u->nom_affiche ?: '@'.$u->nom_utilisateur,
            'sousTitre' => trim(implode(' · ', array_filter(['@'.$u->nom_utilisateur, $u->ville]))),
            'legende' => $u->bio,
            'chemin' => '/@'.$u->nom_utilisateur,
            'images' => $photos->map(fn (Contenu $c) => $this->image($c))->filter()->values()->all(),
            // Sa photo de profil en tête (ses initiales sans photo), comme dans l'application.
            'profil' => [
                'photo' => $u->avatar ? Medias::public()->url($u->avatar) : null,
                'initiales' => $this->initiales($nom),
                'teinte' => $this->teinte($nom),
            ],
            // L'aperçu du lien (WhatsApp…) : sa photo de profil, sinon sa dernière publication.
            'apercu' => $u->avatar ? ['url' => $this->urlApercu($u->avatar), 'largeur' => 512, 'hauteur' => 512, 'carre' => true] : null,
        ]);
    }

    /** GET c/{ulid} : une collection, si elle n'est pas secrète. */
    public function collection(string $ulid): Response
    {
        $col = Collection::where('ulid', $ulid)->where('secrete', false)->with('utilisateur')->first() ?? abort(404);
        abort_if($col->utilisateur === null || $col->utilisateur->suspendu_le !== null, 404);
        $photos = $col->contenus()->publies()->with('variantes')->limit(6)->get();

        return $this->page([
            'titre' => $col->nom,
            'sousTitre' => trim(implode(' · ', array_filter(['@'.$col->utilisateur->nom_utilisateur, $this->nombre($col->nombre_contenus)]))),
            'chemin' => '/c/'.$col->ulid,
            'images' => $photos->map(fn (Contenu $c) => $this->image($c))->filter()->values()->all(),
        ]);
    }

    /** GET .well-known/assetlinks.json : Android ouvre ces liens dans l'application signée par Discover. */
    public function liensApplication(): JsonResponse
    {
        return response()->json([[
            'relation' => ['delegate_permission/common.handle_all_urls'],
            'target' => [
                'namespace' => 'android_app',
                'package_name' => config('discover.android.paquet'),
                'sha256_cert_fingerprints' => config('discover.android.empreintes'),
            ],
        ]])->header('Cache-Control', 'public, max-age=3600');
    }

    private function nombre(?int $n): ?string
    {
        return $n ? $n.' '.($n > 1 ? 'publications' : 'publication') : null;
    }

    /** L'image à montrer d'une publication : la taille écran, sinon une autre ; l'affiche d'un reel. */
    private function image(Contenu $c): ?array
    {
        $ordre = [UsageVariante::Ecran, UsageVariante::Affiche, UsageVariante::Grande, UsageVariante::Petite];
        foreach ($ordre as $usage) {
            $v = $c->variantes->first(fn (Variante $v) => $v->usage === $usage);
            if ($v !== null) {
                return [
                    'url' => $v->url(),
                    'apercu' => $this->urlApercu($v->chemin),
                    'largeur' => $v->largeur,
                    'hauteur' => $v->hauteur,
                    'reel' => $c->type === TypeContenu::Reel,
                ];
            }
        }

        return null;
    }

    /**
     * GET apercu/{chemin}.jpg : une image publique (WebP) en JPEG, pour l'aperçu des liens :
     * WhatsApp et d'autres ne lisent pas toujours le WebP. Faite une fois, puis gardée à côté
     * de l'originale (et effacée avec elle).
     */
    public function apercu(string $chemin): Response
    {
        $disque = Medias::public();
        $cible = $chemin.'.jpg';
        if ($disque->exists($cible)) {
            $octets = (string) $disque->get($cible);
        } else {
            abort_unless($disque->exists($chemin.'.webp'), 404);
            $image = @imagecreatefromstring((string) $disque->get($chemin.'.webp'));
            abort_if($image === false, 404);
            ob_start();
            imagejpeg($image, null, 85);
            $octets = (string) ob_get_clean();
            $disque->put($cible, $octets);
        }

        return response($octets, 200, ['Content-Type' => 'image/jpeg', 'Cache-Control' => 'public, max-age=604800, immutable']);
    }

    /** L'adresse de l'aperçu JPEG d'une image publique (contenus/…/1080.webp, avatars/….webp). */
    public static function urlApercu(string $chemin): string
    {
        return 'https://'.config('discover.domaine_public').'/apercu/'.preg_replace('/\.webp$/', '', $chemin).'.jpg';
    }

    /** Les initiales d'un nom, comme dans l'application (deux au plus). */
    private function initiales(string $nom): string
    {
        $mots = array_values(array_filter(preg_split('/\s+/u', trim($nom)) ?: []));
        $i = implode('', array_map(fn ($m) => mb_strtoupper(mb_substr($m, 0, 1)), array_slice($mots, 0, 2)));

        return $i === '' ? 'U' : $i;
    }

    /** La teinte tirée du nom, la même que dans l'application : chacun garde la sienne. */
    private function teinte(string $nom): int
    {
        $somme = 0;
        foreach (mb_str_split($nom) as $c) {
            $somme += mb_ord($c);
        }

        return ($somme * 47) % 360;
    }

    private function page(array $d, bool $application = true): Response
    {
        $domaine = config('discover.domaine_public');
        $url = 'https://'.$domaine.$d['chemin'];
        $description = Str::limit(trim(($d['legende'] ?? '') ?: ($d['sousTitre'] ?? '')) ?: 'Sur Discover', 180);

        $premiere = $d['images'][0] ?? null;

        return response()->view('partage.page', [
            ...$d,
            // L'image de l'aperçu du lien : celle choisie, sinon la première photo.
            'og' => $d['apercu'] ?? ($premiere === null ? null : ['url' => $premiere['apercu'], 'largeur' => $premiere['largeur'], 'hauteur' => $premiere['hauteur'], 'carre' => false]),
            'url' => $url,
            'description' => $description,
            'support' => config('discover.support'),
            // Android : l'application si elle est installée, sinon cette même page.
            'lienApplication' => $application
                ? 'intent://'.$domaine.$d['chemin'].'#Intent;scheme=https;package='.config('discover.android.paquet').';S.browser_fallback_url='.rawurlencode($url.'?web=1').';end'
                : null,
        ])->header('Cache-Control', 'public, max-age=300');
    }
}
