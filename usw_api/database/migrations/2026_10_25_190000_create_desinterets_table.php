<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** « Pas intéressé » : la publication ne revient plus dans « Pour toi », son créateur moins souvent. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('desinterets', function (Blueprint $t) {
            $t->id();
            $t->string('spectateur', 80);
            $t->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $t->foreignId('auteur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $t->timestamps();
            $t->unique(['spectateur', 'contenu_id']);
            $t->index(['spectateur', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('desinterets');
    }
};
