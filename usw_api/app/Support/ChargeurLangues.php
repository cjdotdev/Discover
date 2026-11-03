<?php

namespace App\Support;

use Illuminate\Translation\FileLoader;

/**
 * Les traductions « en une phrase » (__('Le texte français')) : celles de lang/{code}.json, et
 * celles des paquets de langue (resources/langues/{code}.json), partagés avec l'application.
 */
class ChargeurLangues extends FileLoader
{
    public function load($locale, $group, $namespace = null)
    {
        $lignes = parent::load($locale, $group, $namespace);
        if ($group === '*' && $namespace === '*') {
            return array_merge(Langues::textes($locale), $lignes);
        }

        return $lignes;
    }
}
