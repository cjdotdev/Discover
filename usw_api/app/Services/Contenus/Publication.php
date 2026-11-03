<?php

namespace App\Services\Contenus;

use App\Enums\RoleEnvoi;
use App\Enums\SourceCapture;
use App\Enums\StatutContenu;
use App\Enums\StatutEnvoi;
use App\Enums\TypeContenu;
use App\Exceptions\ErreurMetier;
use App\Models\Contenu;
use App\Models\Envoi;
use App\Models\FichierOriginal;
use App\Models\Lieu;
use App\Models\ModeleTelephone;
use App\Models\Son;
use App\Models\Utilisateur;
use App\Services\Lieux\PlacesGoogle;
use App\Services\Lieux\RapprocheurLieu;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/** B31 : créer le brouillon et ses deux envois ; le compléter. */
class Publication
{
    /** Le rayon où un point posé sur la carte reprend un lieu de Discover (celui de l'app). */
    private const POINT_POSE_KM = 0.3;

    public function __construct(private RapprocheurLieu $rapprocheur, private PlacesGoogle $google) {}

    /** Les envois pas encore finis d'un membre : 20 au plus, 2 Go au plus. */
    private const ENVOIS_EN_COURS = 20;

    private const OCTETS_EN_ATTENTE = 2 * 1024 * 1024 * 1024;

    public function creer(Utilisateur $u, array $d): Contenu
    {
        $enCours = Envoi::where('statut', StatutEnvoi::EnCours)->whereIn('contenu_id', Contenu::where('utilisateur_id', $u->id)->select('id'));
        $attente = (int) (clone $enCours)->sum(DB::raw('taille - recu'));
        if ((clone $enCours)->count() >= self::ENVOIS_EN_COURS
            || $attente + $d['fichiers']['apercu']['taille'] + $d['fichiers']['original']['taille'] > self::OCTETS_EN_ATTENTE) {
            throw new ErreurMetier(429, 'Vous avez trop de publications en cours d’envoi. Attendez qu’elles se terminent.');
        }
        if (FichierOriginal::where('empreinte_sha256', $d['fichiers']['original']['empreinte'])->exists()) {
            throw new ErreurMetier(409, 'Cette photo ou cette vidéo est déjà publiée sur Discover.');
        }
        $c = $d['capture'];

        return DB::transaction(function () use ($u, $d, $c) {
            $lieu = $this->lieu($d, $c);
            // Un lieu sans position (« Sans lieu », ou un nom seul) : la position de la prise reste
            // sur le téléphone.
            $prive = ! $lieu->estSitue();
            // La musique choisie au montage : mêlée à la vidéo quand elle est ré-encodée.
            $musique = $d['type'] === 'reel' && isset($d['musique']['id']) ? Son::where('ulid', $d['musique']['id'])->first() : null;
            $contenu = Contenu::create([
                'utilisateur_id' => $u->id,
                'lieu_id' => $lieu->id,
                'nom_lieu' => null,
                'type' => TypeContenu::from($d['type']),
                // Pour mon lifestyle : hors de l'accueil, des lieux et des Reels.
                'portee' => ($d['portee'] ?? null) === Contenu::LIFESTYLE ? Contenu::LIFESTYLE : 'decouverte',
                'statut' => StatutContenu::Brouillon,
                'titre' => $d['titre'] ?? null,
                'legende' => $d['legende'] ?? null,
                'duree' => $d['type'] === 'reel' ? $d['duree'] : null,
                'son' => $d['type'] === 'reel' ? ($musique?->nomComplet() ?? 'Son d’origine') : null,
                'son_id' => $musique?->id,
                'son_debut_ms' => $musique ? min((int) ($d['musique']['debut_ms'] ?? $musique->debut_conseille_ms), max(0, $musique->duree_ms - 1000)) : null,
                'son_volume' => $musique ? (int) ($d['musique']['volume'] ?? 100) : null,
                'origine_volume' => $musique ? (int) ($d['musique']['volume_origine'] ?? 100) : null,
            ]);
            $contenu->capture()->create([
                'source' => SourceCapture::from($c['source']),
                'modele_telephone_id' => $this->modele($u, $c['marque'] ?? null, $c['modele'] ?? null)?->id,
                'prise_le' => isset($c['prise_le']) ? Carbon::parse($c['prise_le']) : null,
                'latitude' => $prive ? null : ($c['latitude'] ?? null),
                'longitude' => $prive ? null : ($c['longitude'] ?? null),
                'origines' => array_merge(['modele' => 'declaree', 'date' => 'declaree', 'position' => 'declaree'], $c['origines'] ?? []),
            ]);
            if (! empty($d['etiquettes'])) {
                $contenu->etiqueter($d['etiquettes']);
            }
            foreach (RoleEnvoi::cases() as $role) {
                $f = $d['fichiers'][$role->value];
                $contenu->envois()->create([
                    'utilisateur_id' => $u->id,
                    'role' => $role,
                    'type' => $f['type'],
                    'taille' => $f['taille'],
                    'empreinte_sha256' => $f['empreinte'],
                    'derniere_activite' => now(),
                ]);
            }

            return $contenu;
        });
    }

