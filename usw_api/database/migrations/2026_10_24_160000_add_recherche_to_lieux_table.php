<?php

use App\Models\Lieu;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// La recherche (E31) : le nom du lieu, sa ville et sa région, en minuscules et sans accents, pour
// que « possotome » trouve « Lac Ahémé, Possotomé » sur SQLite comme sur PostgreSQL.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lieux', fn (Blueprint $table) => $table->string('recherche', 255)->default(''));
        Lieu::with('ville')->chunkById(200, fn ($lieux) => $lieux->each->rafraichirRecherche());
    }

    public function down(): void
    {
        Schema::table('lieux', fn (Blueprint $table) => $table->dropColumn('recherche'));
    }
};
