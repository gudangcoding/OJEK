<?php

namespace Tests\Feature\Http\Controllers\Api;

use App\Events\OrderCreated;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * @see \App\Http\Controllers\Api\OrderController
 */
final class OrderControllerTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function index_responds_with_authenticated(): void
    {
        $user = User::factory()->create();
        Order::factory()->count(2)->create();

        // Sanctum::actingAs($user);

        $response = $this->getJson(route('orders.index'));

        $response->assertOk();
        $response->assertJsonStructure([
            ['id', 'customer_id', 'driver_id', 'address', 'status']
        ]);
    }


    #[Test]
    public function store_saves_and_broadcasts(): void
    {
        Event::fake();
        $user = User::factory()->create();
        // Sanctum::actingAs($user);

        $payload = ['address' => 'Jl. Testing'];
        $response = $this->postJson(route('orders.store'), $payload);

        $response->assertCreated();
        $response->assertJsonFragment([
            'address' => 'Jl. Testing',
            'customer_id' => $user->id,
            'status' => 'pending',
        ]);

        $this->assertDatabaseHas('orders', [
            'address' => 'Jl. Testing',
            'customer_id' => $user->id,
            'status' => 'pending',
        ]);

        $order = Order::first();
        Event::assertDispatched(OrderCreated::class, function ($event) use ($order) {
            return $event->order->is($order);
        });
    }
}
