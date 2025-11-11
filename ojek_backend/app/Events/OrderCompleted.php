<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Broadcasting\Channel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OrderCompleted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Order $order)
    {
    }

    public function broadcastOn(): array
    {
        // Dual broadcast: publik 'orders' untuk driver, privat 'orders.{id}' untuk customer
        return [
            new Channel('orders'),
            new PrivateChannel('orders.' . $this->order->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'completed';
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->order->id,
            'customer_id' => $this->order->customer_id,
            'driver_id' => $this->order->driver_id,
            'status' => $this->order->status,
        ];
    }
}