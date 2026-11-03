<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// L'original vérifié n'est plus gardé par le serveur (config/discover.php) : sa ligne reste, pour
// son empreinte (les doublons), mais son chemin peut être vide.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('fichiers_originaux', fn (Blueprint $table) => $table->string('chemin')->nullable()->change());
    }

    public function down(): void
    {
        Schema::table('fichiers_originaux', fn (Blueprint $table) => $table->string('chemin')->nullable(false)->change());
    }
};
