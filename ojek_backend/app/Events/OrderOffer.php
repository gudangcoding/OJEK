<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Targeted offer of a newly created order to selected drivers.
 * Broadcasts to per-driver private channels: private-users.{driverId}
 */
class OrderOffer implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /** @var int[] */
    public array $driverIds;

    public function __construct(public Order $order, array $driverIds)
    {
        $this->driverIds = array_map(fn($id) => (int) $id, $driverIds);
    }

    public function broadcastOn(): array
    {
        // Broadcast ke channel privat per-user driver terpilih
        return array_map(function ($id) {
            return new PrivateChannel('users.' . $id);
        }, $this->driverIds);
    }

    public function broadcastAs(): string
    {
        // Gunakan event name yang sama agar frontend tidak perlu dibedakan
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
            'targeted' => true,
        ];
    }
}