<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Log;

class BroadcastAuthController extends Controller
{
    /**
     * Authenticate for WebSocket channel access.
     * This is a custom endpoint for mobile apps using Sanctum tokens.
     */
    public function __invoke(Request $request)
    {
        $user = $request->user();
        
        Log::info('[Broadcast Auth API] Request received', [
            'user_id' => $user->id,
            'user_email' => $user->email,
            'user_station_id' => $user->station_id,
            'channel_name' => $request->input('channel_name'),
            'socket_id' => $request->input('socket_id'),
        ]);
        
        // Let Laravel handle the channel authorization
        return Broadcast::auth($request);
    }
}
