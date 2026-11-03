<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// On entre dans Discover avec un code à 6 chiffres reçu par e-mail (ou avec Google) : plus de mot
// de passe, plus d'essais comptés ni de blocage, plus de ticket « mot de passe oublié ». Les sessions
// web, la file des tâches et le cache quittent la base principale (la base `locale` du serveur).
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            foreach (['mot_de_passe', 'essais_mot_de_passe', 'bloque_jusqu_a', 'remember_token'] as $colonne) {
                if (Schema::hasColumn('utilisateurs', $colonne)) {
                    $table->dropColumn($colonne);
                }
            }
        });
        if (Schema::hasColumn('codes_email', 'ticket_hache')) {
            Schema::table('codes_email', fn (Blueprint $table) => $table->dropColumn('ticket_hache'));
        }

        Schema::dropIfExists('sessions');
        if (config('queue.connections.database.connection') !== config('database.default')) {
            foreach (['jobs', 'job_batches', 'failed_jobs'] as $t) {
                Schema::dropIfExists($t);
            }
        }
        if (config('cache.stores.database.connection') !== config('database.default')) {
            foreach (['cache', 'cache_locks'] as $t) {
                Schema::dropIfExists($t);
            }
        }
    }

    public function down(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->string('mot_de_passe')->nullable();
            $table->unsignedTinyInteger('essais_mot_de_passe')->default(0);
            $table->timestamp('bloque_jusqu_a')->nullable();
            $table->rememberToken();
        });
        Schema::table('codes_email', fn (Blueprint $table) => $table->string('ticket_hache')->nullable());
    }
};
