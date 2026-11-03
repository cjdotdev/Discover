<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les vues (une par personne, par publication et par jour) et le score de recommandation :
 * celui d'une publication (son engagement adouci par l'âge) et celui d'un lieu (ses meilleures).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contenus', function (Blueprint $t) {
            $t->unsignedInteger('nombre_vues')->default(0);
            $t->unsignedInteger('nombre_vues_completes')->default(0);
            $t->double('score')->default(0)->index();
        });
        Schema::table('lieux', function (Blueprint $t) {
            $t->double('score')->default(0)->index();
        });
        Schema::create('vues', function (Blueprint $t) {
            $t->id();
            $t->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            // « u:<id> » pour un membre, « a:<empreinte> » pour un téléphone sans compte.
            $t->string('spectateur', 80);
            $t->date('jour');
            $t->unsignedInteger('duree_ms')->default(0);
            $t->boolean('complete')->default(false);
            $t->timestamps();
            $t->unique(['contenu_id', 'spectateur', 'jour']);
            $t->index(['spectateur', 'jour']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vues');
        Schema::table('lieux', fn (Blueprint $t) => $t->dropColumn('score'));
        Schema::table('contenus', fn (Blueprint $t) => $t->dropColumn(['nombre_vues', 'nombre_vues_completes', 'score']));
    }
};
