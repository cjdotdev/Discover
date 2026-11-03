<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Ce que l'IA voit sur chaque photo (ou l'affiche d'une vidéo), en français : la recherche trouve
 * « nourriture » même si la légende dit « chez maman » (usw:decrire).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contenus', function (Blueprint $t) {
            $t->text('description_ia')->nullable();
            // La description et ses mots-clés, sans accents ni majuscules (Lieu::normaliser) : la recherche.
            $t->text('recherche_ia')->nullable();
            // Quand l'IA l'a décrite (vide : à décrire, les plus récentes d'abord).
            $t->timestamp('decrit_le')->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('contenus', fn (Blueprint $t) => $t->dropColumn(['description_ia', 'recherche_ia', 'decrit_le']));
    }
};
