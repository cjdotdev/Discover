<?php

use App\Enums\StatutContenu;
use App\Jobs\AnalyserCapture;
use App\Models\Contenu;
use App\Models\Lieu;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Une photo n'attend plus son lieu pour être publiée : sans lieu, elle rejoint la pile
// « Sans lieu » (un lieu sans position, absent de la carte), avec le nom que son auteur a
// pu donner (« Chez ma grand-mère ») sans dire où c'est.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lieux', function (Blueprint $table) {
            $table->decimal('latitude', 9, 6)->nullable()->change();
            $table->decimal('longitude', 9, 6)->nullable()->change();
            $table->foreignId('ville_id')->nullable()->change();
        });
        Schema::table('contenus', function (Blueprint $table) {
            $table->string('nom_lieu', 160)->nullable();
        });

        // Les photos restées « à compléter » faute de lieu : dans la pile, puis l'analyse repart.
        if (DB::table('contenus')->whereNull('lieu_id')->exists()) {
            $sansLieu = Lieu::sansLieu();
            DB::table('contenus')->whereNull('lieu_id')->update(['lieu_id' => $sansLieu->id]);
            Contenu::where('statut', StatutContenu::ACompleter)->each(fn (Contenu $c) => AnalyserCapture::dispatch($c));
        }
    }

    public function down(): void
    {
        Schema::table('contenus', function (Blueprint $table) {
            $table->dropColumn('nom_lieu');
        });
    }
};
