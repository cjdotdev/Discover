<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Le lifestyle : l'album de vie de chaque membre (ce qu'il mange, ce qu'il fait, ses lieux). Ses
 * publications ne passent pas à l'accueil de Discover : elles ne se voient que dans son lifestyle,
 * et seulement s'il l'a rendu visible.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contenus', function (Blueprint $t) {
            // decouverte (l'accueil, les lieux, les Reels) ou lifestyle.
            $t->string('portee', 12)->default('decouverte')->index();
        });
        Schema::table('utilisateurs', function (Blueprint $t) {
            // Son lifestyle se voit des autres (sinon, de lui seul).
            $t->boolean('lifestyle_visible')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('contenus', fn (Blueprint $t) => $t->dropColumn('portee'));
        Schema::table('utilisateurs', fn (Blueprint $t) => $t->dropColumn('lifestyle_visible'));
    }
};
