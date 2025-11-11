<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerController extends Controller
{
    /**
     * Return nearby online customers around given lat/lng.
     * Query params:
     * - lat (required)
     * - lng (required)
     * - radius (optional, km, default 5)
     * - limit (optional, default 20)
     */
    public function nearby(Request $request)
    {
        $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
            'radius' => 'nullable|numeric',
            'limit' => 'nullable|integer|min:1|max:100',
        ]);

        $lat = (float) $request->input('lat');
        $lng = (float) $request->input('lng');
        $radiusKm = (float) ($request->input('radius', 5));
        $limit = (int) ($request->input('limit', 20));

        // Haversine formula to compute distance in KM
        $haversine = "(6371 * acos(cos(radians(?)) * cos(radians(users.lat)) * cos(radians(users.lng) - radians(?)) + sin(radians(?)) * sin(radians(users.lat))))";

        $query = DB::table('users')
            ->select([
                'users.id',
                'users.name',
                'users.lat',
                'users.lng',
                'users.phone',
                'users.status_job',
                DB::raw($haversine . ' AS distance_km'),
                // Optional enriched fields
                'users.avatar_url',
                'users.vehicle_plate',
                'users.vehicle_model',
                'users.rating',
            ])
            ->whereNotNull('users.lat')
            ->whereNotNull('users.lng')
            ->where('users.role', '=', 'customer')
            ->where(function ($q) {
                // Consider online when status_job is active
                $q->where('users.status_job', '=', 'active');
            })
            ->having('distance_km', '<=', $radiusKm)
            ->orderBy('distance_km', 'asc')
            ->limit($limit);

        $customers = $query->setBindings([$lat, $lng, $lat])->get();

        $payload = $customers->map(function ($c) {
            return [
                'id' => $c->id,
                'name' => $c->name,
                'lat' => $c->lat,
                'lng' => $c->lng,
                'distance_km' => round($c->distance_km, 3),
                'status_job' => $c->status_job,
                'status_online' => $c->status_job === 'active',
                'phone' => $c->phone,
                // Optional fields if exist
                'avatar_url' => $c->avatar_url ?? null,
                'vehicle_plate' => $c->vehicle_plate ?? null,
                'vehicle_model' => $c->vehicle_model ?? null,
                'rating' => $c->rating ?? null,
            ];
        });

        return response()->json([
            'data' => $payload,
            'meta' => [
                'count' => $payload->count(),
                'radius_km' => $radiusKm,
                'limit' => $limit,
            ],
        ]);
    }
}