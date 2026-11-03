<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Ce qu'on voit sur chaque photo (« forest », « beach », « food »), lu par le téléphone : la
 * recherche (« arbre ») et les goûts choisis à l'inscription s'en servent.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('etiquettes', function (Blueprint $t) {
            $t->id();
            $t->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $t->string('nom', 60);
            $t->float('confiance');
            $t->unique(['contenu_id', 'nom']);
            $t->index(['nom', 'confiance']);
        });
        Schema::table('contenus', function (Blueprint $t) {
            // Quand ses étiquettes ont été lues (vide : à lire, l'équipe rattrape les anciennes).
            $t->timestamp('etiquete_le')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('contenus', fn (Blueprint $t) => $t->dropColumn('etiquete_le'));
        Schema::dropIfExists('etiquettes');
    }
};
