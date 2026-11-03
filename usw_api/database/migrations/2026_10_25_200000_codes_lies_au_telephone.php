<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Le défi d'un code : un secret remis au téléphone qui a demandé le code. Seul ce téléphone peut
 * l'essayer ; quelqu'un d'autre qui tape la même adresse ne fait ni tomber ce code, ni ses essais.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('codes_email', function (Blueprint $t) {
            $t->string('defi_hache', 64)->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('codes_email', function (Blueprint $t) {
            $t->dropIndex(['defi_hache']);
            $t->dropColumn('defi_hache');
        });
    }
};
