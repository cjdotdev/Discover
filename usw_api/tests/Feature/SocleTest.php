<?php

namespace Tests\Feature;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Lot 0 : l'API répond, sous /api/v1, et toutes ses erreurs ont la même forme
 * { "message": …, "erreurs": … } (ARCHITECTURE.md, section 5).
 */
class SocleTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Des routes d'essai, le temps du test, pour provoquer chaque erreur.
        Route::prefix('api/v1/essai')->group(function () {
            Route::post('/validation', fn (Request $r) => $r->validate([
                'email' => ['required', 'email'],
                'mot_de_passe' => ['required', 'string', 'min:8'],
            ]));
            Route::get('/connecte', fn () => 'ok')->middleware('auth:sanctum');
            Route::get('/interdit', fn () => abort(403));
            Route::get('/limite', fn () => 'ok')->middleware('throttle:1,1');
            Route::get('/panne', fn () => throw new \RuntimeException('détail interne'));
        });
    }

    public function test_le_bilan_de_sante_est_vert(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_l_api_repond_sous_api_v1(): void
    {
        $this->getJson('/api/v1/etat')
            ->assertOk()
            ->assertExactJson(['nom' => 'Discover', 'version' => 'v1']);
    }

    public function test_une_route_inconnue_renvoie_404_en_json(): void
    {
        $this->get('/api/v1/rien')
            ->assertNotFound()
            ->assertExactJson(['message' => 'Introuvable.']);
    }

    public function test_une_validation_renvoie_le_premier_message_et_les_erreurs_par_champ(): void
    {
        $this->postJson('/api/v1/essai/validation', ['email' => 'pas-une-adresse', 'mot_de_passe' => 'court'])
            ->assertUnprocessable()
            ->assertExactJson([
                'message' => 'Entrez une adresse e-mail valide.',
                'erreurs' => [
                    'email' => ['Entrez une adresse e-mail valide.'],
                    'mot_de_passe' => ['Le mot de passe doit faire au moins 8 caractères.'],
                ],
            ]);
    }

    public function test_sans_jeton_la_reponse_est_401(): void
    {
        $this->getJson('/api/v1/essai/connecte')
            ->assertUnauthorized()
            ->assertExactJson(['message' => 'Connectez-vous pour continuer.']);
    }

    public function test_une_action_interdite_renvoie_403(): void
    {
        $this->getJson('/api/v1/essai/interdit')
            ->assertForbidden()
            ->assertExactJson(['message' => "Vous n'avez pas le droit de faire cela."]);
    }

    public function test_trop_de_demandes_renvoie_429_avec_le_delai(): void
    {
        $this->getJson('/api/v1/essai/limite')->assertOk();
        $this->getJson('/api/v1/essai/limite')
            ->assertTooManyRequests()
            ->assertExactJson(['message' => 'Trop de demandes. Réessayez dans un instant.'])
            ->assertHeader('Retry-After');
    }

    public function test_une_panne_ne_montre_aucun_detail_hors_developpement(): void
    {
        config(['app.debug' => false]);

        $this->getJson('/api/v1/essai/panne')
            ->assertInternalServerError()
            ->assertExactJson(['message' => 'Une erreur est survenue. Réessayez plus tard.']);
    }
}
