<?php

return [
    // Default ke 'pusher' agar event realtime dikirim ke Pusher bila env tidak diset
    'default' => env('BROADCAST_DRIVER', 'pusher'),

    'connections' => [
        'pusher' => [
            'driver' => 'pusher',
            'key' => env('PUSHER_APP_KEY'),
            'secret' => env('PUSHER_APP_SECRET'),
            'app_id' => env('PUSHER_APP_ID'),
            'options' => [
                // Biarkan Laravel dan SDK menentukan host berdasarkan cluster
                // Menghindari host override yang bisa menyebabkan broadcast gagal
                'useTLS' => env('PUSHER_USE_TLS', true),
                'cluster' => env('PUSHER_APP_CLUSTER'),
            ],
        ],

        'ably' => [
            'driver' => 'ably',
            'key' => env('ABLY_KEY'),
        ],

        'log' => [
            'driver' => 'log',
        ],

        'null' => [
            'driver' => 'null',
        ],
    ],
];