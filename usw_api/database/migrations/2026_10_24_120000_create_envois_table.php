<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * B30 : les envois par morceaux (ARCHITECTURE.md, section 6.3). Chaque contenu en a deux :
 * l'aperçu (une image légère, d'abord) et l'original (la photo ou la vidéo telle quelle).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('envois', function (Blueprint $table) {
            $table->id();
            $table->ulid()->unique();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            // apercu ou original.
            $table->string('role', 10);
            $table->string('type', 60);
            $table->unsignedBigInteger('taille');
            $table->unsignedBigInteger('recu')->default(0);
            $table->char('empreinte_sha256', 64);
            // en_cours, termine.
            $table->string('statut', 12)->default('en_cours');
            $table->timestamp('derniere_activite')->nullable();
            $table->timestamps();
            $table->unique(['contenu_id', 'role']);
            $table->index(['statut', 'derniere_activite']);
        });

        Schema::table('contenus', function (Blueprint $table) {
            // Pourquoi il est refusé, ou ce qu'il faut compléter : pour son auteur seul.
            $table->string('motif', 255)->nullable()->after('statut');
            // Ce qui manque encore (« telephone », « date », « lieu ») quand il est à compléter.
            $table->json('manque')->nullable()->after('motif');
        });
    }

    public function down(): void
    {
        Schema::table('contenus', function (Blueprint $table) {
            $table->dropColumn(['motif', 'manque']);
        });
        Schema::dropIfExists('envois');
    }
};
