<?php

namespace Tests\Feature;

use App\Models\Lieu;
use App\Models\Pays;
use App\Models\Ville;
use App\Services\Lieux\RapprocheurLieu;
use App\Support\Geo;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** B25 : une position vers le lieu connu le plus proche, avec de vraies coordonnées du Bénin. */
class RapprocheurLieuTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $benin = Pays::create(['code' => 'BJ', 'nom' => 'Bénin']);
        $ouidah = Ville::create(['pays_id' => $benin->id, 'nom' => 'Ouidah', 'region' => 'Atlantique']);
        $popo = Ville::create(['pays_id' => $benin->id, 'nom' => 'Grand-Popo', 'region' => 'Mono']);
        // La Porte du Non-Retour et le ponton de Ouidah sont à 1,5 km l'un de l'autre.
        Lieu::create(['slug' => 'ouidah', 'nom' => 'Ponton de Ouidah', 'ville_id' => $ouidah->id, 'type' => 'Plages', 'latitude' => 6.3256, 'longitude' => 2.0886]);
        Lieu::create(['slug' => 'porte-du-non-retour', 'nom' => 'Porte du Non-Retour', 'ville_id' => $ouidah->id, 'type' => 'Patrimoine', 'latitude' => 6.3236, 'longitude' => 2.1018]);
        Lieu::create(['slug' => 'grand-popo', 'nom' => 'Plage de Grand-Popo', 'ville_id' => $popo->id, 'type' => 'Plages', 'latitude' => 6.2833, 'longitude' => 1.8222]);
    }

    public function test_la_distance_entre_cotonou_et_porto_novo(): void
    {
        // Environ 29 km à vol d'oiseau.
        $this->assertEqualsWithDelta(29.4, Geo::distanceKm(6.3703, 2.3912, 6.4969, 2.6283), 1.0);
    }

    public function test_une_photo_prise_sur_le_ponton_va_au_ponton(): void
    {
        $r = app(RapprocheurLieu::class)->proche(6.3262, 2.0893);
        $this->assertSame('ouidah', $r->lieu->slug);
        $this->assertLessThan(0.2, $r->distanceKm);
    }

    public function test_entre_deux_lieux_le_plus_proche_l_emporte(): void
    {
        $this->assertSame('porte-du-non-retour', app(RapprocheurLieu::class)->proche(6.3240, 2.0990)->lieu->slug);
    }

    public function test_trop_loin_de_tout_lieu_connu(): void
    {
        // Le centre de Cotonou : à plus de 30 km de Ouidah.
        $this->assertNull(app(RapprocheurLieu::class)->proche(6.3703, 2.3912));
    }

    public function test_la_route_lieux_proche(): void
    {
        $this->getJson('/api/v1/lieux/proche?latitude=6.2840&longitude=1.8230')->assertOk()
            ->assertJsonPath('lieu.id', 'grand-popo')
            ->assertJsonPath('lieu.region', 'Mono, Bénin');
        $this->getJson('/api/v1/lieux/proche?latitude=6.3703&longitude=2.3912')->assertNotFound()
            ->assertJsonPath('message', 'Aucun lieu connu à moins de 2 km. Indiquez-le sur la carte.');
        $this->getJson('/api/v1/lieux/proche?latitude=200&longitude=2')->assertUnprocessable();
    }
}
