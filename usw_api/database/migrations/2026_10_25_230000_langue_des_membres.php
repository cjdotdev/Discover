<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** La langue de l'application de chaque membre : ses notifications arrivent dans cette langue. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->string('langue', 5)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('utilisateurs', fn (Blueprint $table) => $table->dropColumn('langue'));
    }
};
