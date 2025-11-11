<?php

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

// Gunakan Sanctum token untuk otorisasi channel private Pusher
Broadcast::routes(['middleware' => ['auth:sanctum']]);

Broadcast::channel('orders.{orderId}', function (User $user, int $orderId) {
    $order = Order::find($orderId);

    if (!$order) {
        return false;
    }

    return in_array($user->id, [$order->customer_id, $order->driver_id]);
});