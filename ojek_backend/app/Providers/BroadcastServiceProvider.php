<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Broadcast;

class BroadcastServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Registrasi route otorisasi channel broadcasting
        Broadcast::routes(['middleware' => ['auth:sanctum']]);

        // Muat definisi channel
        require base_path('routes/channels.php');
    }
}