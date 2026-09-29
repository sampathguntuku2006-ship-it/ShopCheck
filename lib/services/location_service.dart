import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

/// Service managing user location permission, GPS coordinates,
/// Indian city centroids, and Haversine distance calculation.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Default center of India
  static const double defaultIndiaLat = 20.5937;
  static const double defaultIndiaLng = 78.9629;

  /// Major Indian Cities and their center coordinates
  static const Map<String, ({double lat, double lng, String state})> indianCities = {
    'Hyderabad': (lat: 17.3850, lng: 78.4867, state: 'Telangana'),
    'Bengaluru': (lat: 12.9716, lng: 77.5946, state: 'Karnataka'),
    'Mumbai': (lat: 19.0760, lng: 72.8777, state: 'Maharashtra'),
    'Delhi': (lat: 28.6139, lng: 77.2090, state: 'Delhi'),
    'Chennai': (lat: 13.0827, lng: 80.2707, state: 'Tamil Nadu'),
    'Kolkata': (lat: 22.5726, lng: 88.3639, state: 'West Bengal'),
    'Pune': (lat: 18.5204, lng: 73.8567, state: 'Maharashtra'),
  };

  Position? _currentPosition;
  bool _permissionDenied = false;
  LocationPermissionStatus _lastPermissionStatus = LocationPermissionStatus.granted;
  String _lastStatusMessage = '';

  Position? get currentPosition => _currentPosition;
  bool get hasLocation => _currentPosition != null;
  bool get isPermissionDenied => _permissionDenied;
  LocationPermissionStatus get lastPermissionStatus => _lastPermissionStatus;
  String get lastStatusMessage => _lastStatusMessage;

  /// Requests user location with detailed permission & service status breakdown.
  Future<({Position? position, LocationPermissionStatus status, String message})>
      requestLocationDetailed({bool requestIfNotGranted = true}) async {
    if (_currentPosition != null) {
      _lastPermissionStatus = LocationPermissionStatus.granted;
      _lastStatusMessage =
          'Location detected: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}';
      return (
        position: _currentPosition,
        status: LocationPermissionStatus.granted,
        message: _lastStatusMessage,
      );
    }
    if (_permissionDenied) {
      if (_lastStatusMessage.isEmpty) {
        _lastStatusMessage =
            'Location permission denied. GPS permission is required only for automatic current-location selection. You can select your location manually on the map.';
      }
      return (
        position: null,
        status: _lastPermissionStatus == LocationPermissionStatus.granted
            ? LocationPermissionStatus.denied
            : _lastPermissionStatus,
        message: _lastStatusMessage,
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionDenied = true;
        _lastPermissionStatus = LocationPermissionStatus.serviceDisabled;
        _lastStatusMessage =
            'Location services (GPS) are disabled on your device. Please turn on GPS in settings. GPS permission is required only for automatic current-location selection; you can select your location manually on the map.';
        return (
          position: null,
          status: LocationPermissionStatus.serviceDisabled,
          message: _lastStatusMessage,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfNotGranted) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _lastPermissionStatus = LocationPermissionStatus.permanentlyDenied;
        _lastStatusMessage =
            'Location permission is permanently denied. You can enable it in device app settings, or select your location manually on the map.';
        return (
          position: null,
          status: LocationPermissionStatus.permanentlyDenied,
          message: _lastStatusMessage,
        );
      }

      if (permission == LocationPermission.denied) {
        _permissionDenied = true;
        _lastPermissionStatus = LocationPermissionStatus.denied;
        _lastStatusMessage =
            'Location permission denied. GPS permission is required only for automatic current-location selection. You can select your location manually on the map.';
        return (
          position: null,
          status: LocationPermissionStatus.denied,
          message: _lastStatusMessage,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _currentPosition = pos;
      _permissionDenied = false;
      _lastPermissionStatus = LocationPermissionStatus.granted;
      _lastStatusMessage =
          'Location detected: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      return (
        position: pos,
        status: LocationPermissionStatus.granted,
        message: _lastStatusMessage,
      );
    } catch (e) {
      debugPrint('LocationService: Could not acquire position: $e');
      _permissionDenied = true;
      _lastPermissionStatus = LocationPermissionStatus.error;
      _lastStatusMessage =
          'Could not acquire GPS location. GPS permission is required only for automatic current-location selection. You can select your location manually on the map.';
      return (
        position: null,
        status: LocationPermissionStatus.error,
        message: _lastStatusMessage,
      );
    }
  }

  /// Requests user location permission safely.
  /// If permission is denied, falls back gracefully without crashing.
  Future<Position?> getCurrentLocation({bool requestIfNotGranted = true}) async {
    final result = await requestLocationDetailed(requestIfNotGranted: requestIfNotGranted);
    return result.position;
  }

  /// Calculates the geographical distance in kilometers using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Formats distance into clean human-readable text (e.g. "450 m" or "1.8 km").
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Mock position setter for testing
  void setMockPositionForTesting(double lat, double lng) {
    _currentPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    _permissionDenied = false;
  }

  /// Mock permission denied state for testing
  void setMockPermissionDeniedForTesting({
    LocationPermissionStatus status = LocationPermissionStatus.denied,
    String? customMessage,
  }) {
    _currentPosition = null;
    _permissionDenied = true;
    _lastPermissionStatus = status;
    _lastStatusMessage = customMessage ??
        (status == LocationPermissionStatus.serviceDisabled
            ? 'Location services (GPS) are disabled on your device. Please turn on GPS in settings. GPS permission is required only for automatic current-location selection; you can select your location manually on the map.'
            : status == LocationPermissionStatus.permanentlyDenied
                ? 'Location permission is permanently denied. You can enable it in device app settings, or select your location manually on the map.'
                : 'Location permission denied. GPS permission is required only for automatic current-location selection. You can select your location manually on the map.');
  }

  /// Reset state for testing
  void resetForTesting() {
    _currentPosition = null;
    _permissionDenied = false;
    _lastPermissionStatus = LocationPermissionStatus.granted;
    _lastStatusMessage = '';
  }
}
