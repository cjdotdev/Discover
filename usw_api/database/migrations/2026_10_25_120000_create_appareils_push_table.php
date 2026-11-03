<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Les téléphones qui reçoivent les notifications (Firebase Cloud Messaging) : le jeton que
// Firebase donne au téléphone, la connexion (jeton Sanctum) qui l'a enregistré, et ce que le
// membre a choisi de recevoir dans ses réglages.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('appareils_push', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->string('jeton', 512)->unique();
            // La connexion de ce téléphone : à la déconnexion, il ne reçoit plus rien.
            $table->unsignedBigInteger('jeton_acces_id')->nullable()->index();
            $table->json('preferences')->nullable();
            $table->timestamp('pause_jusqu_a')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('appareils_push');
    }
};
