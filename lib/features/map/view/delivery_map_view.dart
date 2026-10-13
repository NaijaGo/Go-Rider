import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/delivery_coordinates.dart';
import '../../../core/map/mapbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../orders/controller/delivery_controller.dart';
import '../controller/map_controller.dart';

class DeliveryMapView extends StatefulWidget {
  const DeliveryMapView({super.key, this.tileProvider});
  final TileProvider? tileProvider;
  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  final _map = MapController();
  late final RiderMapController controller;
  late final DeliveryController delivery;
  bool _fallbackTiles = false;
  bool _tilesUnavailable = false;
  bool _manualCamera = false;
  String _lastFitKey = '';

  @override
  void initState() {
    super.initState();
    controller = Get.find<RiderMapController>();
    delivery = Get.find<DeliveryController>();
    controller.syncDelivery(delivery);
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  List<LatLng> get _visiblePoints => [
    if (controller.hasRiderGpsLocation.value) controller.riderLocation.value,
    ...delivery.pickupStops.map((stop) => stop.location),
    if (delivery.pickupStops.isEmpty) controller.vendorLocation.value,
    controller.customerLocation.value,
    ...controller.routePoints,
  ].where(validDeliveryCoordinate).toList();

  void _fit({bool force = false}) {
    final points = _visiblePoints;
    if (points.isEmpty) return;
    final key =
        '${delivery.activeOrder.value?.id}:${delivery.currentPickupIndex.value}:'
        '${delivery.hasPickedUp}:${controller.hasRoadRoute.value}:${points.first}:${points.last}';
    if (!force && (_manualCamera || key == _lastFitKey)) return;
    _lastFitKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (controller.isNavigationMode.value &&
            !_manualCamera &&
            controller.hasRiderGpsLocation.value) {
          _map.move(controller.riderLocation.value, 16);
        } else if (points.every((point) => point == points.first)) {
          _map.move(points.first, 15);
        } else {
          _map.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.fromLTRB(52, 64, 52, 64),
              maxZoom: 16,
            ),
          );
        }
      } catch (_) {
        /* Camera is not attached yet. onMapReady retries. */
      }
    });
  }

  void _centreRider() {
    if (!controller.hasRiderGpsLocation.value) return;
    _manualCamera = false;
    try {
      _map.move(controller.riderLocation.value, 16);
    } catch (_) {
      // The map may still be attaching when GPS arrives.
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final order = delivery.activeOrder.value;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery route')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 52,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No active delivery',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accept a delivery to see its pickup and drop-off locations.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Back to deliveries'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final useMapbox = MapboxConfig.hasToken && !_fallbackTiles;
    final points = _visiblePoints;
    _fit();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery route',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              order.orderCode,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh road route',
            onPressed: controller.isLoadingRoute.value
                ? null
                : controller.refreshRoute,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: points.isEmpty
                          ? const LatLng(9.082, 8.6753)
                          : points.first,
                      initialZoom: points.isEmpty ? 5 : 14,
                      onMapReady: () => _fit(force: true),
                      onPositionChanged: (_, hasGesture) {
                        if (hasGesture) _manualCamera = true;
                      },
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey(useMapbox ? 'mapbox' : 'osm'),
                        tileProvider: widget.tileProvider,
                        urlTemplate: useMapbox
                            ? MapboxConfig.tileUrl
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        tileDimension: useMapbox ? 512 : 256,
                        maxNativeZoom: useMapbox ? 22 : 19,
                        zoomOffset: useMapbox ? -1 : 0,
                        userAgentPackageName: 'com.naijago.rider',
                        errorTileCallback: (_, __, ___) {
                          if (!mounted) return;
                          if (useMapbox && !_fallbackTiles) {
                            setState(() => _fallbackTiles = true);
                          } else if (!_tilesUnavailable) {
                            setState(() => _tilesUnavailable = true);
                          }
                        },
                      ),
                      if (controller.hasRoadRoute.value)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: controller.routePoints.toList(),
                              strokeWidth: 5,
                              color: controller.isGpsStale
                                  ? AppTheme.textMuted
                                  : AppTheme.primary,
                              borderStrokeWidth: 2,
                              borderColor: Colors.white,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (controller.hasRiderGpsLocation.value &&
                              validDeliveryCoordinate(
                                controller.riderLocation.value,
                              ))
                            _marker(
                              controller.riderLocation.value,
                              'You',
                              Icons.delivery_dining_rounded,
                              AppTheme.deepBlue,
                              'map-rider',
                            ),
                          if (delivery.pickupStops.isEmpty &&
                              validDeliveryCoordinate(
                                controller.vendorLocation.value,
                              ))
                            _marker(
                              controller.vendorLocation.value,
                              delivery.vendorName,
                              Icons.storefront_outlined,
                              AppTheme.pickup,
                              'map-pickup-0',
                            ),
                          ...delivery.pickupStops
                              .asMap()
                              .entries
                              .where(
                                (e) =>
                                    validDeliveryCoordinate(e.value.location),
                              )
                              .map(
                                (e) => _marker(
                                  e.value.location,
                                  'Pickup ${e.key + 1}',
                                  e.key < delivery.currentPickupIndex.value
                                      ? Icons.check
                                      : Icons.storefront_outlined,
                                  e.key < delivery.currentPickupIndex.value
                                      ? AppTheme.textMuted
                                      : AppTheme.pickup,
                                  'map-pickup-${e.key}',
                                ),
                              ),
                          if (validDeliveryCoordinate(
                            controller.customerLocation.value,
                          ))
                            _marker(
                              controller.customerLocation.value,
                              'Customer',
                              Icons.location_on_outlined,
                              AppTheme.primary,
                              'map-drop-off',
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 68,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        controller.navigationStageLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _mapButton(
                          'Centre on rider',
                          Icons.my_location,
                          _centreRider,
                          enabled: controller.hasRiderGpsLocation.value,
                        ),
                        const SizedBox(height: 8),
                        _mapButton('Show all stops', Icons.zoom_out_map, () {
                          _manualCamera = true;
                          _fit(force: true);
                        }),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _legend('Pickup', AppTheme.pickup),
                        _legend('Customer', AppTheme.primary),
                        Text(
                          useMapbox
                              ? '© Mapbox © OpenStreetMap'
                              : '© OpenStreetMap',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textDark,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (controller.isLoadingRoute.value)
                              const LinearProgressIndicator(minHeight: 2),
                            Text(
                              controller.hasRoadRoute.value &&
                                      !controller.isGpsStale
                                  ? '${controller.routeDistanceKm.value.toStringAsFixed(1)} km · ${controller.routeDurationMinutes.value} min'
                                  : 'Your delivery stops',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _tilesUnavailable
                                  ? 'Map images are unavailable. Google Maps directions are still available.'
                                  : controller.hasRoadRoute.value &&
                                        controller.isGpsStale
                                  ? 'Waiting for fresh GPS. The last road route is shown.'
                                  : controller.routeStatus.value,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _stopRow(
                              'Pickup${delivery.pickupStops.length > 1 ? ' ${delivery.currentPickupIndex.value + 1} of ${delivery.pickupStops.length}' : ''}',
                              delivery.vendorName,
                              delivery.vendorAddress.value,
                              AppTheme.pickup,
                              Icons.storefront_outlined,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 19),
                              child: Container(
                                width: 2,
                                height: 14,
                                color: AppTheme.border,
                              ),
                            ),
                            _stopRow(
                              'Drop-off',
                              delivery.customerName,
                              delivery.customerAddress.value,
                              AppTheme.primary,
                              Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 12),
                            if (controller.nextInstruction != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.softBlue,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.navigation_outlined,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${controller.nextInstruction!.instruction}\n${controller.nextInstruction!.distanceLabel}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (controller.routeInstructions.isNotEmpty)
                              Material(
                                color: Colors.transparent,
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Route directions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  children: controller.routeInstructions
                                      .take(5)
                                      .map(
                                        (step) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            _turnIcon(step),
                                            color: AppTheme.primary,
                                          ),
                                          title: Text(
                                            step.instruction,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          subtitle: Text(step.distanceLabel),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            Row(
                              children: [
                                Icon(
                                  controller.isGpsStale
                                      ? Icons.gps_not_fixed
                                      : Icons.gps_fixed,
                                  size: 16,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    controller.gpsStatusText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('start-rider-navigation'),
                              onPressed:
                                  !controller.hasDestination ||
                                      controller.isStartingNavigation.value
                                  ? null
                                  : () async {
                                      await controller.startTracking();
                                      await controller.openExternalNavigation();
                                    },
                              icon: const Icon(
                                Icons.navigation_outlined,
                                size: 20,
                              ),
                              label: Text(
                                controller.isStartingNavigation.value
                                    ? 'Starting...'
                                    : 'Open Google Maps',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (controller.isTracking.value) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Stop map tracking',
                              onPressed: controller.stopTracking,
                              icon: const Icon(Icons.stop_circle_outlined),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });

  IconData _turnIcon(RouteInstruction step) {
    if (step.maneuverType == 'arrive') return Icons.flag_outlined;
    if (step.maneuverType.contains('roundabout')) {
      return Icons.roundabout_right_outlined;
    }
    if (step.modifier == 'uturn') return Icons.u_turn_left_outlined;
    if (step.modifier.contains('left')) return Icons.turn_left_outlined;
    if (step.modifier.contains('right')) return Icons.turn_right_outlined;
    return Icons.straight_outlined;
  }

  Marker _marker(
    LatLng point,
    String label,
    IconData icon,
    Color color,
    String key,
  ) => Marker(
    point: point,
    width: 110,
    height: 70,
    child: Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Column(
          key: ValueKey(key),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _mapButton(
    String label,
    IconData icon,
    VoidCallback action, {
    bool enabled = true,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: IconButton(
      tooltip: label,
      onPressed: enabled ? action : null,
      icon: Icon(icon, color: enabled ? AppTheme.primary : AppTheme.textMuted),
    ),
  );
  Widget _legend(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textDark),
        ),
      ],
    ),
  );
  Widget _stopRow(
    String label,
    String name,
    String address,
    Color color,
    IconData icon,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              name,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              address,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
