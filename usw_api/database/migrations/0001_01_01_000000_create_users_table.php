<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Lot 1 : les membres (ARCHITECTURE.md, section 7). Un compte s'ouvre par e-mail (mot de passe et
// code à 6 chiffres) ou par Google (pas de mot de passe). Les sessions de Laravel restent pour le web.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('utilisateurs', function (Blueprint $table) {
            $table->id();
            $table->ulid('ulid')->unique();
            $table->string('email')->unique();
            $table->string('fournisseur', 10)->default('email'); // email, google
            $table->string('google_sub')->nullable()->unique();
            $table->string('mot_de_passe')->nullable();
            $table->timestamp('email_verifie_le')->nullable();

            // Le profil (« Compléter le profil », E36).
            $table->string('nom_affiche', 60)->nullable();
            $table->string('nom_utilisateur', 30)->nullable()->unique();
            $table->string('bio', 160)->nullable();
            $table->string('site', 120)->nullable();
            $table->string('pays', 60)->nullable();
            $table->string('ville', 60)->nullable();
            $table->boolean('position')->default(true);
            $table->json('types_aimes')->nullable();
            $table->string('avatar')->nullable();
            $table->timestamp('profil_complete_le')->nullable();

            // 5 essais de mot de passe, puis 15 minutes de pause (E37).
            $table->unsignedTinyInteger('essais_mot_de_passe')->default(0);
            $table->timestamp('bloque_jusqu_a')->nullable();

            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('utilisateur_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('utilisateurs');
        Schema::dropIfExists('sessions');
    }
};
