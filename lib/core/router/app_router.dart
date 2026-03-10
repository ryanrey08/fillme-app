import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

// Auth screens
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';

// Customer screens
import '../../features/customer/screens/customer_home_screen.dart';
import '../../features/customer/screens/customer_orders_screen.dart';
import '../../features/customer/screens/customer_profile_screen.dart';
import '../../features/customer/screens/edit_profile_screen.dart';
import '../../features/customer/screens/station_list_screen.dart';
import '../../features/customer/screens/station_detail_screen.dart';
import '../../features/customer/screens/cart_screen.dart';
import '../../features/customer/screens/checkout_screen.dart';
import '../../features/customer/screens/order_tracking_screen.dart';
import '../../features/customer/screens/address_management_screen.dart';

// Driver screens
import '../../features/driver/screens/driver_home_screen.dart';
import '../../features/driver/screens/driver_delivery_screen.dart';
import '../../features/driver/screens/driver_earnings_screen.dart';
import '../../features/driver/screens/driver_profile_screen.dart';
import '../../features/driver/screens/driver_edit_profile_screen.dart';
import '../../features/driver/screens/vehicle_info_screen.dart';
import '../../features/driver/screens/work_schedule_screen.dart';
import '../../features/driver/screens/service_areas_screen.dart';
import '../../features/driver/screens/delivery_history_screen.dart';
import '../../features/driver/screens/delivery_detail_screen.dart';

// Owner screens
import '../../features/owner/screens/owner_dashboard_screen.dart';
import '../../features/owner/screens/owner_orders_screen.dart';
import '../../features/owner/screens/owner_analytics_screen.dart';
import '../../features/owner/screens/owner_drivers_screen.dart';
import '../../features/owner/screens/owner_inventory_screen.dart';
import '../../features/owner/screens/owner_promos_screen.dart';
import '../../features/owner/screens/owner_settings_screen.dart';
import '../../features/owner/screens/owner_products_screen.dart';

// Route names
class AppRoutes {
  // Auth routes
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Customer routes
  static const customerHome = '/customer/home';
  static const customerOrders = '/customer/orders';
  static const customerProfile = '/customer/profile';
  static const editProfile = '/customer/profile/edit';
  static const stationList = '/customer/stations';
  static const stationDetail = '/customer/stations/:stationId';
  static const cart = '/customer/cart';
  static const checkout = '/customer/checkout';
  static const orderTracking = '/customer/orders/:orderId';
  static const addressManagement = '/customer/addresses';

  // Driver routes
  static const driverHome = '/driver/home';
  static const driverDeliveries = '/driver/deliveries';
  static const driverEarnings = '/driver/earnings';
  static const driverProfile = '/driver/profile';
  static const driverEditProfile = '/driver/profile/edit';
  static const driverVehicleInfo = '/driver/profile/vehicle';
  static const driverWorkSchedule = '/driver/work/schedule';
  static const driverServiceAreas = '/driver/work/areas';
  static const driverDeliveryHistory = '/driver/work/history';
  static const deliveryDetail = '/driver/deliveries/:orderId';

  // Owner routes
  static const ownerDashboard = '/owner/dashboard';
  static const ownerOrders = '/owner/orders';
  static const ownerAnalytics = '/owner/analytics';
  static const ownerDrivers = '/owner/drivers';
  static const ownerInventory = '/owner/inventory';
  static const ownerPromos = '/owner/promos';
  static const ownerSettings = '/owner/settings';
  static const ownerProducts = '/owner/products';
}

