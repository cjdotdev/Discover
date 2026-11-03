<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * B21 : les contenus (photos et reels), leur capture (d'où viennent le téléphone, la date et
 * la position), le fichier original (privé) et ses variantes (publiques), et les modèles de
 * téléphone (B24).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('modeles_telephone', function (Blueprint $table) {
            $table->id();
            $table->string('marque', 60);
            $table->string('nom', 100);
            // « tecno camon 50 pro » : la recherche par le début du nom ou de la marque.
            $table->string('nom_recherche', 170)->index();
            $table->foreignId('ajoute_par')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->unsignedInteger('nombre_contenus')->default(0);
            $table->timestamps();
            $table->unique(['marque', 'nom']);
        });

        Schema::create('contenus', function (Blueprint $table) {
            $table->id();
            $table->ulid()->unique();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('lieu_id')->nullable()->constrained('lieux')->nullOnDelete();
            $table->string('type', 10);
            $table->string('statut', 20)->default('brouillon');
            $table->string('badge', 20)->nullable();
            $table->string('titre', 120)->nullable();
            $table->text('legende')->nullable();
            // Un reel : sa durée en secondes et son son.
            $table->unsignedSmallInteger('duree')->nullable();
            $table->string('son', 120)->nullable();
            $table->unsignedInteger('largeur')->nullable();
            $table->unsignedInteger('hauteur')->nullable();
            // Les compteurs, tenus à jour à chaque réaction, commentaire, enregistrement.
            $table->unsignedInteger('nombre_reactions')->default(0);
            $table->unsignedInteger('nombre_commentaires')->default(0);
            $table->unsignedInteger('nombre_enregistrements')->default(0);
            $table->unsignedInteger('nombre_partages')->default(0);
            $table->timestamp('publie_le')->nullable();
            $table->timestamps();
            $table->index(['statut', 'publie_le']);
            $table->index(['utilisateur_id', 'publie_le']);
            $table->index(['lieu_id', 'statut', 'publie_le']);
        });

        Schema::create('captures', function (Blueprint $table) {
            $table->id();
            $table->foreignId('contenu_id')->unique()->constrained('contenus')->cascadeOnDelete();
            // fichier (lu dans l'EXIF), appareil (pris depuis l'application), declaree.
            $table->string('source', 20);
            $table->foreignId('modele_telephone_id')->nullable()->constrained('modeles_telephone')->nullOnDelete();
            $table->timestamp('prise_le')->nullable();
            $table->decimal('latitude', 9, 6)->nullable();
            $table->decimal('longitude', 9, 6)->nullable();
            // L'origine de chaque information : { "modele": "exif", "date": "exif", "position": "declaree" }.
            $table->json('origines')->nullable();
            $table->timestamps();
            $table->index(['latitude', 'longitude']);
        });

        Schema::create('fichiers_originaux', function (Blueprint $table) {
            $table->id();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            $table->char('empreinte_sha256', 64)->unique();
            $table->string('format', 20);
            $table->unsignedInteger('largeur')->nullable();
            $table->unsignedInteger('hauteur')->nullable();
            $table->unsignedBigInteger('poids');
            // Sur le disque privé : jamais servi tel quel (lien signé, lot 3).
            $table->string('chemin');
            $table->timestamps();
        });

        Schema::create('variantes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('contenu_id')->constrained('contenus')->cascadeOnDelete();
            // flou, 480, 1080, 2160, video, affiche.
            $table->string('usage', 10);
            $table->string('chemin');
            $table->unsignedInteger('largeur')->nullable();
            $table->unsignedInteger('hauteur')->nullable();
            $table->timestamps();
            $table->unique(['contenu_id', 'usage']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('variantes');
        Schema::dropIfExists('fichiers_originaux');
        Schema::dropIfExists('captures');
        Schema::dropIfExists('contenus');
        Schema::dropIfExists('modeles_telephone');
    }
};
