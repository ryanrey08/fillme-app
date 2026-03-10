<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\StationController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PaymentController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Mobile API Routes
|--------------------------------------------------------------------------
| Routes for mobile applications (Customer App, Driver App)
| Prefix: /api/mobile/v1
*/

Route::prefix('v1')->group(function () {

    // Public routes
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'registerCustomer']);
        Route::post('login', [AuthController::class, 'loginWithEmail']);
        Route::post('login/phone', [AuthController::class, 'login']);
    });

    // Public station discovery
    Route::get('stations/discover', [StationController::class, 'discover']);
    Route::get('stations/{station:uuid}', [StationController::class, 'show']);
    Route::get('stations/{station:uuid}/products', [StationController::class, 'products']);
    Route::get('stations/{station:uuid}/categories', [StationController::class, 'categories']);
    Route::get('stations/{station:uuid}/reviews', [StationController::class, 'reviews']);

    // Zones
    Route::get('zones', [App\Http\Controllers\Api\ZoneController::class, 'index']);
    Route::get('zones/{zone}', [App\Http\Controllers\Api\ZoneController::class, 'show']);

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {
        
        // Auth
        Route::prefix('auth')->group(function () {
            Route::post('logout', [AuthController::class, 'logout']);
            Route::get('me', [AuthController::class, 'me']);
            Route::get('profile', [CustomerController::class, 'profile']);
            Route::put('profile', [CustomerController::class, 'updateProfile']);
            Route::post('fcm-token', [AuthController::class, 'updateFcmToken']);
            Route::post('change-password', [AuthController::class, 'changePassword']);
            Route::post('refresh', [AuthController::class, 'refresh']);
        });

        // Customer routes
        Route::prefix('customer')->group(function () {
            Route::get('profile', [CustomerController::class, 'profile']);
            Route::put('profile', [CustomerController::class, 'updateProfile']);
            
            // Addresses
            Route::get('addresses', [CustomerController::class, 'addresses']);
            Route::post('addresses', [CustomerController::class, 'storeAddress']);
            Route::put('addresses/{address}', [CustomerController::class, 'updateAddress']);
            Route::delete('addresses/{address}', [CustomerController::class, 'deleteAddress']);
            Route::post('addresses/{address}/default', [CustomerController::class, 'setDefaultAddress']);
            
            // Loyalty
            Route::get('loyalty', [CustomerController::class, 'loyaltyPoints']);
            Route::get('loyalty/history', [CustomerController::class, 'loyaltyHistory']);
            
            // Subscriptions
            Route::get('subscriptions', [CustomerController::class, 'subscriptions']);
            Route::post('subscriptions', [CustomerController::class, 'createSubscription']);
            Route::put('subscriptions/{subscription}', [CustomerController::class, 'updateSubscription']);
            Route::post('subscriptions/{subscription}/pause', [CustomerController::class, 'pauseSubscription']);
            Route::post('subscriptions/{subscription}/resume', [CustomerController::class, 'resumeSubscription']);
            Route::post('subscriptions/{subscription}/cancel', [CustomerController::class, 'cancelSubscription']);

            // Containers
            Route::get('containers', [CustomerController::class, 'containerLogs']);
        });

        // Orders
        Route::prefix('orders')->group(function () {
            Route::get('/', [OrderController::class, 'index']);
            Route::get('/customer', [OrderController::class, 'customerOrders']);
            Route::get('/station', [OrderController::class, 'stationOrders']);
            Route::post('/', [OrderController::class, 'store']);
            Route::get('/{order}', [OrderController::class, 'show'])->whereNumber('order');
            Route::get('/number/{orderNumber}', [OrderController::class, 'showByNumber']);
            Route::put('/{orderNumber}/status', [OrderController::class, 'updateStatusByNumber']);
            Route::post('/{orderNumber}/assign-driver', [OrderController::class, 'assignDriverByNumber']);
            Route::post('/{order}/cancel', [OrderController::class, 'cancel'])->whereNumber('order');
            Route::get('/{order}/track', [OrderController::class, 'track'])->whereNumber('order');
        });

        // Payments
        Route::prefix('payments')->group(function () {
            Route::post('initiate', [PaymentController::class, 'initiate']);
            Route::post('confirm', [PaymentController::class, 'confirm']);
        });

        // Notifications
        Route::prefix('notifications')->group(function () {
            Route::get('/', [NotificationController::class, 'index']);
            Route::post('/{notification}/read', [NotificationController::class, 'markAsRead']);
            Route::post('/read-all', [NotificationController::class, 'markAllAsRead']);
            Route::get('/unread-count', [NotificationController::class, 'unreadCount']);
        });

        // Driver routes
        Route::prefix('driver')->group(function () {
            Route::get('dashboard', [DriverController::class, 'dashboard']);
            Route::put('status', [DriverController::class, 'updateStatus']);
            Route::post('location', [DriverController::class, 'updateLocation']);
            Route::get('queue', [DriverController::class, 'deliveryQueue']);
            Route::put('deliveries/{identifier}/status', [DriverController::class, 'updateDeliveryStatus']);
            Route::get('earnings', [DriverController::class, 'earnings']);
            Route::put('profile', [DriverController::class, 'updateProfile']);
            Route::get('deliveries/{orderNumber}/route', [DriverController::class, 'getDeliveryRoute']);
            Route::get('deliveries/history', [DriverController::class, 'deliveryHistory']);
            Route::get('schedule', [DriverController::class, 'getSchedule']);
            Route::put('schedule', [DriverController::class, 'updateSchedule']);
            Route::get('service-areas', [DriverController::class, 'getServiceAreas']);
        });

        // Station staff routes
        Route::prefix('station')->group(function () {
            Route::get('dashboard', [StationController::class, 'dashboard']);
            Route::get('drivers', [StationController::class, 'drivers']);
            Route::get('settings', [StationController::class, 'getSettings']);
            Route::put('profile', [StationController::class, 'updateProfile']);
            Route::put('operating-hours', [StationController::class, 'updateOperatingHours']);
            Route::put('delivery-settings', [StationController::class, 'updateDeliverySettings']);
            Route::get('payment-methods', [StationController::class, 'getPaymentMethods']);
            Route::put('payment-methods', [StationController::class, 'updatePaymentMethods']);
            Route::get('inventory', [StationController::class, 'inventory']);
            Route::put('inventory/{product}', [StationController::class, 'updateInventory']);
            Route::get('analytics', [StationController::class, 'analytics']);
            Route::put('zones', [StationController::class, 'manageZones']);
        });

        // Station products routes
        // Station promotions routes
        Route::prefix('station/promotions')->group(function () {
            Route::get('/', [\App\Http\Controllers\Api\Station\PromotionController::class, 'index']);
            Route::post('/', [\App\Http\Controllers\Api\Station\PromotionController::class, 'store']);
            Route::get('/{promotion}', [\App\Http\Controllers\Api\Station\PromotionController::class, 'show']);
            Route::put('/{promotion}', [\App\Http\Controllers\Api\Station\PromotionController::class, 'update']);
            Route::delete('/{promotion}', [\App\Http\Controllers\Api\Station\PromotionController::class, 'destroy']);
        });

        Route::prefix('station/products')->group(function () {
            Route::get('/categories', [\App\Http\Controllers\Api\Station\ProductController::class, 'categories']);
            Route::get('/', [\App\Http\Controllers\Api\Station\ProductController::class, 'index']);
            Route::post('/', [\App\Http\Controllers\Api\Station\ProductController::class, 'store']);
            Route::get('/{product}', [\App\Http\Controllers\Api\Station\ProductController::class, 'show']);
            Route::put('/{product}', [\App\Http\Controllers\Api\Station\ProductController::class, 'update']);
            Route::delete('/{product}', [\App\Http\Controllers\Api\Station\ProductController::class, 'destroy']);
        });


        // Cart
        Route::prefix('cart')->group(function () {
            Route::get('/', [\App\Http\Controllers\Api\CartController::class, 'index']);
            Route::post('/add', [\App\Http\Controllers\Api\CartController::class, 'addItem']);
            Route::put('/items/{item}', [\App\Http\Controllers\Api\CartController::class, 'updateItem']);
            Route::delete('/items/{item}', [\App\Http\Controllers\Api\CartController::class, 'removeItem']);
            Route::post('/clear', [\App\Http\Controllers\Api\CartController::class, 'clear']);
            Route::post("/checkout", [\App\Http\Controllers\Api\CartController::class, "checkout"]);
        });

        // Chat
        Route::prefix('chat')->group(function () {
            Route::get('rooms', [App\Http\Controllers\Api\ChatController::class, 'rooms']);
            Route::get('rooms/{room}/messages', [App\Http\Controllers\Api\ChatController::class, 'messages']);
            Route::post('rooms/{room}/messages', [App\Http\Controllers\Api\ChatController::class, 'sendMessage']);
        });

        // Broadcasting auth route for mobile apps (WebSocket channel authorization)
        Route::post('/broadcasting/auth', \App\Http\Controllers\Api\BroadcastAuthController::class);
    });
});
// Add after chat routes, before closing the middleware group

