<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Les codes à 6 chiffres envoyés par e-mail (inscription, mot de passe oublié) : hachés, valables
// 10 minutes, 5 essais au plus (ARCHITECTURE.md, section 6.1). Pour un oubli, un code juste donne un
// ticket, lui aussi haché, qui permet de choisir le nouveau mot de passe.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('codes_email', function (Blueprint $table) {
            $table->id();
            $table->string('email')->index();
            $table->string('but', 12); // inscription, oubli
            $table->string('code_hache');
            $table->string('ticket_hache')->nullable();
            $table->unsignedTinyInteger('essais')->default(0);
            $table->timestamp('expire_le');
            $table->timestamp('utilise_le')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('codes_email');
    }
};
