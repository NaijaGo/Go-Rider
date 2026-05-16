import 'dart:async';

import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/map/mapbox_config.dart';
import '../../../core/socket/socket_service.dart';
import '../../orders/controller/delivery_controller.dart';
import '../../orders/service/rider_api.dart';

class RiderMapController extends GetxController {
  final riderLocation = const LatLng(0, 0).obs;
  final vendorLocation = const LatLng(10.5150, 7.4200).obs;
  final customerLocation = const LatLng(10.5050, 7.4100).obs;
  final routePoints = <LatLng>[].obs;
  final routeInstructions = <RouteInstruction>[].obs;
  final routeDistanceKm = 0.0.obs;
  final routeDurationMinutes = 0.obs;
  final isLoadingRoute = false.obs;
  final hasRiderGpsLocation = false.obs;
  final lastGpsUpdateAt = Rxn<DateTime>();
  final gpsFreshnessTick = 0.obs;
  final isNavigationMode = false.obs;

  final isTracking = false.obs;
  var _loadedMapboxConfig = false;
  var _isRefreshingFromLiveGps = false;
  StreamSubscription<Position>? _trackingSubscription;
  Timer? _gpsFreshnessTimer;
  DateTime? _lastRouteRefreshAt;
  LatLng? _lastRouteRefreshLocation;
  LatLng? _pendingServerLocation;
  String? _activeOrderId;

  @override
  void onInit() {
    super.onInit();
    _syncCurrentGpsLocation(sendToServer: false);
  }

  void syncDelivery(DeliveryController deliveryController) {
    _activeOrderId = deliveryController.activeOrder.value?.id;
    vendorLocation.value = deliveryController.vendorLocation.value;
    customerLocation.value = deliveryController.customerLocation.value;

    if (routePoints.isEmpty) {
      refreshRoute();
    }
  }

  void updateRiderGpsLocation(LatLng current) {
    riderLocation.value = current;
    hasRiderGpsLocation.value = true;
    lastGpsUpdateAt.value = DateTime.now();
    gpsFreshnessTick.value++;
    if (isTracking.value) {
      _refreshRouteFromLiveGps(current);
    }
  }

  Future<void> startTracking() async {
    isTracking.value = true;
    isNavigationMode.value = true;

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      isTracking.value = false;
      return;
    }

