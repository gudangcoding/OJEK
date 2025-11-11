<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Targeted update notifications (accepted/cancelled/completed) to selected drivers.
 * Broadcasts to per-driver private channels: private-users.{driverId}
 */
class OrderUpdate implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var int[] */
    public array $driverIds;
    public string $type; // 'accepted' | 'cancelled' | 'completed'

    public function __construct(public Order $order, array $driverIds, string $type)
    {
        $this->driverIds = array_map(fn($id) => (int) $id, $driverIds);
        $this->type = $type;
    }

    public function broadcastOn(): array
    {
        return array_map(function ($id) {
            return new PrivateChannel('users.' . $id);
        }, $this->driverIds);
    }

    public function broadcastAs(): string
    {
        return $this->type;
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