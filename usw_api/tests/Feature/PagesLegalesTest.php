<?php

namespace Tests\Feature;

use Tests\TestCase;

/** La confidentialité et la suppression du compte, lisibles sans l'application (Google Play). */
class PagesLegalesTest extends TestCase
{
    public function test_les_pages_legales_se_lisent_sans_compte(): void
    {
        $this->get('/confidentialite')->assertOk()->assertSee('Politique de confidentialité')->assertSee('support@discover.simeonamoussou.com');
        $this->get('/supprimer-mon-compte')->assertOk()->assertSee('Supprimer mon compte')->assertSee('30 jours');
    }
}
