<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// La suppression du compte (E21) : demandée, elle attend 30 jours ; se reconnecter l'annule.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->timestamp('suppression_demandee_le')->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->dropColumn('suppression_demandee_le');
        });
    }
};
