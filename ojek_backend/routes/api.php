<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Http;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\CustomerController;

Route::post('login',[AuthController::class,'login']);
Route::post('register',[AuthController::class,'register']);

Route::middleware('auth:sanctum')->group(function(){
Route::get('orders',[OrderController::class,'index']);
Route::post('orders',[OrderController::class,'store']);
Route::post('orders/{order}/location', [OrderController::class, 'updateLocation']);
Route::post('orders/{order}/accept', [OrderController::class, 'accept']);
Route::post('orders/{order}/reject', [OrderController::class, 'reject']);
Route::post('orders/{order}/complete', [OrderController::class, 'complete']);
Route::post('orders/{order}/cancel', [OrderController::class, 'cancel']);
    Route::post('logout',[AuthController::class,'logout']);
    // Update authenticated user's location
    Route::post('me/location', [UserController::class, 'updateLocation']);
    // Update authenticated user's online status only
    Route::post('me/status', [UserController::class, 'updateStatus']);
});

// Nearby endpoints tidak memerlukan auth agar peta tetap tampil
Route::get('drivers/nearby', [DriverController::class, 'nearby']);
Route::get('customers/nearby', [CustomerController::class, 'nearby']);

// Proxy untuk pencarian geocode (Nominatim) agar lolos CORS di Flutter Web
Route::get('geocode/search', function() {
    $q = request('q');
    if (!$q) {
        return response()->json([]);
    }
    $res = Http::withHeaders(['User-Agent' => 'ojek_app'])
        ->get('https://nominatim.openstreetmap.org/search', [
            'q' => $q,
            'format' => 'json',
            'addressdetails' => 1,
            'limit' => 10,
        ]);
    return response()->json($res->json(), $res->status());
});

// Proxy untuk reverse geocode (lat/lon -> alamat) agar lolos CORS di Flutter Web
Route::get('geocode/reverse', function() {
    $lat = request('lat');
    $lon = request('lon');
    if ($lat === null || $lon === null) {
        return response()->json(['display_name' => null]);
    }

    $res = Http::withHeaders(['User-Agent' => 'ojek_app'])
        ->get('https://nominatim.openstreetmap.org/reverse', [
            'lat' => $lat,
            'lon' => $lon,
            'format' => 'json',
            'addressdetails' => 1,
        ]);

    $body = $res->json();
    $name = is_array($body) && array_key_exists('display_name', $body) ? $body['display_name'] : null;
    return response()->json(['display_name' => $name], $res->status());
});


