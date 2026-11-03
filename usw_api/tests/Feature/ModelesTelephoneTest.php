<?php

namespace Tests\Feature;

use App\Models\ModeleTelephone;
use App\Models\Utilisateur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** B24 : indiquer son téléphone quand le fichier ne le dit pas (E15). */
class ModelesTelephoneTest extends TestCase
{
    use RefreshDatabase;

    private string $jeton;

    protected function setUp(): void
    {
        parent::setUp();
        $this->jeton = Utilisateur::factory()->create()->createToken('t')->plainTextToken;
        foreach ([['Tecno', 'Camon 50 Pro'], ['Tecno', 'Camon 30'], ['Tecno', 'Spark 20'], ['Infinix', 'Note 40'], ['Apple', 'iPhone 13']] as [$marque, $nom]) {
            ModeleTelephone::create(['marque' => $marque, 'nom' => $nom]);
        }
    }

    private function chercher(string $q)
    {
        return $this->getJson('/api/v1/modeles-telephone?q='.urlencode($q), ['Authorization' => "Bearer {$this->jeton}"]);
    }

    public function test_chercher_par_le_debut_de_la_marque_ou_du_nom(): void
    {
        $this->chercher('tecno')->assertOk()->assertJsonCount(3, 'data');
        $this->chercher('CAMON')->assertOk()->assertJsonCount(2, 'data');
        $this->chercher('camon 5')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.complet', 'Tecno Camon 50 Pro');
        $this->chercher('iph')->assertOk()->assertJsonPath('data.0.complet', 'iPhone 13');
        $this->chercher('nokia')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_la_recherche_demande_un_compte(): void
    {
        $this->getJson('/api/v1/modeles-telephone?q=tecno')->assertUnauthorized();
    }

    public function test_ajouter_un_telephone(): void
    {
        $this->postJson('/api/v1/modeles-telephone', ['marque' => ' Itel ', 'nom' => 'A70'], ['Authorization' => "Bearer {$this->jeton}"])
            ->assertCreated()->assertJsonPath('data.complet', 'Itel A70');
        $this->chercher('itel a')->assertJsonCount(1, 'data');
    }

    public function test_un_doublon_est_refuse_meme_ecrit_autrement(): void
    {
        $this->postJson('/api/v1/modeles-telephone', ['marque' => 'TECNO', 'nom' => 'camon-50  pro'], ['Authorization' => "Bearer {$this->jeton}"])
            ->assertUnprocessable()->assertJsonPath('erreurs.nom.0', 'Ce téléphone est déjà dans la liste.');
    }
}
