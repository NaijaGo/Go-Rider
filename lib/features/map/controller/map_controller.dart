import 'dart:async';

import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/map/delivery_coordinates.dart';
import '../../../core/map/mapbox_config.dart';
import '../../../core/map/rider_tracking_settings.dart';
import '../../../core/socket/socket_service.dart';
import '../../orders/controller/delivery_controller.dart';
import '../../orders/service/rider_api.dart';

typedef DirectionsLoader =
    Future<Map<String, dynamic>> Function(LatLng, LatLng);

class RiderMapController extends GetxController {
  RiderMapController({
    DirectionsLoader? directionsLoader,
    Future<Map<String, dynamic>> Function()? configLoader,
    Future<bool> Function()? permissionChecker,
    Future<Position> Function()? positionReader,
    Stream<Position> Function()? positionStream,
    Future<void> Function(LatLng)? locationPublisher,
    void Function(Map<String, dynamic>)? locationEmitter,
    Future<bool> Function(Uri)? navigationLauncher,
  }) : _directionsLoader = directionsLoader ?? _defaultDirections,
       _configLoader = configLoader ?? RiderApi.mapboxConfig,
       _permissionChecker = permissionChecker ?? _defaultPermission,
       _positionReader = positionReader ?? _defaultPosition,
       _positionStream = positionStream ?? _defaultStream,
       _locationPublisher = locationPublisher ?? _defaultPublish,
       _locationEmitter = locationEmitter ?? _defaultEmit,
       _navigationLauncher = navigationLauncher ?? _defaultLaunch;

  final DirectionsLoader _directionsLoader;
  final Future<Map<String, dynamic>> Function() _configLoader;
  final Future<bool> Function() _permissionChecker;
  final Future<Position> Function() _positionReader;
  final Stream<Position> Function() _positionStream;
  final Future<void> Function(LatLng) _locationPublisher;
  final void Function(Map<String, dynamic>) _locationEmitter;
  final Future<bool> Function(Uri) _navigationLauncher;

  final riderLocation = const LatLng(0, 0).obs;
  final vendorLocation = const LatLng(0, 0).obs;
  final customerLocation = const LatLng(0, 0).obs;
  final routePoints = <LatLng>[].obs;
  final routeInstructions = <RouteInstruction>[].obs;
  final routeDistanceKm = 0.0.obs;
  final routeDurationMinutes = 0.obs;
  final isLoadingRoute = false.obs;
  final hasRoadRoute = false.obs;
  final routeStatus = 'Open an active delivery to see its route.'.obs;
  final gpsError = ''.obs;
  final hasRiderGpsLocation = false.obs;
  final lastGpsUpdateAt = Rxn<DateTime>();
  final gpsFreshnessTick = 0.obs;
  final isNavigationMode = false.obs;
  final isTracking = false.obs;
  final isStartingNavigation = false.obs;

  bool _loadedMapboxConfig = false;
  bool _isRefreshingFromLiveGps = false;
  bool _sendingLocation = false;
  bool _disposed = false;
  int _routeVersion = 0;
  int _trackingVersion = 0;
  String _deliveryKey = '';
  String? _activeOrderId;
  StreamSubscription<Position>? _trackingSubscription;
  Timer? _gpsFreshnessTimer;
  DateTime? _lastRouteRefreshAt;
  LatLng? _lastRouteRefreshLocation;
  LatLng? _pendingServerLocation;

  static Future<Map<String, dynamic>> _defaultDirections(LatLng a, LatLng b) =>
      RiderApi.mapboxDirections(
        originLat: a.latitude,
        originLng: a.longitude,
        destinationLat: b.latitude,
        destinationLng: b.longitude,
      );
  static Future<void> _defaultPublish(LatLng point) async {
    await RiderApi.updateLocation(lat: point.latitude, lng: point.longitude);
  }

