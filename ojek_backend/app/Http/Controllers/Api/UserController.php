<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Update authenticated user's location (and optional status_job).
     * POST /api/me/location
     */
    public function updateLocation(Request $request)
    {
        $data = $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
            'status_job' => 'nullable|in:online,offline,active',
        ]);

        $user = $request->user();
        $user->lat = (float) $data['lat'];
        $user->lng = (float) $data['lng'];
        if (isset($data['status_job'])) {
            $user->status_job = $data['status_job'];
        }
        $user->save();

        return response()->noContent();
    }

    /**
     * Update authenticated user's online status only.
     * POST /api/me/status
     */
    public function updateStatus(Request $request)
    {
        $data = $request->validate([
            'status_job' => 'required|in:online,offline,active',
        ]);

        $user = $request->user();
        $user->status_job = $data['status_job'];
        $user->save();

        return response()->json(['status_job' => $user->status_job]);
    }
}