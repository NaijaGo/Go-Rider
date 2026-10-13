import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naijago_ridersapp/core/map/delivery_coordinates.dart';
import 'package:naijago_ridersapp/core/map/mapbox_config.dart';
import 'package:naijago_ridersapp/core/map/rider_tracking_settings.dart';
import 'package:naijago_ridersapp/features/orders/model/rider_order.dart';
import 'support/rider_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() {
    Get.reset();
    MapboxConfig.applyBackendConfig({'hasToken': false});
  });
  test(
    'tracking settings preserve Android foreground service and use iOS location settings',
    () {
      final android =
          riderTrackingSettings(
                activeDelivery: true,
                platform: TargetPlatform.android,
              )
              as AndroidSettings;
      expect(android.distanceFilter, 10);
      expect(android.foregroundNotificationConfig?.setOngoing, isTrue);
      final apple =
          riderTrackingSettings(
                activeDelivery: true,
                platform: TargetPlatform.iOS,
              )
              as AppleSettings;
      expect(apple.allowBackgroundLocationUpdates, isTrue);
      expect(apple.showBackgroundLocationIndicator, isTrue);
      expect(apple.activityType, ActivityType.otherNavigation);
      expect(
        riderTrackingSettings(
          activeDelivery: false,
          platform: TargetPlatform.iOS,
        ).distanceFilter,
        25,
      );
    },
  );

  test(
    'coordinate parser supports aliases, numeric strings and GeoJSON order',
    () {
      expect(
        readDeliveryCoordinate({'lat': '6.52', 'lng': '3.36'}),
        const LatLng(6.52, 3.36),
      );
      expect(
        readDeliveryCoordinate({'latitude': 0, 'longitude': 3.36}),
        const LatLng(0, 3.36),
      );
      expect(
        readDeliveryCoordinate({'latitude': 6.52, 'lon': 0}),
        const LatLng(6.52, 0),
      );
      expect(
        readDeliveryCoordinate({
          'type': 'Point',
          'coordinates': [3.36, 6.52],
        }),
        const LatLng(6.52, 3.36),
      );
    },
  );
  test('invalid or partial coordinates never become a guessed pin', () {
    for (final source in [
      null,
      'address',
      {},
      {'lat': 6.52},
      {'lat': true, 'lng': 3},
      {'lat': 'NaN', 'lng': 3},
      {'lat': 91, 'lng': 3},
      {'lat': 6, 'lng': -181},
      {'lat': '', 'lng': 3},
      {
        'type': 'Point',
        'coordinates': [3],
      },
    ]) {
      expect(
        validDeliveryCoordinate(readDeliveryCoordinate(source)),
        isFalse,
        reason: '$source',
      );
    }
  });
  test(
    'legacy order parsing preserves pickup sequence and actual coordinate aliases',
    () {
      final order = RiderOrder.fromBackend({
        '_id': 'legacy',
        'pickupSequence': [
          {
            'shipment': 's2',
            'sequence': 1,
            'sellerName': 'Second',
            'latitude': 6.53,
            'longitude': 3.37,
          },
          {
            'shipment': 's1',
            'sequence': 2,
            'sellerName': 'First',
            'latitude': 6.52,
            'longitude': 3.36,
          },
        ],
        'userLocation': {'address': 'No pin'},
        'shippingAddress': {
          'lat': '6.54',
          'lng': '3.38',
          'formattedAddress': 'Customer street',
        },
      });
      expect(order.pickupStops.map((stop) => stop.shipmentId), ['s2', 's1']);
      expect(order.vendorLocation, const LatLng(6.53, 3.37));
      expect(order.customerLocation, const LatLng(6.54, 3.38));
      expect(order.customerAddress, 'Customer street');
    },
  );
  test(
    'empty legacy orders retain missing coordinates instead of fake map locations',
    () {
      final order = RiderOrder.fromBackend({'_id': 'empty'});
      expect(validDeliveryCoordinate(order.vendorLocation), isFalse);
      expect(validDeliveryCoordinate(order.customerLocation), isFalse);
      expect(order.pickupVerified, isFalse);
    },
  );
  test(
    'pickup restoration requires server verification for every delivery shipment',
    () {
      expect(
        RiderOrder.fromBackend({
          'shipmentStatus': 'out_for_delivery',
        }).pickupVerified,
        isTrue,
      );
      expect(
        RiderOrder.fromBackend({
          'shipments': [
            {'shipmentStatus': 'out_for_delivery'},
            {'shipmentStatus': 'ready'},
          ],
        }).pickupVerified,
        isFalse,
      );
      expect(
        RiderOrder.fromBackend({
          'shipments': [
            {'shipmentStatus': 'out_for_delivery'},
            {'shipmentStatus': 'out_for_delivery'},
            {'fulfillmentMethod': 'pickup', 'shipmentStatus': 'ready'},
          ],
        }).pickupVerified,
        isTrue,
      );
      expect(
        RiderOrder.fromBackend({
          'shipments': [
            {'shipmentStatus': 'cancelled'},
          ],
        }).pickupVerified,
        isFalse,
      );
    },
  );
  test(
    'delivery restores customer leg only from verified pickup and retains arrival on refresh',
    () {
      final delivery = FixtureDeliveryController();
      delivery.setActiveOrder(fixtureOrder(pickedUp: true));
      expect(delivery.isGoingToCustomer, isTrue);
      delivery.markArrivedAtCustomer();
      delivery.setActiveOrder(fixtureOrder(pickedUp: true));
      expect(delivery.hasArrivedAtCustomer, isTrue);
      delivery.setActiveOrder(fixtureOrder(id: 'new'));
      expect(delivery.isGoingToVendor, isTrue);
    },
  );
  test(
    'route service works without public tile token and uses verified road metrics',
    () async {
      final delivery = FixtureDeliveryController();
      final map = fixtureMap();
      map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      expect(MapboxConfig.hasToken, isFalse);
      expect(map.hasRoadRoute.value, isTrue);
      expect(map.routeDistanceKm.value, 2.4);
      expect(map.routeDurationMinutes.value, 6);
      expect(map.nextInstruction?.instruction, contains('Turn left'));
    },
  );
  test(
    'failed route clears old timing and never displays a straight-line substitute',
    () async {
      var fail = false;
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        directions: (a, b) async {
          if (fail) throw StateError('offline');
          return fixtureRoad(a, b);
        },
      );
      map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      fail = true;
      await map.refreshRoute();
      expect(map.hasRoadRoute.value, isFalse);
      expect(map.routePoints, isEmpty);
      expect(map.routeDistanceKm.value, 0);
      expect(map.routeDurationMinutes.value, 0);
      expect(map.routeInstructions, isEmpty);
      expect(map.routeStatus.value, contains('unavailable'));
    },
  );
  test(
    'malformed route coordinates and negative metrics are rejected safely',
    () async {
      for (final data in [
        {
          'points': [
            [91, 3],
            [6, 3],
          ],
          'distanceMeters': 1,
          'durationSeconds': 1,
        },
        {
          'points': [
            [6, 3],
            [6.1, 3.1],
          ],
          'distanceMeters': -1,
          'durationSeconds': 1,
        },
        {
          'points': [
            [6, 3],
          ],
          'distanceMeters': 1,
          'durationSeconds': 1,
        },
      ]) {
        final delivery = FixtureDeliveryController();
        final map = fixtureMap(directions: (_, __) async => data);
        map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
        registerFixtureDelivery(delivery, map, order: fixtureOrder());
        await flushRiderAsync();
        expect(map.hasRoadRoute.value, isFalse);
        expect(map.routePoints, isEmpty);
        Get.reset();
      }
    },
  );
  test('missing destination or GPS makes no directions requests', () async {
    var calls = 0;
    final delivery = FixtureDeliveryController();
    final map = fixtureMap(
      directions: (a, b) async {
        calls++;
        return fixtureRoad(a, b);
      },
    );
    registerFixtureDelivery(
      delivery,
      map,
      order: fixtureOrder(vendor: const LatLng(0, 0)),
    );
    await flushRiderAsync();
    expect(calls, 0);
    expect(map.hasDestination, isFalse);
    delivery.setActiveOrder(fixtureOrder());
    await flushRiderAsync();
    expect(calls, 0);
    expect(map.routeStatus.value, contains('GPS'));
  });
  test('stale GPS is refreshed before road routing', () async {
    var reads = 0;
    final delivery = FixtureDeliveryController();
    final map = fixtureMap(
      permission: () async => true,
      position: () async {
        reads++;
        return fixturePosition();
      },
    );
    map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
    map.lastGpsUpdateAt.value = DateTime.now().subtract(
      const Duration(minutes: 2),
    );
    registerFixtureDelivery(delivery, map, order: fixtureOrder());
    await flushRiderAsync();
    expect(reads, 1);
    expect(map.hasRoadRoute.value, isTrue);
    expect(map.isGpsStale, isFalse);
  });
  test(
    'new pickup and customer legs ignore late responses from previous destinations',
    () async {
      final pending = <Completer<Map<String, dynamic>>>[];
      final targets = <LatLng>[];
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        directions: (_, target) {
          targets.add(target);
          final c = Completer<Map<String, dynamic>>();
          pending.add(c);
          return c.future;
        },
      );
      map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
      registerFixtureDelivery(
        delivery,
        map,
        order: fixtureOrder(multiple: true),
      );
      await flushRiderAsync();
      delivery.advanceToNextPickupStop();
      expect(delivery.currentPickupIndex.value, 0);
      delivery.markArrivedAtVendor();
      delivery.advanceToNextPickupStop();
      await flushRiderAsync();
      delivery.markPickedUp();
      await flushRiderAsync();
      expect(targets, [
        const LatLng(6.52, 3.36),
        const LatLng(6.53, 3.37),
        const LatLng(6.54, 3.38),
      ]);
      pending[2].complete(fixtureRoad(const LatLng(6.51, 3.35), targets[2]));
      await flushRiderAsync();
      pending[0].complete(fixtureRoad(const LatLng(6.51, 3.35), targets[0]));
      pending[1].complete(fixtureRoad(const LatLng(6.51, 3.35), targets[1]));
      await flushRiderAsync();
      expect(map.routePoints.last, targets[2]);
      expect(map.currentDestination, targets[2]);
    },
  );
  test(
    'clearing delivery stops tracking and invalidates in-flight route',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(directions: (_, __) => pending.future);
      map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      delivery.clearActiveOrder();
      pending.complete(
        fixtureRoad(const LatLng(6.51, 3.35), const LatLng(6.52, 3.36)),
      );
      await flushRiderAsync();
      expect(map.routePoints, isEmpty);
      expect(map.hasDestination, isFalse);
      expect(map.isTracking.value, isFalse);
      expect(delivery.vendorAddress.value, 'Not available');
    },
  );
  test(
    'denied GPS permission never enables navigation or sends updates',
    () async {
      var updates = 0;
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        publish: (_) async {
          updates++;
        },
      );
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      expect(await map.startTracking(), isFalse);
      expect(map.isNavigationMode.value, isFalse);
      expect(map.isTracking.value, isFalse);
      expect(updates, 0);
      expect(map.gpsError.value, contains('allow location'));
    },
  );
  test('stop while permission is pending cannot restart tracking', () async {
    final permission = Completer<bool>();
    final delivery = FixtureDeliveryController();
    final map = fixtureMap(permission: () => permission.future);
    map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
    registerFixtureDelivery(delivery, map, order: fixtureOrder());
    await flushRiderAsync();
    final starting = map.startTracking();
    map.stopTracking();
    permission.complete(true);
    expect(await starting, isFalse);
    expect(map.isTracking.value, isFalse);
  });
  test(
    'GPS stream error stops navigation with a recoverable message',
    () async {
      final gps = StreamController<Position>();
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        permission: () async => true,
        stream: () => gps.stream,
      );
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      expect(await map.startTracking(), isTrue);
      gps.addError(StateError('GPS unavailable'));
      await flushRiderAsync();
      expect(map.isTracking.value, isFalse);
      expect(map.isNavigationMode.value, isFalse);
      expect(map.gpsError.value, contains('Live GPS is unavailable'));
      await gps.close();
    },
  );
  test(
    'GPS publishing is serialized and coalesces rapid positions to latest',
    () async {
      final gps = StreamController<Position>();
      final pending = Completer<void>();
      final sent = <LatLng>[];
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        permission: () async => true,
        stream: () => gps.stream,
        publish: (point) async {
          sent.add(point);
          if (sent.length == 1) await pending.future;
        },
      );
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      await map.startTracking();
      gps.add(fixturePosition(lat: 6.512));
      gps.add(fixturePosition(lat: 6.513));
      await flushRiderAsync();
      expect(sent.length, 1);
      pending.complete();
      await flushRiderAsync();
      expect(sent.length, 2);
      expect(sent.last.latitude, 6.513);
      map.stopTracking();
      gps.add(fixturePosition(lat: 6.514));
      await flushRiderAsync();
      expect(sent.length, 2);
      await gps.close();
    },
  );
  test(
    'external navigation validates destination and falls back to browser safely',
    () async {
      final urls = <Uri>[];
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        launch: (uri) async {
          urls.add(uri);
          return uri.scheme == 'https';
        },
      );
      registerFixtureDelivery(delivery, map);
      expect(await map.openExternalNavigation(), isFalse);
      expect(urls, isEmpty);
      delivery.setActiveOrder(fixtureOrder());
      await flushRiderAsync();
      expect(await map.openExternalNavigation(), isTrue);
      expect(urls.first.scheme, 'google.navigation');
      expect(urls.last.queryParameters['destination'], '6.52,3.36');
    },
  );
  test('tile configuration clears stale URLs and rejects untrusted URLs', () {
    MapboxConfig.applyBackendConfig({
      'hasToken': true,
      'tileUrl':
          'https://api.mapbox.com/styles/v1/test/tiles/{z}/{x}/{y}?access_token=pk.fixture',
    });
    expect(MapboxConfig.hasToken, isTrue);
    MapboxConfig.applyBackendConfig({'hasToken': false});
    expect(MapboxConfig.hasToken, isFalse);
    MapboxConfig.applyBackendConfig({
      'hasToken': true,
      'tileUrl': 'https://invalid.example/tiles',
    });
    expect(MapboxConfig.hasToken, isFalse);
  });
  test(
    'invalid pickup sequence numbers use their original list-position fallback',
    () {
      expect(
        RiderPickupStop.fromBackend({
          'sequence': 'NaN',
        }, fallbackSequence: 2).sequence,
        2,
      );
      expect(
        RiderPickupStop.fromBackend({
          'sequence': double.infinity,
        }, fallbackSequence: 3).sequence,
        3,
      );
    },
  );
  test(
    'invalid turn metrics are ignored while a valid road route remains usable',
    () async {
      final delivery = FixtureDeliveryController();
      final map = fixtureMap(
        directions: (a, b) async {
          final data = fixtureRoad(a, b);
          data['steps'] = [
            {
              'instruction': 'Malformed turn',
              'distanceMeters': 'NaN',
              'durationSeconds': 3,
            },
          ];
          return data;
        },
      );
      map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
      registerFixtureDelivery(delivery, map, order: fixtureOrder());
      await flushRiderAsync();
      expect(map.hasRoadRoute.value, isTrue);
      expect(map.routeInstructions, isEmpty);
    },
  );
}
