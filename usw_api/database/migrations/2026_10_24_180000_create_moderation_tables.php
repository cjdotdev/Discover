<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Lot 6 : la modération (E24, E25), réservée aux administrateurs. Chaque décision est gardée : qui,
// quoi, pourquoi.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('utilisateurs', fn (Blueprint $table) => $table->string('role', 12)->default('membre'));

        Schema::create('decisions_moderation', function (Blueprint $table) {
            $table->id();
            $table->foreignId('contenu_id')->nullable()->constrained('contenus')->nullOnDelete();
            $table->foreignId('commentaire_id')->nullable()->constrained('commentaires')->nullOnDelete();
            $table->foreignId('moderateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->string('decision', 12); // publier, refuser, masquer, classer
            $table->string('motif', 300)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('decisions_moderation');
        Schema::table('utilisateurs', fn (Blueprint $table) => $table->dropColumn('role'));
    }
};
