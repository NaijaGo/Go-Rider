import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/socket/socket_service.dart';
import '../../../core/storage/app_storage.dart';
import '../../map/controller/map_controller.dart';
import '../../orders/service/rider_api.dart';

class RiderLocationController extends GetxController {
  final isTrackingOnlineLocation = false.obs;
  final currentLocation = Rxn<LatLng>();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastSentAt;
  Position? _lastPosition;
  Position? _pendingServerPosition;
  bool _sending = false;

  @override
  void onInit() {
    super.onInit();
    if (AppStorage.isRiderOnline) {
      startOnlineLocationUpdates();
    }
  }

  @override
  void onClose() {
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
    if (isTrackingOnlineLocation.value) return;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    isTrackingOnlineLocation.value = true;
    await _sendCurrentLocation();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            intervalDuration: const Duration(seconds: 15),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'NaijaGo delivery tracking',
              notificationText:
                  'Your rider location is active while you are online.',
              notificationChannelName: 'NaijaGo Rider Location',
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        ).listen((position) {
          _sendPosition(position);
        });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _retryPendingLocation();
      _sendCurrentLocation();
    });
  }

  Future<LatLng?> refreshCurrentLocation({
    bool sendToServerWhenOnline = true,
  }) async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return currentLocation.value;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _applyLocalPosition(position);
      if (sendToServerWhenOnline && AppStorage.isRiderOnline) {
        await _sendPosition(position, force: true);
      }
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return currentLocation.value;
    }
  }

  void stopOnlineLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    isTrackingOnlineLocation.value = false;
    _lastSentAt = null;
    _lastPosition = null;
    _pendingServerPosition = null;
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _sendCurrentLocation() async {
    if (!AppStorage.isRiderOnline || _sending) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _applyLocalPosition(position);
      await _sendPosition(position, force: true);
    } catch (_) {
      // Keep the previous known position until GPS becomes available again.
    }
  }

  Future<void> _sendPosition(Position position, {bool force = false}) async {
    if (!AppStorage.isRiderOnline || _sending) return;

    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    final lastPosition = _lastPosition;
    final movedEnough =
        lastPosition == null ||
        Geolocator.distanceBetween(
              lastPosition.latitude,
              lastPosition.longitude,
              position.latitude,
              position.longitude,
            ) >=
            20;
    final oldEnough =
        lastSentAt == null || now.difference(lastSentAt).inSeconds >= 25;

    if (!force && !movedEnough && !oldEnough) return;

    _sending = true;
    try {
      await _sendPendingThenCurrent(position);
      SocketService().emit('rider_location_update', {
        'lat': position.latitude,
        'lng': position.longitude,
      });
      _applyLocalPosition(position);
      _lastPosition = position;
      _lastSentAt = now;
    } catch (_) {
      _pendingServerPosition = position;
    } finally {
      _sending = false;
    }
  }

  Future<void> _retryPendingLocation() async {
    final pending = _pendingServerPosition;
    if (pending == null || _sending || !AppStorage.isRiderOnline) return;

    _sending = true;
    try {
      await RiderApi.updateLocation(
        lat: pending.latitude,
        lng: pending.longitude,
      );
      _pendingServerPosition = null;
    } catch (_) {
      // Keep the pending position for the next heartbeat.
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendPendingThenCurrent(Position position) async {
    final pending = _pendingServerPosition;
    if (pending != null) {
      await RiderApi.updateLocation(
        lat: pending.latitude,
        lng: pending.longitude,
      );
      _pendingServerPosition = null;
    }

    await RiderApi.updateLocation(
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  void _applyLocalPosition(Position position) {
    final location = LatLng(position.latitude, position.longitude);
    currentLocation.value = location;
    if (Get.isRegistered<RiderMapController>()) {
      Get.find<RiderMapController>().updateRiderGpsLocation(location);
    }
  }
}
