import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  final _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Position? get currentPosition => _currentPosition;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('LocationService: Current permission status: $permission');
    
    if (permission == LocationPermission.denied) {
      debugPrint('LocationService: Requesting permission...');
      permission = await Geolocator.requestPermission();
      debugPrint('LocationService: Permission after request: $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: Permission denied by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('LocationService: Permission denied forever');
      return false;
    }

    debugPrint('LocationService: Permission granted');
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('LocationService: No permission, returning null');
        return null;
      }

      debugPrint('LocationService: Getting current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('LocationService: Got position - lat: ${_currentPosition!.latitude}, lng: ${_currentPosition!.longitude}');
      return _currentPosition;
    } catch (e) {
      debugPrint('LocationService: Error getting position: $e');
      return null;
    }
  }

  Future<void> startBackgroundTracking({
    Duration interval = const Duration(seconds: 30),
    Function(Position)? onPositionUpdate,
  }) async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: interval,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _positionController.add(position);
      onPositionUpdate?.call(position);
    });
  }

  void stopBackgroundTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      Placemark place = placemarks.first;
      return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
    } catch (e) {
      return null;
    }
  }

  Future<List<Location>> getCoordinatesFromAddress(String address) async {
    try {
      return await locationFromAddress(address);
    } catch (e) {
      return [];
    }
  }

  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  double calculateDistanceInKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return calculateDistance(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionController.close();
  }
}
