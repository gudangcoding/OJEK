<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class DriverController extends Controller
{
    /**
     * List active drivers near a given coordinate.
     * GET /drivers/nearby?lat=..&lng=..&radius=km
     */
    public function nearby(Request $request)
    {
        $data = $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
            'radius' => 'nullable|numeric', // km
            'limit' => 'nullable|integer|min:1|max:100',
        ]);

        $lat = (float) $data['lat'];
        $lng = (float) $data['lng'];
        $radius = isset($data['radius']) ? (float) $data['radius'] : 5.0; // km
        $limit = isset($data['limit']) ? (int) $data['limit'] : 20;

        $drivers = User::query()
            ->where('role', 'driver')
            ->where('status_job', 'active')
            ->whereNotNull('lat')
            ->whereNotNull('lng')
            ->get();

        $result = [];
        foreach ($drivers as $d) {
            $dLat = (float) $d->lat;
            $dLng = (float) $d->lng;
            // Haversine distance in KM
            $distance = $this->haversineKm($lat, $lng, $dLat, $dLng);
            if ($distance <= $radius) {
                $result[] = [
                    'id' => $d->id,
                    'name' => $d->name,
                    'lat' => $dLat,
                    'lng' => $dLng,
                    'distance_km' => round($distance, 3),
                    'status_online' => $d->status_job === 'active',
                    'status_job' => $d->status_job,
                    'phone' => $d->phone,
                    // Optional fields if present in schema
                    'avatar_url' => property_exists($d, 'avatar_url') ? $d->avatar_url : null,
                    'vehicle_plate' => property_exists($d, 'vehicle_plate') ? $d->vehicle_plate : null,
                    'vehicle_model' => property_exists($d, 'vehicle_model') ? $d->vehicle_model : null,
                    'rating' => property_exists($d, 'rating') ? (float) $d->rating : null,
                ];
            }
        }

        // Sort by distance asc and limit to 20
        usort($result, function ($a, $b) {
            return $a['distance_km'] <=> $b['distance_km'];
        });
        $result = array_slice($result, 0, $limit);

        return response()->json($result);
    }

    private function haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $R = 6371.0; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) * sin($dLat / 2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return $R * $c;
    }
}