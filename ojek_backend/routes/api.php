<?php

use Illuminate\Support\Facades\Route;

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
    Route::post('logout',[AuthController::class,'logout']);
    // Nearby active drivers (no auth required)
    Route::get('drivers/nearby', [DriverController::class, 'nearby']);
    // Nearby online customers
    Route::get('customers/nearby', [CustomerController::class, 'nearby']);
    // Update authenticated user's location
    Route::post('me/location', [UserController::class, 'updateLocation']);
});


