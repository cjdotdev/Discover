<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// La file des tâches et le cache, dans la petite base SQLite du serveur (config/database.php,
// connexion `locale`) : l'ouvrier peut la lire chaque seconde sans réveiller Neon.
return new class extends Migration
{
    public function getConnection(): ?string
    {
        return config('queue.connections.database.connection');
    }

    public function up(): void
    {
        $s = Schema::connection($this->getConnection());
        if (! $s->hasTable('jobs')) {
            $s->create('jobs', function (Blueprint $table) {
                $table->id();
                $table->string('queue')->index();
                $table->longText('payload');
                $table->unsignedSmallInteger('attempts');
                $table->unsignedInteger('reserved_at')->nullable();
                $table->unsignedInteger('available_at');
                $table->unsignedInteger('created_at');
            });
        }
        if (! $s->hasTable('job_batches')) {
            $s->create('job_batches', function (Blueprint $table) {
                $table->string('id')->primary();
                $table->string('name');
                $table->integer('total_jobs');
                $table->integer('pending_jobs');
                $table->integer('failed_jobs');
                $table->longText('failed_job_ids');
                $table->mediumText('options')->nullable();
                $table->integer('cancelled_at')->nullable();
                $table->integer('created_at');
                $table->integer('finished_at')->nullable();
            });
        }
        if (! $s->hasTable('failed_jobs')) {
            $s->create('failed_jobs', function (Blueprint $table) {
                $table->id();
                $table->string('uuid')->unique();
                $table->string('connection');
                $table->string('queue');
                $table->longText('payload');
                $table->longText('exception');
                $table->timestamp('failed_at')->useCurrent();
                $table->index(['connection', 'queue', 'failed_at']);
            });
        }

        $c = Schema::connection(config('cache.stores.database.connection'));
        if (! $c->hasTable('cache')) {
            $c->create('cache', function (Blueprint $table) {
                $table->string('key')->primary();
                $table->mediumText('value');
                $table->bigInteger('expiration')->index();
            });
        }
        if (! $c->hasTable('cache_locks')) {
            $c->create('cache_locks', function (Blueprint $table) {
                $table->string('key')->primary();
                $table->string('owner');
                $table->bigInteger('expiration')->index();
            });
        }
    }

    public function down(): void
    {
        // Rien : ces tables ne contiennent rien de précieux, et la migration précédente ne les
        // recrée pas dans la base principale.
    }
};