    public function completer(Contenu $contenu, Utilisateur $u, array $d): void
    {
        $contenu->fill(array_intersect_key($d, array_flip(['titre', 'legende'])));
        if (array_intersect_key($d, array_flip(['lieu', 'lieu_google', 'lieu_latitude', 'nom_lieu']))) {
            $lieu = $this->lieu($d, []);
            $contenu->lieu_id = $lieu->id;
            $contenu->nom_lieu = null;
        }
        $contenu->save();
        $capture = $contenu->capture;
        if (! $contenu->lieu->estSitue()) {
            $capture->latitude = $capture->longitude = null;
        }
        $origines = $capture->origines ?? [];
        if (isset($d['modele'])) {
            $capture->modele_telephone_id = $this->modele($u, $d['marque'], $d['modele'])?->id;
            $origines['modele'] = 'declaree';
        }
        if (isset($d['prise_le'])) {
            $capture->prise_le = Carbon::parse($d['prise_le']);
            $origines['date'] = 'declaree';
        }
        $capture->origines = $origines;
        $capture->save();
    }

    /** Le téléphone : celui de la liste s'il y est (écrit autrement compris), sinon ajouté. */
    private function modele(Utilisateur $u, ?string $marque, ?string $nom): ?ModeleTelephone
    {
        if (! $marque || ! $nom) {
            return null;
        }
        $marque = trim($marque);
        $nom = trim((string) preg_replace('/^'.preg_quote($marque, '/').'\s+/i', '', trim($nom)));

        $q = ModeleTelephone::normaliser($marque.' '.$nom);

        // « iPhone 13 » (le nom montré, sans sa marque) retrouve « Apple iPhone 13 » plutôt que
        // d'en créer un double : le nom complet, sinon un modèle qui finit pareil, le plus utilisé.
        return ModeleTelephone::where('nom_recherche', $q)->first()
            ?? ModeleTelephone::where('nom_recherche', 'like', '% '.$q)->orderByDesc('nombre_contenus')->first()
            ?? ModeleTelephone::create(['marque' => Str::ucfirst($marque), 'nom' => $nom, 'ajoute_par' => $u->id]);
    }

    /**
     * Le lieu, dans l'ordre : un lieu de Discover (son slug) ; un lieu trouvé avec Google ; le point
     * posé sur la carte, sinon la position de la prise (le lieu connu le plus proche, sinon créé
     * avec le nom donné) ; sinon la pile « Sans lieu ».
     */
    private function lieu(array $d, array $c): Lieu
    {
        if (! empty($d['lieu']) && ($l = Lieu::where('slug', $d['lieu'])->first())) {
            return $l;
        }
        if (! empty($d['lieu_google']) && ($l = $this->google->lieu($d['lieu_google']))) {
            return $l;
        }
        // Un nom seul, sans position (« Chez ma grand-mère ») : un vrai lieu, avec sa pile, mais
        // ni carte ni « Y aller ». La position de la prise reste sur le téléphone.
        $nom = trim((string) ($d['nom_lieu'] ?? ''));
        if ($nom !== '') {
            return $this->lieuNomme($nom);
        }
        $lat = $d['lieu_latitude'] ?? $c['latitude'] ?? null;
        $lon = $d['lieu_longitude'] ?? $c['longitude'] ?? null;
        // Un nom vide (« Sans lieu », choisi) passe avant la position de la prise.
        if ($lat !== null && $lon !== null && ! array_key_exists('nom_lieu', $d)) {
            // Un point posé à la main ne reprend qu'un lieu tout près (comme l'app, 300 m) ;
            // la position de la prise, elle, rejoint le lieu connu des environs.
            $pose = isset($d['lieu_latitude'], $d['lieu_longitude']);
            if ($r = $this->rapprocheur->proche((float) $lat, (float) $lon, $pose ? self::POINT_POSE_KM : RapprocheurLieu::RAYON_KM)) {
                return $r->lieu;
            }
            if (! empty($d['lieu_nom'])) {
                return PlacesGoogle::creer($d['lieu_nom'], (float) $lat, (float) $lon, $d['ville'] ?? null, $d['region'] ?? null, $d['pays'] ?? null, $d['pays_code'] ?? null);
            }
        }

        return Lieu::sansLieu();
    }

    /** Le lieu sans position de ce nom (écrit autrement, accents ou majuscules, c'est le même), sinon créé. */
    private function lieuNomme(string $nom): Lieu
    {
        $nom = Str::limit($nom, 150, '');
        $base = Str::slug($nom) ?: 'lieu';
        $deja = Lieu::whereNull('latitude')->where('slug', '!=', Lieu::SANS_LIEU)
            ->where(fn ($q) => $q->where('slug', $base)->orWhere('slug', 'like', $base.'-%'))
            ->get()->first(fn (Lieu $l) => Str::slug($l->nom) === $base);
        if ($deja !== null) {
            return $deja;
        }
        $slug = $base;
        for ($i = 2; Lieu::where('slug', $slug)->exists(); $i++) {
            $slug = $base.'-'.$i;
        }

        return Lieu::create(['slug' => $slug, 'nom' => $nom, 'type' => 'Autres']);
    }
}
