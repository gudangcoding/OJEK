<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        channels: __DIR__.'/../routes/channels.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Jangan redirect ke route 'login' untuk request API tanpa autentikasi.
        // Biarkan middleware mengembalikan 401 tanpa mencoba membuat URL login.
        $middleware->redirectTo(fn (Request $request) => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
