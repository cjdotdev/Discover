<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les villes et villages du monde (GeoNames, plus de 1 000 habitants) : le choix de la ville
 * dans le profil, sans position. À part des villes des lieux, qui ne gardent que celles utilisées.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('localites', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('geoname_id')->unique();
            $table->char('pays', 2);
            $table->string('nom', 200);
            // Le nom sans accents ni majuscules, ce que la recherche compare.
            $table->string('recherche', 200);
            $table->string('region', 120)->nullable();
            $table->unsignedInteger('population')->default(0);
            $table->decimal('latitude', 9, 6);
            $table->decimal('longitude', 9, 6);
            $table->index(['pays', 'population']);
            $table->index(['pays', 'recherche']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('localites');
    }
};
