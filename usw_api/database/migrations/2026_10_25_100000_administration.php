<?php

use App\Models\Utilisateur;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// L'administration (« Gérer Discover ») : qui est là et qui agit, la suspension d'un compte,
// la recherche des membres. Les droits ne sont plus un rôle rangé sur le compte : le serveur
// les donne aux adresses de ADMIN_EMAILS (config/discover.php), rien ne se voit sur le compte.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->timestamp('derniere_activite_le')->nullable()->index();
            $table->timestamp('suspendu_le')->nullable()->index();
            $table->string('motif_suspension', 300)->nullable();
            // Nom, nom d'utilisateur, e-mail et ville, sans accents ni majuscules.
            $table->string('recherche', 400)->nullable();
        });

        // Un jour où le membre a ouvert Discover : les actifs par jour, semaine, mois.
        Schema::create('activites_jour', function (Blueprint $table) {
            $table->foreignId('utilisateur_id')->constrained('utilisateurs')->cascadeOnDelete();
            $table->date('jour')->index();
            $table->primary(['utilisateur_id', 'jour']);
        });

        Schema::table('utilisateurs', fn (Blueprint $table) => $table->dropColumn('role'));

        foreach (DB::table('utilisateurs')->get(['id', 'nom_affiche', 'nom_utilisateur', 'email', 'ville', 'pays']) as $u) {
            DB::table('utilisateurs')->where('id', $u->id)->update(['recherche' => Utilisateur::texteDeRecherche($u)]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('activites_jour');
        Schema::table('utilisateurs', function (Blueprint $table) {
            $table->dropColumn(['derniere_activite_le', 'suspendu_le', 'motif_suspension', 'recherche']);
            $table->string('role', 12)->default('membre');
        });
    }
};
