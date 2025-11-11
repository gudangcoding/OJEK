<?php

return [
    // Terapkan CORS untuk API dan endpoint otorisasi broadcasting
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'broadcasting/*', 'broadcasting/auth'],

    // Izinkan semua method HTTP (GET, POST, PUT, DELETE, OPTIONS, dll)
    'allowed_methods' => ['*'],

    // Izinkan origin frontend dev (Flutter web dev server)
    'allowed_origins' => [
        'http://localhost:8080',
        'http://localhost:8081',
        'http://localhost:8090',
        'http://localhost:8091',
        'http://localhost:8092',
        'http://localhost:8093',
        'http://localhost:8094',
        'http://localhost:8095',
    ],

    'allowed_origins_patterns' => [],

    // Izinkan semua header, termasuk Authorization
    'allowed_headers' => ['*'],

    // Header yang diekspos ke browser
    'exposed_headers' => [],

    // Cache preflight
    'max_age' => 0,

    // Tidak menggunakan kredensial cookies untuk API berbasis Bearer token
    'supports_credentials' => false,
];