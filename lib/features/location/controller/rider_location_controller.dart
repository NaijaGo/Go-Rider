import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/delivery_coordinates.dart';
import '../../../core/map/rider_tracking_settings.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/storage/app_storage.dart';
import '../../map/controller/map_controller.dart';
import '../../orders/service/rider_api.dart';

class RiderLocationController extends GetxController {
  RiderLocationController({
    Future<bool> Function()? permissionChecker,
    Future<Position> Function()? positionReader,
    Stream<Position> Function()? positionStream,
    Future<void> Function(LatLng)? locationPublisher,
    void Function(Map<String, dynamic>)? locationEmitter,
    bool Function()? onlineReader,
  }) : _permissionChecker = permissionChecker ?? _defaultPermission,
       _positionReader = positionReader ?? _defaultPosition,
       _positionStream = positionStream ?? _defaultStream,
       _locationPublisher = locationPublisher ?? _defaultPublish,
       _locationEmitter = locationEmitter ?? _defaultEmit,
       _onlineReader = onlineReader ?? _defaultOnline;

  final Future<bool> Function() _permissionChecker;
  final Future<Position> Function() _positionReader;
  final Stream<Position> Function() _positionStream;
  final Future<void> Function(LatLng) _locationPublisher;
  final void Function(Map<String, dynamic>) _locationEmitter;
  final bool Function() _onlineReader;
  final isTrackingOnlineLocation = false.obs;
  final currentLocation = Rxn<LatLng>();
  final locationError = ''.obs;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastSentAt;
  LatLng? _lastSentPosition;
  LatLng? _pendingPosition;
  bool _sending = false;
  bool _starting = false;
  bool _closed = false;
  int _generation = 0;

  static bool _defaultOnline() => AppStorage.isRiderOnline;
  static Future<bool> _defaultPermission() async =>
      await Geolocator.isLocationServiceEnabled() &&
      await Geolocator.checkPermission() == LocationPermission.always;
  static Future<Position> _defaultPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  static Stream<Position> _defaultStream() => Geolocator.getPositionStream(
    locationSettings: riderTrackingSettings(activeDelivery: false),
  );
  static Future<void> _defaultPublish(LatLng point) async {
    await RiderApi.updateLocation(lat: point.latitude, lng: point.longitude);
  }

  static void _defaultEmit(Map<String, dynamic> payload) =>
      SocketService().emit('rider_location_update', payload);

  @override
  void onInit() {
    super.onInit();
    if (_onlineReader()) unawaited(startOnlineLocationUpdates());
  }

  @override
  void onClose() {
    _closed = true;
    stopOnlineLocationUpdates();
    super.onClose();
  }

  Future<void> syncWithOnlineStatus(bool online) async {
    if (online) {
      await startOnlineLocationUpdates();
    } else {
      stopOnlineLocationUpdates();
    }
  }