// Auth state notifier for router refresh
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // Show splash during initial check
      if (authState.status == AuthStatus.initial) {
        return isSplash ? null : AppRoutes.splash;
      }

      // If not authenticated and not on auth pages, redirect to login
      if (authState.status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      // If authenticated and on auth pages, redirect to appropriate home
      if (authState.status == AuthStatus.authenticated ||
          authState.status == AuthStatus.guest) {
        if (isLoggingIn || isSplash) {
          return _getHomeRouteForRole(authState.user?.role);
        }
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Customer routes
      ShellRoute(
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.customerHome,
            builder: (context, state) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.customerOrders,
            builder: (context, state) => const CustomerOrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.customerProfile,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.stationList,
        builder: (context, state) => const StationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.stationDetail,
        builder: (context, state) {
          final stationId = state.pathParameters['stationId']!;
          return StationDetailScreen(stationId: stationId);
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderTracking,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.addressManagement,
        builder: (context, state) => const AddressManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Driver routes
      ShellRoute(
        builder: (context, state, child) => DriverShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.driverHome,
            builder: (context, state) => const DriverHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverDeliveries,
            builder: (context, state) => const DriverDeliveryScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverEarnings,
            builder: (context, state) => const DriverEarningsScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverProfile,
            builder: (context, state) => const DriverProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverEditProfile,
            builder: (context, state) => const DriverEditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverVehicleInfo,
            builder: (context, state) => const VehicleInfoScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverWorkSchedule,
            builder: (context, state) => const WorkScheduleScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverServiceAreas,
            builder: (context, state) => const ServiceAreasScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverDeliveryHistory,
            builder: (context, state) => const DeliveryHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.deliveryDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return DeliveryDetailScreen(orderId: orderId);
        },
      ),

      // Owner routes
      ShellRoute(
        builder: (context, state, child) => OwnerShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.ownerDashboard,
            builder: (context, state) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerOrders,
            builder: (context, state) => const OwnerOrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerAnalytics,
            builder: (context, state) => const OwnerAnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerDrivers,
            builder: (context, state) => const OwnerDriversScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerInventory,
            builder: (context, state) => const OwnerInventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerPromos,
            builder: (context, state) => const OwnerPromosScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerSettings,
            builder: (context, state) => const OwnerSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerProducts,
            builder: (context, state) => const OwnerProductsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

String _getHomeRouteForRole(UserRole? role) {
  switch (role) {
    case UserRole.customer:
      return AppRoutes.customerHome;
    case UserRole.driver:
      return AppRoutes.driverHome;
    case UserRole.owner:
      return AppRoutes.ownerDashboard;
    default:
      return AppRoutes.customerHome; // Default for guest
  }
}

// Shell widgets for bottom navigation
class CustomerShell extends StatelessWidget {
  final Widget child;
  const CustomerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    debugPrint('[CustomerShell] build() called');
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.customerHome)) return 0;
    if (location.startsWith(AppRoutes.customerOrders)) return 1;
    if (location.startsWith(AppRoutes.customerProfile)) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.customerHome);
        break;
      case 1:
        context.go(AppRoutes.customerOrders);
        break;
      case 2:
        context.go(AppRoutes.customerProfile);
        break;
    }
  }
}

class DriverShell extends StatelessWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.driverHome)) return 0;
    if (location.startsWith(AppRoutes.driverDeliveries)) return 1;
    if (location.startsWith(AppRoutes.driverEarnings)) return 2;
    if (location.startsWith(AppRoutes.driverProfile)) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.driverHome);
        break;
      case 1:
        context.go(AppRoutes.driverDeliveries);
        break;
      case 2:
        context.go(AppRoutes.driverEarnings);
        break;
      case 3:
        context.go(AppRoutes.driverProfile);
        break;
    }
  }
}

class OwnerShell extends StatelessWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Drivers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.ownerDashboard)) return 0;
    if (location.startsWith(AppRoutes.ownerOrders)) return 1;
    if (location.startsWith(AppRoutes.ownerAnalytics)) return 2;
    if (location.startsWith(AppRoutes.ownerDrivers)) return 3;
    if (location.startsWith(AppRoutes.ownerSettings)) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.ownerDashboard);
        break;
      case 1:
        context.go(AppRoutes.ownerOrders);
        break;
      case 2:
        context.go(AppRoutes.ownerAnalytics);
        break;
      case 3:
        context.go(AppRoutes.ownerDrivers);
        break;
      case 4:
        context.go(AppRoutes.ownerSettings);
        break;
    }
  }
}

// Error screen
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Something went wrong',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
