<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
 * B20 : les pays, les villes et les lieux. La position est en latitude et longitude
 * (degrés, 6 décimales : 11 cm), avec un index : la base de développement est SQLite,
 * sans géométrie. Sur MySQL, une colonne POINT SRID 4326 pourra s'y ajouter sans rien
 * changer à l'API (ARCHITECTURE.md, section 7).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pays', function (Blueprint $table) {
            $table->id();
            $table->char('code', 2)->unique();
            $table->string('nom', 80);
            $table->timestamps();
        });

        Schema::create('villes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pays_id')->constrained('pays')->cascadeOnDelete();
            $table->string('nom', 120);
            // Le département ou la région, tel que l'application l'affiche (« Mono »).
            $table->string('region', 120)->nullable();
            $table->timestamps();
            $table->unique(['pays_id', 'nom']);
        });

        Schema::create('lieux', function (Blueprint $table) {
            $table->id();
            $table->ulid()->unique();
            // L'adresse du lieu dans l'application : /lieux/grand-popo.
            $table->string('slug', 120)->unique();
            $table->string('nom', 160);
            $table->foreignId('ville_id')->constrained('villes')->restrictOnDelete();
            $table->string('type', 40)->index();
            $table->decimal('latitude', 9, 6);
            $table->decimal('longitude', 9, 6);
            $table->unsignedInteger('nombre_contenus')->default(0);
            $table->timestamps();
            $table->index(['latitude', 'longitude']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lieux');
        Schema::dropIfExists('villes');
        Schema::dropIfExists('pays');
    }
};
