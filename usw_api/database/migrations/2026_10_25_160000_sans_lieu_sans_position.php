<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/** Les photos de la pile « Sans lieu » ne gardent pas la position de leur prise. */
return new class extends Migration
{
    public function up(): void
    {
        $sansLieu = DB::table('lieux')->where('slug', 'sans-lieu')->value('id');
        if ($sansLieu === null) {
            return;
        }
        DB::table('captures')
            ->whereIn('contenu_id', DB::table('contenus')->where('lieu_id', $sansLieu)->select('id'))
            ->update(['latitude' => null, 'longitude' => null]);
    }

    public function down(): void {}
};
