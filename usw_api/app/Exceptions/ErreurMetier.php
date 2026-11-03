<?php

namespace App\Exceptions;

use Symfony\Component\HttpKernel\Exception\HttpException;

/** Un refus de l'API dont le message, en français, est fait pour le membre : il est montré tel quel. */
class ErreurMetier extends HttpException
{
    public function __construct(int $code, string $message)
    {
        parent::__construct($code, $message);
    }
}
