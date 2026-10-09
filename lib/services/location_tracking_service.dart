import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../data/api/api_constants.dart';
import '../core/security/secure_session_store.dart';
import 'socket/socket_service.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _periodicTimer;
  bool _isTracking = false;
  bool _isGoodsTrip = false;
  int _sequence = 0;
  DateTime? _lastUpdateSentAt;
  Position? _lastKnownPosition;

  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking => _isTracking;

  Future<void> initializeService() async {
    // Initialization fallback if called at app boot
  }

  Future<void> startTracking(String? tripId, {bool isGoods = false}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _isGoodsTrip = isGoods;

    final prefs = await SharedPreferences.getInstance();
    if (tripId != null) {
      await prefs.setString('active_trip_id', tripId);
    } else {
      await prefs.remove('active_trip_id');
    }

    if (_isTracking) {
      await sendFreshLocationUpdate(tripId: tripId, force: true);
      return;
    }

    _isTracking = true;
    _sequence = 0;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    // Send immediate initial location update
    await sendFreshLocationUpdate(tripId: tripId, force: true);

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) async {
        if (position != null && _isTracking) {
          _lastKnownPosition = position;
          await _sendLocationPayload(position, tripIdOverride: tripId);
        }
      },
    );

    // Periodic fallback timer (every 15 seconds) to ensure fresh location on backend even when stationary
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      if (_lastUpdateSentAt == null ||
          DateTime.now().difference(_lastUpdateSentAt!).inSeconds >= 12) {
        await sendFreshLocationUpdate(tripId: tripId, force: true);
      }
    });
  }

  /// Explicitly fetches current real GPS location and sends it via Socket and REST API immediately.
  /// Awaits transmission to prevent race conditions when completing a ride.
  Future<bool> sendFreshLocationUpdate({String? tripId, bool force = false}) async {
    final position = await fetchBestCurrentPosition();
    if (position == null) return false;
    _lastKnownPosition = position;
    await _sendLocationPayload(position, tripIdOverride: tripId, force: force);
    return true;
  }

  Future<Position?> fetchBestCurrentPosition() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition() ?? _lastKnownPosition;
      }
      return position;
    } catch (e) {
      print('Failed to fetch fresh location: $e');
    }
    return null;
  }

  Future<void> _sendLocationPayload(Position position, {String? tripIdOverride, bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastUpdateSentAt != null) {
      final elapsedMs = now.difference(_lastUpdateSentAt!).inMilliseconds;
      if (elapsedMs < 3000) {
        // Throttle rapid position stream updates to at most once per 3 seconds
        return;
      }
    }
    _sequence++;
    _lastUpdateSentAt = now;
    final prefs = await SharedPreferences.getInstance();
    final currentTripId = tripIdOverride ?? prefs.getString('active_trip_id');
    print(
      '[DRIVER_LOCATION] lat=${position.latitude} lng=${position.longitude} sentAt=${now.toIso8601String()} socketConnected=${SocketService.to.isConnected}',
    );

    bool socketSuccess = false;
    // Primary transmission path: Socket.IO
    try {
      if (SocketService.to.isConnected) {
        await SocketService.to.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed,
          accuracy: position.accuracy,
          sequence: _sequence,
          tripId: currentTripId,
        );
        socketSuccess = true;
      }
    } catch (err) {
      print('Socket location emission failed: $err');
    }

    // Secondary fallback path: REST API (only if socket is disconnected or emission failed)
    if (!socketSuccess) {
      try {
        final token = await SecureSessionStore.readToken();
        final sessionCookie = await SecureSessionStore.readCookie();

        if (token != null || sessionCookie != null) {
          final endpoint = _isGoodsTrip && currentTripId != null
              ? ApiConstants.updateGoodsLocation(currentTripId)
              : ApiConstants.driverLocation;
          final payload = <String, dynamic>{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
            if (currentTripId != null) 'tripId': currentTripId,
          };
          await Dio().post(
            '${ApiConstants.baseUrl}$endpoint',
            data: payload,
            options: Options(
              headers: {
                if (token != null) 'Authorization': 'Bearer $token',
                if (sessionCookie != null) 'Cookie': sessionCookie,
              },
            ),
          );
          print('[DRIVER_LOCATION] REST fallback sync=success endpoint=$endpoint');
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 429) {
          print('[DRIVER_LOCATION] REST update rate limited (429) - respecting rate limit.');
        } else {
          print('Location REST update failed: $e');
        }
      }
    }
  }

  Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_id');
    if (!_isTracking) return;
    _isTracking = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}
