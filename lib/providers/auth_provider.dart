import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';
import '../models/user_model.dart';

// Service Providers
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthService(apiService, storageService);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final orderServiceProvider = Provider<OrderService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return OrderService(apiService);
});

// Auth State
enum AuthStatus { initial, authenticated, unauthenticated, guest }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final GuestUser? guestUser;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.guestUser,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    GuestUser? guestUser,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      guestUser: guestUser ?? this.guestUser,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.guest;
  
  UserRole? get userRole => user?.role;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StorageService _storageService;

  AuthNotifier(this._authService, this._storageService) : super(const AuthState());

  Future<void> checkAuthStatus() async {
    debugPrint('[Auth] checkAuthStatus started');
    try {
      state = state.copyWith(isLoading: true);

      // Check if guest mode
      debugPrint('[Auth] Checking guest mode...');
      if (await _storageService.isGuestMode()) {
        final guestUser = await _storageService.getGuestData();
        if (guestUser != null) {
          debugPrint('[Auth] Guest mode detected');
          state = AuthState(
            status: AuthStatus.guest,
            guestUser: guestUser,
          );
          return;
        }
      }

      // Check if logged in - first try cached user for faster startup
      debugPrint('[Auth] Checking token...');
      final token = await _storageService.getToken();
      if (token != null) {
        debugPrint('[Auth] Token found, checking cached user...');
        // Try cached user first
        final cachedUser = await _storageService.getUser();
        if (cachedUser != null) {
          debugPrint('[Auth] Using cached user: ${cachedUser.email}');
          state = AuthState(
            status: AuthStatus.authenticated,
            user: cachedUser,
          );
          // Refresh user data in background (don't await)
          _authService.getCurrentUser().then((result) {
            if (result.success && result.user != null) {
              state = AuthState(
                status: AuthStatus.authenticated,
                user: result.user,
              );
            }
          }).catchError((_) {
            // Ignore background refresh errors
          });
          return;
        }
        
        // No cached user, try API with timeout
        debugPrint('[Auth] No cached user, calling API...');
        try {
          final result = await _authService.getCurrentUser()
              .timeout(const Duration(seconds: 10));
          if (result.success && result.user != null) {
            debugPrint('[Auth] API success: ${result.user!.email}');
            state = AuthState(
              status: AuthStatus.authenticated,
              user: result.user,
            );
            return;
          }
        } catch (e) {
          debugPrint('[Auth] API error or timeout: $e');
          // API failed or timed out - fall through to unauthenticated
        }
      }

      debugPrint('[Auth] Setting status to unauthenticated');
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('[Auth] Unexpected error: $e');
      // Catch any unexpected errors and set to unauthenticated
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.login(email: email, password: password);

    if (result.success && result.user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.message,
    );
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.register(
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    if (result.success && result.user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.message,
    );
    return false;
  }

  Future<void> continueAsGuest() async {
    final guestUser = await _authService.continueAsGuest();
    state = AuthState(
      status: AuthStatus.guest,
      guestUser: guestUser,
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Force logout due to token expiry or unauthenticated state
  /// This is called automatically when a 401 response is received
  Future<void> forceLogout({String? reason}) async {
    // Only logout if currently authenticated
    if (state.status == AuthStatus.authenticated) {
      await _storageService.deleteToken();
      await _storageService.deleteUser();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: reason ?? 'Your session has expired. Please login again.',
      );
    }
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
  }) async {
    state = state.copyWith(isLoading: true);

    final result = await _authService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      vehicleType: vehicleType,
      vehiclePlate: vehiclePlate,
      licenseNumber: licenseNumber,
    );

    if (result.success && result.user != null) {
      // Merge with existing user data in case API returns partial data
      final existingUser = state.user;
      final updatedUser = existingUser != null ? _mergeUserData(existingUser, result.user!) : result.user;
      
      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.message,
    );
    return false;
  }

  /// Merge existing user data with updated user data, preferring non-null/non-empty values from updated
  UserModel _mergeUserData(UserModel existing, UserModel updated) {
    return UserModel(
      id: updated.id.isNotEmpty ? updated.id : existing.id,
      email: updated.email.isNotEmpty ? updated.email : existing.email,
      phone: updated.phone ?? existing.phone,
      firstName: updated.firstName ?? existing.firstName,
      lastName: updated.lastName ?? existing.lastName,
      role: updated.role,
      profileImage: updated.profileImage ?? existing.profileImage,
      isVerified: updated.isVerified,
      isActive: updated.isActive,
      createdAt: updated.createdAt ?? existing.createdAt,
      updatedAt: updated.updatedAt ?? existing.updatedAt,
      loyaltyPoints: updated.loyaltyPoints ?? existing.loyaltyPoints,
      containerDeposit: updated.containerDeposit ?? existing.containerDeposit,
      referralCode: updated.referralCode ?? existing.referralCode,
      vehicleType: updated.vehicleType ?? existing.vehicleType,
      vehiclePlate: updated.vehiclePlate ?? existing.vehiclePlate,
      licenseNumber: updated.licenseNumber ?? existing.licenseNumber,
      isOnline: updated.isOnline ?? existing.isOnline,
      currentLatitude: updated.currentLatitude ?? existing.currentLatitude,
      currentLongitude: updated.currentLongitude ?? existing.currentLongitude,
      stationId: updated.stationId ?? existing.stationId,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthNotifier(authService, storageService);
});

// Current user role provider for easy access
final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.role;
});

// Check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});

// Check if guest mode
final isGuestModeProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isGuest;
});
