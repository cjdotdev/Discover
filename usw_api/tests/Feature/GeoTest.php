<?php

namespace Tests\Feature;

use App\Models\Localite;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use ZipArchive;

/** Le choix du pays et de la ville du profil : tous les pays, puis les villes (GeoNames). */
class GeoTest extends TestCase
{
    use RefreshDatabase;

    public function test_tous_les_pays_par_ordre_alphabetique_dans_la_langue(): void
    {
        $fr = collect($this->getJson('/api/v1/geo/pays?langue=fr')->assertOk()->json('data'));
        $this->assertGreaterThan(240, $fr->count());
        $this->assertSame('Bénin', $fr->firstWhere('code', 'BJ')['nom']);
        $this->assertNull($fr->firstWhere('code', 'SU'));
        $this->assertSame('Afghanistan', $fr->first()['nom']);
        // « Égypte » se range à E, pas après Z.
        $this->assertLessThan($fr->search(fn ($p) => $p['code'] === 'ES'), $fr->search(fn ($p) => $p['code'] === 'EG'));

        $en = collect($this->getJson('/api/v1/geo/pays?langue=en')->json('data'));
        $this->assertSame('Benin', $en->firstWhere('code', 'BJ')['nom']);
    }

    public function test_importer_puis_chercher_les_villes_d_un_pays(): void
    {
        $dossier = sys_get_temp_dir().'/geo-'.uniqid();
        mkdir($dossier);
        $lignes = [
            [2394819, 'Cotonou', 'Cotonou', '', '6.36536', '2.41833', 'P', 'PPLA', 'BJ', '', '14', '', '', '', '780000'],
            [2392087, 'Porto-Novo', 'Porto-Novo', '', '6.49646', '2.60359', 'P', 'PPLC', 'BJ', '', '16', '', '', '', '264320'],
            [2395261, 'Abomey-Calavi', 'Abomey-Calavi', '', '6.44852', '2.35566', 'P', 'PPL', 'BJ', '', '08', '', '', '', '385755'],
            [9999999, 'Vieux quartier', 'Vieux quartier', '', '6.1', '2.1', 'P', 'PPLX', 'BJ', '', '14', '', '', '', '5000'],
            [2365267, 'Lomé', 'Lome', '', '6.13748', '1.21227', 'P', 'PPLC', 'TG', '', '24', '', '', '', '749700'],
        ];
        $zip = new ZipArchive;
        $zip->open("{$dossier}/cities1000.zip", ZipArchive::CREATE);
        $zip->addFromString('cities1000.txt', implode("\n", array_map(fn ($l) => implode("\t", $l), $lignes))."\n");
        $zip->close();
        file_put_contents("{$dossier}/admin1.txt", "BJ.14\tLittoral\tLittoral\t1\nBJ.08\tAtlantique\tAtlantique\t2\n");

        $this->artisan('usw:importer-localites', ['--fichier' => "{$dossier}/cities1000.zip", '--regions' => "{$dossier}/admin1.txt"])->assertSuccessful();
        $this->assertSame(4, Localite::count());
        // Déjà là : rien n'est refait.
        $this->artisan('usw:importer-localites', ['--si-vide' => true])->assertSuccessful();

        $this->getJson('/api/v1/geo/pays/bj/villes')->assertOk()->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.nom', 'Abomey-Calavi')->assertJsonPath('data.0.region', 'Atlantique')->assertJsonPath('data.1.nom', 'Cotonou');
        $this->getJson('/api/v1/geo/pays/BJ/villes?q=calavi')->assertJsonCount(1, 'data')->assertJsonPath('data.0.nom', 'Abomey-Calavi');
        $this->getJson('/api/v1/geo/pays/BJ/villes?q=porto%')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/geo/pays/TG/villes?q=lome')->assertJsonPath('data.0.nom', 'Lomé');
        $this->getJson('/api/v1/geo/pays/XX1/villes')->assertNotFound();
    }
}
