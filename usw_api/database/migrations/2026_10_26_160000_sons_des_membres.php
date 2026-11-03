<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les sons importés par les membres (le son d'une vidéo, un fichier du téléphone), comme le « son
 * original » de TikTok : les autres peuvent l'utiliser une fois qu'un reel l'a en ligne. Signalé
 * par 3 membres, il est retiré.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sons', function (Blueprint $t) {
            $t->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $t->unsignedInteger('signalements')->default(0);
        });
        Schema::create('sons_signalements', function (Blueprint $t) {
            $t->foreignId('son_id')->constrained('sons')->cascadeOnDelete();
            $t->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $t->timestamp('created_at')->nullable();
            $t->primary(['son_id', 'utilisateur_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sons_signalements');
        Schema::table('sons', function (Blueprint $t) {
            $t->dropConstrainedForeignId('utilisateur_id');
            $t->dropColumn('signalements');
        });
    }
};
