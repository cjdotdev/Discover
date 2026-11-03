<?php

use App\Models\Lieu;
use App\Services\Contenus\Compteurs;
use App\Services\Lieux\TypeDeLieu;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * La seconde vérification demandée par l'auteur d'une publication refusée, les lieux
 * enregistrés, le nombre de reels d'un lieu, et le type des lieux déjà créés (deviné par leur nom).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contenus', function (Blueprint $table) {
            $table->timestamp('recours_le')->nullable()->after('motif');
        });

        Schema::create('lieux_enregistres', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->foreignId('lieu_id')->constrained('lieux')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['utilisateur_id', 'lieu_id']);
        });

        Schema::table('lieux', function (Blueprint $table) {
            $table->unsignedInteger('nombre_reels')->default(0)->after('nombre_contenus');
            $table->unsignedInteger('nombre_verifiees')->default(0)->after('nombre_reels');
        });

        Lieu::query()->select(['id', 'slug', 'nom', 'type'])->chunkById(200, function ($lieux) {
            foreach ($lieux as $l) {
                Compteurs::lieu($l->id);
                if ($l->slug !== Lieu::SANS_LIEU && ($l->type === null || $l->type === TypeDeLieu::AUTRES)) {
                    Lieu::whereKey($l->id)->update(['type' => TypeDeLieu::deviner((string) $l->nom)]);
                }
            }
        });
    }

    public function down(): void
    {
        Schema::table('lieux', fn (Blueprint $table) => $table->dropColumn(['nombre_reels', 'nombre_verifiees']));
        Schema::dropIfExists('lieux_enregistres');
        Schema::table('contenus', fn (Blueprint $table) => $table->dropColumn('recours_le'));
    }
};
