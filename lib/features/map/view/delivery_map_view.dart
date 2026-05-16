import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/mapbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../orders/controller/delivery_controller.dart';
import '../controller/map_controller.dart';

class DeliveryMapView extends StatefulWidget {
  const DeliveryMapView({super.key});

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  final _mapController = MapController();
  var _useFallbackTiles = false;
  var _lastFitKey = '';
  var _lastFollowKey = '';

  void _fitRoute(BuildContext context, List<LatLng> routePoints) {
    if (routePoints.length < 2) return;

    final first = routePoints.first;
    final last = routePoints.last;
    final fitKey =
        '${routePoints.length}:${first.latitude},${first.longitude}:${last.latitude},${last.longitude}';
    if (_lastFitKey == fitKey) return;
    _lastFitKey = fitKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final bottomPadding = (MediaQuery.sizeOf(context).height * 0.45).clamp(
        240.0,
        360.0,
      );
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(routePoints),
            padding: EdgeInsets.fromLTRB(52, 120, 52, bottomPadding),
            maxZoom: 16,
          ),
        );
      } catch (_) {
        // The controller can be briefly unavailable while the map is mounting.
      }
    });
  }

  void _followRider(LatLng rider, bool active) {
    if (!active) return;

    final followKey =
        '${rider.latitude.toStringAsFixed(5)},${rider.longitude.toStringAsFixed(5)}';
    if (_lastFollowKey == followKey) return;
    _lastFollowKey = followKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(rider, 17);
      } catch (_) {
        // The map can be mounting while GPS starts.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RiderMapController>();
    final deliveryController = Get.find<DeliveryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.syncDelivery(deliveryController);
    });

    return Scaffold(
      body: Obx(() {
        final rider = controller.riderLocation.value;
        final vendor = controller.vendorLocation.value;
        final customer = controller.customerLocation.value;
        final routePoints = controller.routePoints.isEmpty
            ? [rider, vendor, customer]
            : controller.routePoints.toList();
        final useMapboxTiles = MapboxConfig.hasToken && !_useFallbackTiles;
        final instructions = controller.routeInstructions.take(5).toList();
        final isNavigationMode = controller.isNavigationMode.value;
        if (isNavigationMode) {
          _followRider(rider, controller.hasRiderGpsLocation.value);
        } else {
          _fitRoute(context, routePoints);
        }
        final nextInstruction = controller.nextInstruction;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: rider, initialZoom: 14),
              children: [
                TileLayer(
                  key: ValueKey(useMapboxTiles ? 'mapbox' : 'osm'),
                  urlTemplate: useMapboxTiles
                      ? MapboxConfig.tileUrl
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileDimension: useMapboxTiles ? 512 : 256,
                  maxNativeZoom: useMapboxTiles ? 22 : 19,
                  zoomOffset: useMapboxTiles ? -1 : 0,
                  userAgentPackageName: 'com.naijago.rider',
                  errorTileCallback: (_, __, ___) {
                    if (useMapboxTiles && mounted) {
                      setState(() => _useFallbackTiles = true);
                    }
                  },
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4,
                      color: AppTheme.secondary,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    _marker(
                      point: rider,
                      icon: Icons.delivery_dining,
                      color: AppTheme.primary,
                    ),
                    _marker(
                      point: vendor,
                      icon: Icons.storefront,
                      color: Colors.orange,
                    ),
                    _marker(
                      point: customer,
                      icon: Icons.location_on,
                      color: AppTheme.green,
                    ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _circleButton(icon: Icons.arrow_back, onTap: Get.back),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              isNavigationMode
                                  ? controller.navigationStageLabel
                                  : useMapboxTiles
                                  ? 'Mapbox Delivery Route'
                                  : 'Delivery Route',
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isNavigationMode && nextInstruction != null) ...[
                      const SizedBox(height: 12),
                      _NavigationInstructionBanner(step: nextInstruction),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RouteRow(
                            icon: Icons.storefront,
                            title: 'Pickup',
                            subtitle: deliveryController.vendorAddress.value,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          _RouteRow(
                            icon: Icons.location_on,
                            title: 'Drop-off',
                            subtitle: deliveryController.customerAddress.value,
                            color: AppTheme.green,
                          ),
                          if (MapboxConfig.hasToken &&
                              controller.routeDistanceKm.value > 0) ...[
                            const SizedBox(height: 12),
                            _RouteRow(
                              icon: Icons.route,
                              title: 'Route estimate',
                              subtitle:
                                  '${controller.routeDistanceKm.value.toStringAsFixed(1)} km • ${controller.routeDurationMinutes.value} min',
                              color: AppTheme.primary,
                            ),
                          ],
                          if (!isNavigationMode && instructions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ...instructions.map(
                              (step) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _InstructionRow(step: step),
                              ),
                            ),
                          ],
                          if (!MapboxConfig.hasToken) ...[
                            const SizedBox(height: 12),
                            const _MapboxTokenNotice(),
                          ],
                          const SizedBox(height: 16),
                          _GpsStatusRow(controller: controller),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: controller.isLoadingRoute.value
                                ? null
                                : () async {
                                    await controller.startTracking();
                                    _followRider(
                                      controller.riderLocation.value,
                                      controller.hasRiderGpsLocation.value,
                                    );
                                    await controller.openExternalNavigation();
                                  },
                            icon: Icon(
                              controller.isLoadingRoute.value
                                  ? Icons.sync
                                  : isNavigationMode
                                  ? Icons.navigation
                                  : Icons.assistant_direction,
                            ),
                            label: Text(
                              controller.isLoadingRoute.value
                                  ? 'Loading Route...'
                                  : isNavigationMode
                                  ? 'Open Google Maps'
                                  : 'Start Google Navigation',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            useMapboxTiles
                                ? '© Mapbox © OpenStreetMap'
                                : '© OpenStreetMap',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Marker _marker({
    required LatLng point,
    required IconData icon,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 46,
      height: 46,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
    );
  }
}

class _GpsStatusRow extends StatelessWidget {
  final RiderMapController controller;

  const _GpsStatusRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stale = controller.isGpsStale;
      final active = controller.isTracking.value && !stale;
      final color = active
          ? AppTheme.green
          : stale
          ? Colors.orange
          : AppTheme.textMuted;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.gpsStatusText,
                style: TextStyle(
                  color: stale ? AppTheme.textDark : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _InstructionRow extends StatelessWidget {
  final RouteInstruction step;

  const _InstructionRow({required this.step});

  IconData get _icon {
    if (step.maneuverType == 'arrive') return Icons.flag;
    if (step.maneuverType == 'depart') return Icons.trip_origin;
    if (step.modifier.contains('left')) return Icons.turn_left;
    if (step.modifier.contains('right')) return Icons.turn_right;
    if (step.modifier.contains('uturn')) return Icons.u_turn_left;
    if (step.maneuverType.contains('roundabout')) return Icons.roundabout_left;
    return Icons.straight;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, color: AppTheme.secondary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.instruction,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                step.distanceLabel,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationInstructionBanner extends StatelessWidget {
  final RouteInstruction step;

  const _NavigationInstructionBanner({required this.step});

  IconData get _icon {
    if (step.maneuverType == 'arrive') return Icons.flag;
    if (step.maneuverType == 'depart') return Icons.trip_origin;
    if (step.modifier.contains('left')) return Icons.turn_left;
    if (step.modifier.contains('right')) return Icons.turn_right;
    if (step.modifier.contains('uturn')) return Icons.u_turn_left;
    if (step.maneuverType.contains('roundabout')) return Icons.roundabout_left;
    return Icons.navigation;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.distanceLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapboxTokenNotice extends StatelessWidget {
  const _MapboxTokenNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.20)),
      ),
      child: const Text(
        'Add MAPBOX_ACCESS_TOKEN to enable Mapbox tiles and road routing.',
        style: TextStyle(
          color: AppTheme.textDark,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _RouteRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
