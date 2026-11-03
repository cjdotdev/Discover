<?php

namespace App\Http\Requests\Exploration;

/** GET reels?curseur=… ; avec latitude et longitude : Près de moi ; abonnements=1 : ceux des créateurs suivis. */
class FilDesReels extends Exploration
{
    public function rules(): array
    {
        return ['curseur' => self::curseur(), 'abonnements' => ['nullable', 'boolean'], ...self::position(false)];
    }
}