  Future<void> startOnlineLocationUpdates() async {
    if (_closed ||
        _starting ||
        isTrackingOnlineLocation.value ||
        !_onlineReader()) {
      return;
    }
    _starting = true;
    final generation = ++_generation;
    try {
      final allowed = await _permissionChecker();
      if (_closed || generation != _generation || !_onlineReader()) return;
      if (!allowed) {
        locationError.value =
            'Enable GPS and background location access to share your online rider position.';
        return;
      }
      isTrackingOnlineLocation.value = true;
      locationError.value = '';
      _positionSubscription = _positionStream().listen(
        (position) {
          if (_closed ||
              generation != _generation ||
              !isTrackingOnlineLocation.value ||
              !_onlineReader()) {
            return;
          }
          final point = _applyLocalPosition(position);
          if (point != null) unawaited(_sendPosition(point));
        },
        onError: (Object error) {
          if (_closed || generation != _generation) return;
          stopOnlineLocationUpdates();
          locationError.value =
              'Live location disconnected. Check GPS and retry tracking.';
        },
        onDone: () {
          if (_closed || generation != _generation) return;
          stopOnlineLocationUpdates();
          locationError.value =
              'Live location stopped. Retry tracking when you are ready.';
        },
      );
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(_sendCurrentLocation());
      });
      await _sendCurrentLocation();
    } catch (_) {
      if (!_closed && generation == _generation) {
        stopOnlineLocationUpdates();
        locationError.value =
            'Unable to start live location. Check location settings and try again.';
      }
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  Future<LatLng?> refreshCurrentLocation({
    bool sendToServerWhenOnline = true,
  }) async {
    final generation = _generation;
    try {
      if (_closed || !await _permissionChecker()) return null;
      final position = await _positionReader();
      if (_closed || generation != _generation) return null;
      final point = _applyLocalPosition(position);
      if (point != null &&
          sendToServerWhenOnline &&
          _onlineReader() &&
          isTrackingOnlineLocation.value) {
        await _sendPosition(point, force: true);
      }
      return point;
    } catch (_) {
      if (!_closed) {
        locationError.value =
            'No fresh GPS fix. Enable location services and try again.';
      }
      // A previous fix cannot authorize going online with a stale position.
      return null;
    }
  }

  void stopOnlineLocationUpdates() {
    _generation++;
    _starting = false;
    isTrackingOnlineLocation.value = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastSentAt = null;
    _lastSentPosition = null;
    _pendingPosition = null;
  }

  Future<void> _sendCurrentLocation() async {
    final generation = _generation;
    if (_closed || !_onlineReader() || !isTrackingOnlineLocation.value) return;
    try {
      final position = await _positionReader();
      if (_closed ||
          generation != _generation ||
          !_onlineReader() ||
          !isTrackingOnlineLocation.value) {
        return;
      }
      final point = _applyLocalPosition(position);
      if (point != null) await _sendPosition(point, force: true);
    } catch (_) {
      if (!_closed && generation == _generation) {
        locationError.value = 'Waiting for a fresh GPS fix.';
        final pending = _pendingPosition;
        if (pending != null) await _sendPosition(pending, force: true);
      }
    }
  }

  Future<void> _sendPosition(LatLng point, {bool force = false}) async {
    if (_closed || !_onlineReader() || !isTrackingOnlineLocation.value) return;
    final moved =
        _lastSentPosition == null ||
        const Distance().as(LengthUnit.Meter, _lastSentPosition!, point) >= 20;
    final old =
        _lastSentAt == null ||
        DateTime.now().difference(_lastSentAt!) >= const Duration(seconds: 25);
    if (!force && !_sending && !moved && !old) return;
    _pendingPosition = point;
    if (_sending) return;
    _sending = true;
    final generation = _generation;
    try {
      while (!_closed &&
          generation == _generation &&
          _onlineReader() &&
          isTrackingOnlineLocation.value &&
          _pendingPosition != null) {
        final pending = _pendingPosition!;
        _pendingPosition = null;
        try {
          await _locationPublisher(pending);
          if (_closed || generation != _generation || !_onlineReader()) return;
          _lastSentPosition = pending;
          _lastSentAt = DateTime.now();
          try {
            _locationEmitter({
              'lat': pending.latitude,
              'lng': pending.longitude,
            });
          } catch (_) {
            // HTTP updates still work during socket reconnection.
          }
        } catch (_) {
          if (!_closed && generation == _generation) {
            _pendingPosition ??= pending;
            locationError.value =
                'Location sharing is reconnecting. Your latest position will be retried.';
          }
          break;
        }
      }
    } finally {
      _sending = false;
      if (generation != _generation &&
          !_closed &&
          isTrackingOnlineLocation.value &&
          _onlineReader() &&
          _pendingPosition != null) {
        unawaited(_sendPosition(_pendingPosition!, force: true));
      }
    }
  }

  LatLng? _applyLocalPosition(Position position) {
    final point = readDeliveryCoordinate({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    if (!validDeliveryCoordinate(point)) {
      locationError.value =
          'GPS returned an invalid position. Waiting for a fresh fix.';
      return null;
    }
    currentLocation.value = point;
    locationError.value = '';
    if (Get.isRegistered<RiderMapController>()) {
      Get.find<RiderMapController>().updateRiderGpsLocation(point);
    }
    return point;
  }
}
