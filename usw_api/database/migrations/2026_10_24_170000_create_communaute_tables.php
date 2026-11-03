<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * Lot 5 : la communauté (E05, E07, E09, E10, E19, E22). Les compteurs restent sur les contenus,
 * les commentaires et les membres (tenus par des observers) : pas de COUNT à chaque affichage.
 * Les notifications (lot 7) sont la table standard de Laravel, vidée après 60 jours.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Une réaction par membre et par contenu : cœur, waouh, voyage ou merci.
        Schema::create('reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $table->string('type', 10);
            $table->timestamps();
            $table->unique(['utilisateur_id', 'contenu_id']);
            $table->index(['contenu_id', 'type']);
        });

        // Un commentaire, ou une réponse (un seul niveau : la réponse à une réponse va sous le même fil).
        Schema::create('commentaires', function (Blueprint $table) {
            $table->id();
            $table->ulid('ulid')->unique();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('parent_id')->nullable()->constrained('commentaires')->cascadeOnDelete();
            $table->foreignId('repond_a_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->string('texte', 1000);
            $table->boolean('epingle')->default(false);
            $table->boolean('masque')->default(false);
            $table->json('mentions')->nullable();
            $table->unsignedInteger('nombre_jaime')->default(0);
            $table->unsignedInteger('nombre_reponses')->default(0);
            $table->timestamps();
            $table->index(['contenu_id', 'parent_id', 'created_at']);
        });

        Schema::create('jaimes_commentaires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('commentaire_id')->constrained('commentaires')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['utilisateur_id', 'commentaire_id']);
        });

        Schema::create('collections', function (Blueprint $table) {
            $table->id();
            $table->ulid('ulid')->unique();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->string('nom', 60);
            $table->boolean('secrete')->default(false);
            $table->unsignedInteger('nombre_contenus')->default(0);
            $table->timestamps();
            $table->unique(['utilisateur_id', 'nom']);
        });

        Schema::create('enregistrements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('collection_id')->constrained('collections')->cascadeOnDelete();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['collection_id', 'contenu_id']);
            $table->index('contenu_id');
        });

        Schema::create('abonnements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('abonne_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('createur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['abonne_id', 'createur_id']);
            $table->index('createur_id');
        });

        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->unsignedInteger('nombre_abonnes')->default(0);
            $table->unsignedInteger('nombre_abonnements')->default(0);
        });

        // Un signalement (E22) : son auteur n'est jamais montré à celui qu'il vise. La file et les
        // décisions (lot 6) se lisent ailleurs, par l'administrateur seul.
        Schema::create('signalements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->string('cible_type', 12); // contenu, utilisateur, commentaire
            $table->unsignedBigInteger('cible_id');
            $table->string('motif', 80);
            $table->string('precision', 500)->nullable();
            $table->string('statut', 12)->default('ouvert');
            $table->timestamps();
            $table->unique(['utilisateur_id', 'cible_type', 'cible_id']);
            $table->index(['cible_type', 'cible_id']);
        });

        Schema::create('blocages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bloqueur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('bloque_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['bloqueur_id', 'bloque_id']);
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type');
            $table->morphs('notifiable');
            $table->text('data');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        foreach (['notifications', 'blocages', 'signalements', 'abonnements', 'enregistrements', 'collections', 'jaimes_commentaires', 'commentaires', 'reactions'] as $t) {
            Schema::dropIfExists($t);
        }
        Schema::table('utilisateurs', fn (Blueprint $table) => $table->dropColumn(['nombre_abonnes', 'nombre_abonnements']));
    }
};
