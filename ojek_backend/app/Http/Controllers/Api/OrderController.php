<?php

namespace App\Http\Controllers\Api;

use App\Events\DriverLocationUpdated;
use App\Events\OrderCreated;
use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class OrderController extends Controller
{
    

    public function index(Request $request)
    {
        // Return list of orders; optionally scope by role
        $user = $request->user();
        if ($user && $user->role === 'customer') {
            $orders = Order::where('customer_id', $user->id)->orderByDesc('id')->get();
        } else if ($user && $user->role === 'driver') {
            // For drivers, return all orders (frontend will filter pending/available)
            $orders = Order::orderByDesc('id')->get();
        } else {
            $orders = Order::orderByDesc('id')->get();
        }
        return response()->json($orders);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'lat_pickup' => 'required|numeric',
            'lon_pickup' => 'required|numeric',
            'pickup_address' => 'required|string',
            'lat_dropoff' => 'required|numeric',
            'lon_dropoff' => 'required|numeric',
            'dropoff_address' => 'required|string',
            'total_price' => 'required|numeric',
            'distance' => 'required|numeric',

        ]);

        $order = Order::create([
            'customer_id' => $request->user()->id,
            'driver_id' => null,
            'lat_pickup' => (float) $data['lat_pickup'],
            'lon_pickup' => (float) $data['lon_pickup'],
            'pickup_address' => $data['pickup_address'],
            'lat_dropoff' => (float) $data['lat_dropoff'],
            'lon_dropoff' => (float) $data['lon_dropoff'],
            'dropoff_address' => $data['dropoff_address'],
            'total_price' => (float) $data['total_price'],
            'distance' => (float) $data['distance'],
            'status' => 'pending',
        ]);

        OrderCreated::dispatch($order);

        return response()->json($order, 201);
    }

    public function updateLocation(Request $request, Order $order)
    {
        $data = $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
        ]);

        DriverLocationUpdated::dispatch($order, (float) $data['lat'], (float) $data['lng']);

        return response()->noContent();
    }

    public function accept(Request $request, Order $order)
    {
        $user = $request->user();
        if (!$user || $user->role !== 'driver') {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        if ($order->status !== 'pending' || ($order->driver_id && $order->driver_id > 0)) {
            return response()->json(['message' => 'Order not available'], 422);
        }
        $order->driver_id = $user->id;
        $order->status = 'accepted';
        $order->save();
        return response()->json($order);
    }

    public function reject(Request $request, Order $order)
    {
        $user = $request->user();
        if (!$user || $user->role !== 'driver') {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        // For simplicity, keep order pending and unassigned when rejected
        if ($order->driver_id === $user->id && $order->status === 'accepted') {
            $order->driver_id = null;
            $order->status = 'pending';
            $order->save();
        }
        return response()->json($order);
    }

    public function complete(Request $request, Order $order)
    {
        $user = $request->user();
        if (!$user || $user->role !== 'driver') {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        if ($order->driver_id !== $user->id) {
            return response()->json(['message' => 'Not your order'], 403);
        }
        $order->status = 'completed';
        $order->save();
        return response()->json($order);
    }
}
