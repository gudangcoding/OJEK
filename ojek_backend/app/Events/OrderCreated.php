<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OrderCreated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Order $order)
    {
    }

    public function broadcastOn(): array
    {
        // Hanya ke channel privat khusus order (publik dinonaktifkan)
        return [
            new PrivateChannel('orders.' . $this->order->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'order.created';
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->order->id,
            'customer_id' => $this->order->customer_id,
            'driver_id' => $this->order->driver_id,
            'lat_pickup' => $this->order->lat_pickup,
            'lon_pickup' => $this->order->lon_pickup,
            'pickup_address' => $this->order->pickup_address,
            'lat_dropoff' => $this->order->lat_dropoff,
            'lon_dropoff' => $this->order->lon_dropoff,
            'dropoff_address' => $this->order->dropoff_address,
            'total_price' => $this->order->total_price,
            'distance' => $this->order->distance,
            'status' => $this->order->status,
        ];
    }
}
