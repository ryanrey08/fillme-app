import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final UserModel? user;
  final String? token;

  AuthResult({
    required this.success,
    this.message,
    this.user,
    this.token,
  });
}

class AuthService {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthService(this._apiService, this._storageService);

  Future<AuthResult> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final response = await _apiService.post('/auth/register', data: {
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': 'customer', // Default role
      });

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;

      await _storageService.saveToken(token);
      await _storageService.saveUser(user);
      await _storageService.clearGuestData();
      _apiService.setAuthToken(token);

      return AuthResult(
        success: true,
        user: user,
        token: token,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Registration failed. Please try again.');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;

      await _storageService.saveToken(token);
      await _storageService.saveUser(user);
      await _storageService.clearGuestData();
      _apiService.setAuthToken(token);

      return AuthResult(
        success: true,
        user: user,
        token: token,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e, stackTrace) {
      print('Login parsing error: $e');
      print('Stack trace: $stackTrace');
      return AuthResult(success: false, message: 'Login failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/auth/logout');
    } catch (_) {
      // Ignore logout API errors
    } finally {
      await _storageService.deleteToken();
      await _storageService.deleteUser();
      _apiService.setAuthToken(null);
    }
  }

  Future<AuthResult> refreshToken() async {
    try {
      final response = await _apiService.post('/auth/refresh');
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;

      await _storageService.saveToken(token);
      _apiService.setAuthToken(token);

      return AuthResult(success: true, token: token);
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<AuthResult> getCurrentUser() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        return AuthResult(success: false, message: 'No token found');
      }

      _apiService.setAuthToken(token);
      final response = await _apiService.get('/auth/me');
      
      // Handle response wrapped in 'data' or direct user object
      final responseData = response.data as Map<String, dynamic>;
      final userData = responseData.containsKey('data') 
          ? (responseData['data'] is Map<String, dynamic> 
              ? responseData['data'] as Map<String, dynamic>
              : responseData['data']['user'] as Map<String, dynamic>)
          : responseData;
      
      final user = UserModel.fromJson(userData);
      await _storageService.saveUser(user);

      return AuthResult(success: true, user: user);
    } on ApiException catch (e) {
      // On 401, use cached user if available instead of logging out immediately
      if (e.statusCode == 401) {
        final cachedUser = await _storageService.getUser();
        if (cachedUser != null) {
          return AuthResult(success: true, user: cachedUser);
        }
        await logout();
      }
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      // Try to use cached user on any error
      final cachedUser = await _storageService.getUser();
      if (cachedUser != null) {
        return AuthResult(success: true, user: cachedUser);
      }
      return AuthResult(success: false, message: 'Session expired. Please login again.');
    }
  }

  Future<AuthResult> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? profileImage,
    String? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
  }) async {
    try {
      final data = {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (profileImage != null) 'profile_image': profileImage,
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
        if (licenseNumber != null) 'license_number': licenseNumber,
      };

      // Use driver profile endpoint if updating vehicle info
      final hasVehicleFields = vehicleType != null || vehiclePlate != null || licenseNumber != null;
      final endpoint = hasVehicleFields ? '/driver/profile' : '/auth/profile';

      print('=== AUTH SERVICE updateProfile ===');
      print('Sending data to $endpoint: $data');

      final response = await _apiService.put(endpoint, data: data);

      print('Response received: ${response.data}');

      final responseData = response.data as Map<String, dynamic>;
      // Handle nested response structure - API may return:
      // {data: {user: ...}} or {data: ...} or {user: ...}
      // For driver endpoint: {data: {user: {...}, driver: {...}}}
      Map<String, dynamic> userData;
      if (responseData['data'] != null && responseData['data'] is Map) {
        final data = responseData['data'] as Map<String, dynamic>;
        if (data['user'] != null && data['user'] is Map) {
          userData = Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
          // Merge driver data if present (from driver profile endpoint)
          if (data['driver'] != null && data['driver'] is Map) {
            final driverData = data['driver'] as Map<String, dynamic>;
            userData['vehicle_type'] = driverData['vehicle_type'];
            userData['vehicle_plate'] = driverData['vehicle_plate'];
            userData['license_number'] = driverData['license_number'];
            userData['is_online'] = driverData['status'] == 'available';
          }
        } else {
          userData = data;
        }
      } else if (responseData['user'] != null && responseData['user'] is Map) {
        userData = responseData['user'] as Map<String, dynamic>;
      } else {
        userData = responseData;
      }

      final user = UserModel.fromJson(userData);
      await _storageService.saveUser(user);

      return AuthResult(success: true, user: user);
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to update profile: $e');
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiService.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      return AuthResult(success: true, message: 'Password changed successfully');
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<AuthResult> forgotPassword(String email) async {
    try {
      await _apiService.post('/auth/forgot-password', data: {
        'email': email,
      });

      return AuthResult(success: true, message: 'Reset link sent to your email');
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<bool> isLoggedIn() async {
    return await _storageService.getToken() != null;
  }

  Future<bool> isGuestMode() async {
    return await _storageService.isGuestMode();
  }

  Future<UserModel?> getCachedUser() async {
    return await _storageService.getUser();
  }

  Future<GuestUser> continueAsGuest() async {
    return await _storageService.createGuestUser();
  }
}