    await _syncCurrentGpsLocation(sendToServer: true, forceRouteRefresh: true);
    _trackingSubscription ??=
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'NaijaGo active delivery',
              notificationText:
                  'Navigation is tracking your route to complete this delivery.',
              notificationChannelName: 'NaijaGo Active Delivery',
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        ).listen((position) {
          _handleLiveTrackingPosition(position);
        });
    _gpsFreshnessTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      gpsFreshnessTick.value++;
    });
  }

  void stopTracking() {
    isTracking.value = false;
    isNavigationMode.value = false;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _gpsFreshnessTimer?.cancel();
    _gpsFreshnessTimer = null;
    _lastRouteRefreshAt = null;
    _lastRouteRefreshLocation = null;
  }

  @override
  void onClose() {
    stopTracking();
    super.onClose();
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _syncCurrentGpsLocation({
    required bool sendToServer,
    bool forceRouteRefresh = false,
  }) async {
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      await _handleLiveTrackingPosition(
        position,
        sendToServer: sendToServer,
        forceRouteRefresh: forceRouteRefresh,
      );
    } catch (_) {
      // Keep the last known map position when GPS or network is unavailable.
    }
  }

  Future<void> _handleLiveTrackingPosition(
    Position position, {
    bool sendToServer = true,
    bool forceRouteRefresh = false,
  }) async {
    final current = LatLng(position.latitude, position.longitude);
    riderLocation.value = current;
    hasRiderGpsLocation.value = true;
    lastGpsUpdateAt.value = DateTime.now();
    gpsFreshnessTick.value++;

    if (sendToServer) {
      _sendLocationToServer(current);
      SocketService().emit('rider_location_update', {
        'lat': current.latitude,
        'lng': current.longitude,
        if (_activeOrderId != null) 'orderId': _activeOrderId,
      });
    }

    if (forceRouteRefresh || _shouldRefreshRouteForLocation(current)) {
      await _refreshRouteFromLiveGps(current, force: forceRouteRefresh);
    }
  }

  Future<void> _sendLocationToServer(LatLng current) async {
    final retryLocation = _pendingServerLocation;
    if (retryLocation != null) {
      try {
        await RiderApi.updateLocation(
          lat: retryLocation.latitude,
          lng: retryLocation.longitude,
        );
        _pendingServerLocation = null;
      } catch (_) {
        _pendingServerLocation = current;
        return;
      }
    }

    try {
      await RiderApi.updateLocation(
        lat: current.latitude,
        lng: current.longitude,
      );
      _pendingServerLocation = null;
    } catch (_) {
      _pendingServerLocation = current;
    }
  }

  bool _shouldRefreshRouteForLocation(LatLng current) {
    final lastAt = _lastRouteRefreshAt;
    final lastLocation = _lastRouteRefreshLocation;
    if (lastAt == null || lastLocation == null) return true;

    final movedMeters = const Distance().as(
      LengthUnit.Meter,
      lastLocation,
      current,
    );
    return movedMeters >= 35 ||
        DateTime.now().difference(lastAt) >= const Duration(seconds: 20);
  }

  bool get isGpsStale {
    gpsFreshnessTick.value;
    final last = lastGpsUpdateAt.value;
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(seconds: 45);
  }

  String get gpsStatusText {
    gpsFreshnessTick.value;
    final last = lastGpsUpdateAt.value;
    if (!isTracking.value) return 'GPS waiting';
    if (last == null) return 'GPS connecting';

    final seconds = DateTime.now().difference(last).inSeconds;
    if (seconds < 5) return 'GPS active - updated just now';
    if (seconds < 60) return 'GPS active - updated ${seconds}s ago';

    final minutes = seconds ~/ 60;
    return 'GPS stale - updated ${minutes}m ago';
  }

  RouteInstruction? get nextInstruction {
    if (routeInstructions.isEmpty) return null;
    return routeInstructions.first;
  }

  String get navigationStageLabel {
    if (!Get.isRegistered<DeliveryController>()) return 'Navigate to pickup';

    final delivery = Get.find<DeliveryController>();
    if (delivery.hasPickedUp || delivery.isGoingToCustomer) {
      return 'Navigate to customer';
    }

    return 'Navigate to vendor';
  }

  Future<void> openExternalNavigation() async {
    final destination = _currentDestination;
    final destinationLabel = navigationStageLabel.contains('customer')
        ? 'customer'
        : 'vendor';

    final googleMapsAppUri = Uri.parse(
      'google.navigation:q=${destination.latitude},${destination.longitude}&mode=d',
    );
    final googleMapsWebUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });

    try {
      final launchedApp = await launchUrl(
        googleMapsAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedApp) return;

      final launchedWeb = await launchUrl(
        googleMapsWebUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedWeb) return;
    } catch (_) {
      try {
        final launchedWeb = await launchUrl(
          googleMapsWebUri,
          mode: LaunchMode.externalApplication,
        );
        if (launchedWeb) return;
      } catch (_) {
        // Fall through to the user-facing message below.
      }
    }

    Get.snackbar(
      'Navigation unavailable',
      'Could not open Google Maps to the $destinationLabel location.',
    );
  }

  Future<void> _refreshRouteFromLiveGps(
    LatLng current, {
    bool force = false,
  }) async {
    if (_isRefreshingFromLiveGps) return;
    if (!force && !_shouldRefreshRouteForLocation(current)) return;

    _isRefreshingFromLiveGps = true;
    _lastRouteRefreshAt = DateTime.now();
    _lastRouteRefreshLocation = current;
    try {
      await refreshRoute();
    } finally {
      _isRefreshingFromLiveGps = false;
    }
  }

  Future<void> refreshRoute() async {
    await _loadMapboxConfig();
    if (!hasRiderGpsLocation.value) {
      await _syncCurrentGpsLocation(sendToServer: false);
    }
    if (!hasRiderGpsLocation.value) {
      routePoints.assignAll([vendorLocation.value, customerLocation.value]);
      routeInstructions.clear();
      return;
    }

    if (!MapboxConfig.hasToken) {
      routePoints.assignAll([riderLocation.value, _currentDestination]);
      routeInstructions.clear();
      return;
    }

    isLoadingRoute.value = true;
    try {
      final route = await _fetchRoute(
        origin: riderLocation.value,
        destination: _currentDestination,
      );
      routePoints.assignAll(route.points);
      routeInstructions.assignAll(route.instructions);
      routeDistanceKm.value = route.distanceMeters / 1000;
      routeDurationMinutes.value = (route.durationSeconds / 60).ceil();
    } catch (_) {
      routePoints.assignAll([riderLocation.value, _currentDestination]);
      routeInstructions.clear();
    } finally {
      isLoadingRoute.value = false;
    }
  }

  LatLng get _currentDestination {
    if (!Get.isRegistered<DeliveryController>()) return vendorLocation.value;

    final delivery = Get.find<DeliveryController>();
    if (delivery.hasPickedUp || delivery.isGoingToCustomer) {
      return customerLocation.value;
    }

    return vendorLocation.value;
  }

  Future<_MapboxRoute> _fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final data = await RiderApi.mapboxDirections(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
    );

    final coordinates = asList(data['points']);
    final points = coordinates.map((coordinate) {
      final pair = asList(coordinate);
      return LatLng(
        asDouble(pair.elementAtOrNull(0)),
        asDouble(pair.elementAtOrNull(1)),
      );
    }).toList();
    final steps = asList(data['steps'])
        .map((step) {
          final item = asMap(step);
          return RouteInstruction(
            instruction: item['instruction']?.toString() ?? '',
            roadName: item['roadName']?.toString() ?? '',
            distanceMeters: asDouble(item['distanceMeters']),
            durationSeconds: asDouble(item['durationSeconds']),
            maneuverType: item['maneuverType']?.toString() ?? '',
            modifier: item['modifier']?.toString() ?? '',
          );
        })
        .where((step) => step.instruction.isNotEmpty)
        .toList();

    return _MapboxRoute(
      points: points.isEmpty ? [origin, destination] : points,
      instructions: steps,
      distanceMeters: asDouble(data['distanceMeters']),
      durationSeconds: asDouble(data['durationSeconds']),
    );
  }

  Future<void> _loadMapboxConfig() async {
    if (_loadedMapboxConfig) return;
    _loadedMapboxConfig = true;

    try {
      final data = await RiderApi.mapboxConfig();
      MapboxConfig.applyBackendConfig(data);
    } catch (_) {
      // The map still works with fallback tiles and straight-line routing.
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

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return '${distanceMeters.round()} m';
  }
}

class _MapboxRoute {
  final List<LatLng> points;
  final List<RouteInstruction> instructions;
  final double distanceMeters;
  final double durationSeconds;

  const _MapboxRoute({
    required this.points,
    required this.instructions,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
