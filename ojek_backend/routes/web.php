<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});



Route::get('auths/register', [App\Http\Controllers\Api\AuthController::class, 'register']);
Route::get('auths/login', [App\Http\Controllers\Api\AuthController::class, 'login']);
Route::get('auths/logout', [App\Http\Controllers\Api\AuthController::class, 'logout']);


Route::get('auths/register', [App\Http\Controllers\Api\AuthController::class, 'register']);
Route::get('auths/login', [App\Http\Controllers\Api\AuthController::class, 'login']);
Route::get('auths/logout', [App\Http\Controllers\Api\AuthController::class, 'logout']);
