<?php

namespace App\Http\Controllers\Api;

use App\Events\DriverLocationUpdated;
use App\Events\OrderCreated;
use App\Events\OrderOffer;
use App\Events\OrderAccepted;
use App\Events\OrderCompleted;
use App\Events\OrderCancelled;
use App\Events\OrderUpdate;
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
            // For drivers, only return orders that are pending and unassigned
            $orders = Order::where('status', 'pending')
                ->whereNull('driver_id')
                ->orderByDesc('id')
                ->get();
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

        // Broadcast publik tetap ada untuk kompatibilitas, namun tambahkan
        // targeted broadcast ke driver terpilih via channel privat per-user.
        try {
            OrderCreated::dispatch($order);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast OrderCreated failed: ' . $e->getMessage());
        }

        // Pilih driver terdekat yang online/active/idle dalam radius tertentu,
        // kemudian ambil subset acak untuk broadcast targeted.
        try {
            $lat = (float) $order->lat_pickup;
            $lng = (float) $order->lon_pickup;
            $radiusKm = 1.0; // radius sesuai permintaan: 1 km
            $limit = 50;     // ambil kandidat maksimal
            $sampleCount = 8; // jumlah driver yang menerima offer

            $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

            $candidates = \Illuminate\Support\Facades\DB::table('users')
                ->select(['users.id'])
                ->selectRaw($haversine . ' AS distance_km', [$lat, $lng, $lat])
                ->where('users.role', '=', 'driver')
                ->whereIn('users.status_job', ['active','online','idle'])
                ->whereNotNull('users.lat')
                ->whereNotNull('users.lng')
                ->havingRaw('distance_km <= ?', [$radiusKm])
                ->orderBy('distance_km', 'asc')
                ->limit($limit)
                ->get();

            $ids = $candidates->pluck('id')->map(fn($v) => (int) $v)->toArray();
            // Acak dan ambil sejumlah sample
            shuffle($ids);
            $targetIds = array_slice($ids, 0, min($sampleCount, count($ids)));

            if (!empty($targetIds)) {
                OrderOffer::dispatch($order, $targetIds);
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast targeted OrderOffer failed: ' . $e->getMessage());
        }

        return response()->json($order, 201);
    }

    public function updateLocation(Request $request, Order $order)
    {
        $data = $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
        ]);

        try {
            DriverLocationUpdated::dispatch($order, (float) $data['lat'], (float) $data['lng']);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast DriverLocationUpdated failed: ' . $e->getMessage());
        }

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
        try {
            OrderAccepted::dispatch($order);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast OrderAccepted failed: ' . $e->getMessage());
        }
        // Targeted notify ke driver sekitar untuk menutup modal mereka
        try {
            $lat = (float) $order->lat_pickup;
            $lng = (float) $order->lon_pickup;
            $radiusKm = 1.0;
            $limit = 50;
            $sampleCount = 8;

            $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

            $candidates = \Illuminate\Support\Facades\DB::table('users')
                ->select(['users.id'])
                ->selectRaw($haversine . ' AS distance_km', [$lat, $lng, $lat])
                ->where('users.role', '=', 'driver')
                ->whereIn('users.status_job', ['active','online','idle'])
                ->whereNotNull('users.lat')
                ->whereNotNull('users.lng')
                ->havingRaw('distance_km <= ?', [$radiusKm])
                ->orderBy('distance_km', 'asc')
                ->limit($limit)
                ->get();

            $ids = $candidates->pluck('id')->map(fn($v) => (int) $v)->toArray();
            shuffle($ids);
            $targetIds = array_slice($ids, 0, min($sampleCount, count($ids)));

            if (!empty($targetIds)) {
                OrderUpdate::dispatch($order, $targetIds, 'accepted');
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast targeted OrderUpdate (accepted) failed: ' . $e->getMessage());
        }
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
            // Siarkan ulang ke customer via channel privat order
            try {
                OrderCreated::dispatch($order);
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Broadcast OrderCreated (after reject) failed: ' . $e->getMessage());
            }
            // Lakukan targeted broadcast ke driver terdekat agar order kembali ditawarkan
            try {
                $lat = (float) $order->lat_pickup;
                $lng = (float) $order->lon_pickup;
                $radiusKm = 1.0;
                $limit = 50;
                $sampleCount = 8;

                $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

                $candidates = \Illuminate\Support\Facades\DB::table('users')
                    ->select(['users.id'])
                    ->selectRaw($haversine . ' AS distance_km', [$lat, $lng, $lat])
                    ->where('users.role', '=', 'driver')
                    ->whereIn('users.status_job', ['active','online','idle'])
                    ->whereNotNull('users.lat')
                    ->whereNotNull('users.lng')
                    ->havingRaw('distance_km <= ?', [$radiusKm])
                    ->orderBy('distance_km', 'asc')
                    ->limit($limit)
                    ->get();

                $ids = $candidates->pluck('id')->map(fn($v) => (int) $v)->toArray();
                shuffle($ids);
                $targetIds = array_slice($ids, 0, min($sampleCount, count($ids)));

                if (!empty($targetIds)) {
                    OrderOffer::dispatch($order, $targetIds);
                }
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Broadcast targeted OrderOffer (after reject) failed: ' . $e->getMessage());
            }
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
        // Gunakan nilai enum yang tersedia pada kolom status: pending, accepted, rejected, done
        $order->status = 'done';
        $order->save();
        // Update driver status to idle after completing the order
        // Simpan juga status_job pada user agar konsisten dengan filter "nearby" dan broadcast
        try {
            $user->status_job = 'idle';
            $user->save();
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Set user.status_job idle failed: ' . $e->getMessage());
        }
        $driver = $user->driver;
        if ($driver) {
            $driver->update(['status' => 'idle']);
        }
        try {
            OrderCompleted::dispatch($order);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast OrderCompleted failed: ' . $e->getMessage());
        }
        // Targeted notify ke driver sekitar untuk menutup modal mereka
        try {
            $lat = (float) $order->lat_pickup;
            $lng = (float) $order->lon_pickup;
            $radiusKm = 1.0;
            $limit = 50;
            $sampleCount = 8;

            $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

            $candidates = \Illuminate\Support\Facades\DB::table('users')
                ->select(['users.id'])
                ->selectRaw($haversine . ' AS distance_km', [$lat, $lng, $lat])
                ->where('users.role', '=', 'driver')
                ->whereIn('users.status_job', ['active','online','idle'])
                ->whereNotNull('users.lat')
                ->whereNotNull('users.lng')
                ->havingRaw('distance_km <= ?', [$radiusKm])
                ->orderBy('distance_km', 'asc')
                ->limit($limit)
                ->get();

            $ids = $candidates->pluck('id')->map(fn($v) => (int) $v)->toArray();
            shuffle($ids);
            $targetIds = array_slice($ids, 0, min($sampleCount, count($ids)));

            if (!empty($targetIds)) {
                OrderUpdate::dispatch($order, $targetIds, 'completed');
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast targeted OrderUpdate (completed) failed: ' . $e->getMessage());
        }
        return response()->json($order);
    }

    public function cancel(Request $request, Order $order)
    {
        $user = $request->user();
        if (!$user || $user->role !== 'customer') {
            return response()->json(['message' => 'Forbidden'], 403);
        }
        if ($order->customer_id !== $user->id) {
            return response()->json(['message' => 'Not your order'], 403);
        }
        // Hanya izinkan cancel jika order belum di-accept oleh driver
        if ($order->status !== 'pending' || ($order->driver_id && $order->driver_id > 0)) {
            return response()->json(['message' => 'Order already processed'], 422);
        }
        // Gunakan nilai enum yang tersedia pada kolom status
        // (pending, accepted, rejected, done)
        $order->status = 'rejected';
        $order->save();
        // Jika order dibatalkan oleh customer dari status pending, pastikan driver (jika ada) kembali idle
        try {
            if ($order->driver_id) {
                // Muat ulang user driver dan set status_job ke idle
                $driverUser = \App\Models\User::find($order->driver_id);
                if ($driverUser) {
                    $driverUser->status_job = 'idle';
                    $driverUser->save();
                }
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Set driver user.status_job idle after cancel failed: ' . $e->getMessage());
        }
         $driver = $user->driver;
        if ($driver) {
            $driver->update(['status' => 'idle']);
        }
        try {
            OrderCancelled::dispatch($order);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast OrderCancelled failed: ' . $e->getMessage());
        }
        // Targeted notify ke driver sekitar untuk menutup modal mereka
        try {
            $lat = (float) $order->lat_pickup;
            $lng = (float) $order->lon_pickup;
            $radiusKm = 1.0;
            $limit = 50;
            $sampleCount = 8;

            $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

            $candidates = \Illuminate\Support\Facades\DB::table('users')
                ->select(['users.id'])
                ->selectRaw($haversine . ' AS distance_km', [$lat, $lng, $lat])
                ->where('users.role', '=', 'driver')
                ->whereIn('users.status_job', ['active','online','idle'])
                ->whereNotNull('users.lat')
                ->whereNotNull('users.lng')
                ->havingRaw('distance_km <= ?', [$radiusKm])
                ->orderBy('distance_km', 'asc')
                ->limit($limit)
                ->get();

            $ids = $candidates->pluck('id')->map(fn($v) => (int) $v)->toArray();
            shuffle($ids);
            $targetIds = array_slice($ids, 0, min($sampleCount, count($ids)));

            if (!empty($targetIds)) {
                OrderUpdate::dispatch($order, $targetIds, 'cancelled');
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Broadcast targeted OrderUpdate (cancelled) failed: ' . $e->getMessage());
        }
        return response()->json($order);
    }
}
