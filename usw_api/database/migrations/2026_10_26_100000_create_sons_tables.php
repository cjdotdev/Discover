<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les sons à mettre sur un reel, comme sur TikTok, Instagram ou Snapchat : un catalogue de
 * musiques dont la licence permet l'usage dans une application (database/sons/catalogue.json),
 * les favoris de chacun, et le son choisi par un reel (son extrait, les deux volumes).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sons', function (Blueprint $t) {
            $t->id();
            $t->ulid()->unique();
            // D'où il vient (« incompetech:Allada.mp3 ») : l'import ne le fait qu'une fois.
            $t->string('cle', 200)->unique();
            $t->string('titre', 160);
            $t->string('artiste', 120);
            $t->string('categorie', 40)->index();
            $t->unsignedInteger('duree_ms');
            $t->string('chemin', 200);
            // Le dessin du son (100 hauteurs de 0 à 100) et le passage le plus fort, proposé d'abord.
            $t->json('forme')->nullable();
            $t->unsignedInteger('debut_conseille_ms')->default(0);
            $t->string('licence', 60);
            $t->string('licence_url', 300)->nullable();
            $t->string('attribution', 300);
            $t->string('recherche', 300)->default('');
            $t->unsignedInteger('nombre_reels')->default(0);
            $t->boolean('actif')->default(true);
            $t->timestamps();
            $t->index(['actif', 'nombre_reels']);
        });

        Schema::create('sons_favoris', function (Blueprint $t) {
            $t->id();
            $t->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $t->foreignId('son_id')->constrained('sons')->cascadeOnDelete();
            $t->timestamps();
            $t->unique(['utilisateur_id', 'son_id']);
        });

        Schema::table('contenus', function (Blueprint $t) {
            $t->foreignId('son_id')->nullable()->after('son')->constrained('sons')->nullOnDelete();
            $t->unsignedInteger('son_debut_ms')->nullable()->after('son_id');
            // De 0 à 100 : la musique, et le son d'origine de la vidéo.
            $t->unsignedTinyInteger('son_volume')->nullable()->after('son_debut_ms');
            $t->unsignedTinyInteger('origine_volume')->nullable()->after('son_volume');
        });
    }

    public function down(): void
    {
        Schema::table('contenus', function (Blueprint $t) {
            $t->dropConstrainedForeignId('son_id');
            $t->dropColumn(['son_debut_ms', 'son_volume', 'origine_volume']);
        });
        Schema::dropIfExists('sons_favoris');
        Schema::dropIfExists('sons');
    }
};