  static void _defaultEmit(Map<String, dynamic> payload) =>
      SocketService().emit('rider_location_update', payload);
  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  static Future<bool> _defaultPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position> _defaultPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      timeLimit: Duration(seconds: 15),
    ),
  );
  static Stream<Position> _defaultStream() => Geolocator.getPositionStream(
    locationSettings: riderTrackingSettings(activeDelivery: true),
  );

  void syncDelivery(DeliveryController delivery) {
    final id = delivery.activeOrder.value?.id;
    final key =
        '$id:${delivery.currentPickupIndex.value}:${delivery.hasPickedUp}:'
        '${delivery.vendorLocation.value}:${delivery.customerLocation.value}';
    if (_deliveryKey == key) return;
    _deliveryKey = key;
    _activeOrderId = id;
    vendorLocation.value = delivery.vendorLocation.value;
    customerLocation.value = delivery.customerLocation.value;
    _routeVersion++;
    _resetRoute();
    if (id == null) {
      stopTracking();
      routeStatus.value = 'No active delivery.';
    } else {
      unawaited(refreshRoute());
    }
  }

  LatLng get currentDestination {
    if (Get.isRegistered<DeliveryController>() &&
        Get.find<DeliveryController>().hasPickedUp) {
      return customerLocation.value;
    }
    return vendorLocation.value;
  }

  bool get hasDestination =>
      _activeOrderId?.isNotEmpty == true &&
      validDeliveryCoordinate(currentDestination);
  String get navigationStageLabel =>
      Get.isRegistered<DeliveryController>() &&
          Get.find<DeliveryController>().hasPickedUp
      ? 'Navigate to customer'
      : 'Navigate to vendor';

  void updateRiderGpsLocation(LatLng current, {bool refreshRoadRoute = true}) {
    if (_disposed || !validDeliveryCoordinate(current)) return;
    riderLocation.value = current;
    hasRiderGpsLocation.value = true;
    lastGpsUpdateAt.value = DateTime.now();
    gpsFreshnessTick.value++;
    gpsError.value = '';
    if (Get.isRegistered<DeliveryController>()) {
      Get.find<DeliveryController>().riderLocation.value = current;
    }
    if (isTracking.value && refreshRoadRoute) {
      unawaited(_refreshRouteFromLiveGps(current));
    }
  }

  Future<bool> startTracking() async {
    if (_disposed || isStartingNavigation.value) return false;
    if (isTracking.value) return true;
    if (!hasDestination) {
      routeStatus.value =
          'The delivery location is missing. Confirm the address before navigating.';
      return false;
    }
    final version = ++_trackingVersion;
    isStartingNavigation.value = true;
    try {
      if (!await _permissionChecker()) {
        gpsError.value =
            'Enable location services and allow location access to track this delivery.';
        return false;
      }
      if (_disposed || version != _trackingVersion) return false;
      isTracking.value = true;
      isNavigationMode.value = true;
      _trackingSubscription = _positionStream().listen(
        (position) {
          if (!_disposed && version == _trackingVersion && isTracking.value) {
            _applyTrackingPosition(position);
          }
        },
        onDone: () {
          if (_disposed || version != _trackingVersion) return;
          stopTracking();
          gpsError.value = 'Live GPS stopped. Restart navigation to reconnect.';
        },
        onError: (Object error) {
          if (_disposed || version != _trackingVersion) return;
          stopTracking();
          gpsError.value =
              'Live GPS is unavailable. Check location access and try again.';
        },
      );
      _gpsFreshnessTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => gpsFreshnessTick.value++,
      );
      try {
        final position = await _positionReader();
        if (!_disposed && version == _trackingVersion && isTracking.value) {
          _applyTrackingPosition(position);
        }
      } catch (_) {
        if (!_disposed && version == _trackingVersion) {
          gpsError.value = 'Waiting for a live GPS fix.';
        }
      }
      return !_disposed && version == _trackingVersion && isTracking.value;
    } catch (_) {
      if (!_disposed && version == _trackingVersion) {
        stopTracking();
        gpsError.value =
            'Unable to start GPS. Check location services and try again.';
      }
      return false;
    } finally {
      if (!_disposed) isStartingNavigation.value = false;
    }
  }

  void _applyTrackingPosition(Position position) {
    final current = readDeliveryCoordinate({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    if (!validDeliveryCoordinate(current)) return;
    updateRiderGpsLocation(current);
    unawaited(_sendLocationToServer(current));
    try {
      _locationEmitter({
        'lat': current.latitude,
        'lng': current.longitude,
        if (_activeOrderId != null) 'orderId': _activeOrderId,
      });
    } catch (_) {
      // HTTP location updates continue when the socket is reconnecting.
    }
  }

  Future<void> _sendLocationToServer(LatLng current) async {
    _pendingServerLocation = current;
    if (_sendingLocation) return;
    _sendingLocation = true;
    try {
      while (!_disposed && isTracking.value && _pendingServerLocation != null) {
        final pending = _pendingServerLocation!;
        _pendingServerLocation = null;
        try {
          await _locationPublisher(pending);
        } catch (_) {
          _pendingServerLocation ??= pending;
          break;
        }
      }
    } finally {
      _sendingLocation = false;
    }
  }

  void stopTracking() {
    _trackingVersion++;
    isTracking.value = false;
    isNavigationMode.value = false;
    isStartingNavigation.value = false;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _gpsFreshnessTimer?.cancel();
    _gpsFreshnessTimer = null;
    _pendingServerLocation = null;
    _lastRouteRefreshAt = null;
    _lastRouteRefreshLocation = null;
  }

  @override
  void onClose() {
    _disposed = true;
    _routeVersion++;
    stopTracking();
    super.onClose();
  }

  bool get isGpsStale {
    gpsFreshnessTick.value;
    final last = lastGpsUpdateAt.value;
    return last == null ||
        DateTime.now().difference(last) > const Duration(seconds: 45);
  }

  String get gpsStatusText {
    gpsFreshnessTick.value;
    if (gpsError.value.isNotEmpty) return gpsError.value;
    final last = lastGpsUpdateAt.value;
    if (last == null) {
      return isTracking.value ? 'GPS connecting' : 'GPS waiting';
    }
    final seconds = DateTime.now().difference(last).inSeconds;
    if (isGpsStale) return 'GPS stale - updated ${seconds}s ago';
    return seconds < 5 ? 'GPS updated just now' : 'GPS updated ${seconds}s ago';
  }

  RouteInstruction? get nextInstruction =>
      routeInstructions.isEmpty ? null : routeInstructions.first;

  Future<bool> openExternalNavigation() async {
    if (!hasDestination) {
      routeStatus.value =
          'Navigation needs a valid delivery location. Confirm the address first.';
      return false;
    }
    final destination = currentDestination;
    final app = Uri.parse(
      'google.navigation:q=${destination.latitude},${destination.longitude}&mode=d',
    );
    final web = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });
    for (final uri in [app, web]) {
      try {
        if (await _navigationLauncher(uri)) return true;
      } catch (_) {
        /* Try browser navigation next. */
      }
    }
    routeStatus.value = 'Could not open Google Maps. Please try again.';
    return false;
  }

  bool _shouldRefreshRouteForLocation(LatLng current) {
    if (_lastRouteRefreshAt == null || _lastRouteRefreshLocation == null) {
      return true;
    }
    return const Distance().as(
              LengthUnit.Meter,
              _lastRouteRefreshLocation!,
              current,
            ) >=
            35 ||
        DateTime.now().difference(_lastRouteRefreshAt!) >=
            const Duration(seconds: 20);
  }

  Future<void> _refreshRouteFromLiveGps(LatLng current) async {
    if (_isRefreshingFromLiveGps || !_shouldRefreshRouteForLocation(current)) {
      return;
    }
    _isRefreshingFromLiveGps = true;
    _lastRouteRefreshAt = DateTime.now();
    _lastRouteRefreshLocation = current;
    try {
      await refreshRoute();
    } finally {
      _isRefreshingFromLiveGps = false;
    }
  }

  void _resetRoute() {
    routePoints.clear();
    routeInstructions.clear();
    routeDistanceKm.value = 0;
    routeDurationMinutes.value = 0;
    hasRoadRoute.value = false;
    isLoadingRoute.value = false;
  }

  Future<void> refreshRoute() async {
    if (_disposed) return;
    final version = ++_routeVersion;
    final destination = currentDestination;
    if (!hasDestination) {
      _resetRoute();
      routeStatus.value = _activeOrderId == null
          ? 'No active delivery.'
          : 'The destination has no valid map pin. Confirm the address with the shop or customer.';
      return;
    }
    isLoadingRoute.value = true;
    routeStatus.value = 'Finding your road route...';
    try {
      if (!_loadedMapboxConfig) {
        try {
          final config = await _configLoader();
          if (_disposed || version != _routeVersion) return;
          MapboxConfig.applyBackendConfig(config);
          _loadedMapboxConfig = true;
        } catch (_) {
          /* Road routing is independent of the public tile token. */
        }
      }
      if (!hasRiderGpsLocation.value || isGpsStale) {
        try {
          if (await _permissionChecker()) {
            final position = await _positionReader();
            if (_disposed || version != _routeVersion) return;
            updateRiderGpsLocation(
              readDeliveryCoordinate({
                'latitude': position.latitude,
                'longitude': position.longitude,
              }),
              refreshRoadRoute: false,
            );
          }
        } catch (_) {
          /* Show the GPS waiting state below. */
        }
      }
      if (_disposed || version != _routeVersion) return;
      if (!hasRiderGpsLocation.value || isGpsStale) {
        _resetRoute();
        routeStatus.value =
            'Waiting for fresh GPS. The pickup and drop-off pins are still available.';
        return;
      }
      final data = await _directionsLoader(riderLocation.value, destination);
      if (_disposed || version != _routeVersion) return;
      final coordinates = asList(data['points']);
      final points = coordinates.map((value) {
        final pair = asList(value);
        if (pair.length < 2) throw const FormatException('Invalid route point');
        final point = readDeliveryCoordinate({
          'latitude': pair[0],
          'longitude': pair[1],
        });
        if (!validDeliveryCoordinate(point)) {
          throw const FormatException('Invalid route point');
        }
        return point;
      }).toList();
      final meters = double.tryParse('${data['distanceMeters']}');
      final seconds = double.tryParse('${data['durationSeconds']}');
      if (data['success'] == false ||
          points.length < 2 ||
          meters == null ||
          seconds == null ||
          !meters.isFinite ||
          !seconds.isFinite ||
          meters < 0 ||
          seconds < 0) {
        throw const FormatException('Invalid road route');
      }
      routePoints.assignAll(points);
      routeInstructions.assignAll(
        asList(data['steps'])
            .map((value) {
              final step = asMap(value);
              final stepDistance = asDouble(step['distanceMeters'], double.nan);
              final stepDuration = asDouble(
                step['durationSeconds'],
                double.nan,
              );
              if (!stepDistance.isFinite ||
                  !stepDuration.isFinite ||
                  stepDistance < 0 ||
                  stepDuration < 0) {
                return null;
              }
              return RouteInstruction(
                instruction: asString(step['instruction']),
                roadName: asString(step['roadName']),
                distanceMeters: stepDistance,
                durationSeconds: stepDuration,
                maneuverType: asString(step['maneuverType']),
                modifier: asString(step['modifier']),
              );
            })
            .whereType<RouteInstruction>()
            .where((step) => step.instruction.isNotEmpty),
      );
      routeDistanceKm.value = meters / 1000;
      routeDurationMinutes.value = (seconds / 60).ceil();
      hasRoadRoute.value = true;
      routeStatus.value = 'Road route ready';
    } catch (_) {
      if (!_disposed && version == _routeVersion) {
        _resetRoute();
        routeStatus.value =
            'Road routing is unavailable. You can still open Google Maps for directions.';
      }
    } finally {
      if (!_disposed && version == _routeVersion) isLoadingRoute.value = false;
    }
  }
}

class RouteInstruction {
  final String instruction;
  final String roadName;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String modifier;
  const RouteInstruction({
    required this.instruction,
    required this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.modifier,
  });
  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';
}
