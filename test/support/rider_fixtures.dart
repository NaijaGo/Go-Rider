import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naijago_ridersapp/features/orders/controller/delivery_controller.dart';
import 'package:naijago_ridersapp/features/orders/model/rider_order.dart';
import 'package:naijago_ridersapp/features/map/controller/map_controller.dart';

class FixtureDeliveryController extends DeliveryController {
  FixtureDeliveryController() : super(notifier: (_, __) {});
  // Fixture deliberately skips network and plugin startup.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadActiveDelivery() async {}
}

RiderOrder fixtureOrder({
  String id = 'fixture-order',
  bool multiple = false,
  LatLng vendor = const LatLng(6.52, 3.36),
  LatLng customer = const LatLng(6.54, 3.38),
  bool pickedUp = false,
}) => RiderOrder(
  id: id,
  orderCode: '#NGO-FIXTURE',
  vendorName: 'Fixture kitchen',
  vendorAddress: 'Test pickup address',
  customerName: 'Fixture customer',
  customerPhone: 'Not provided',
  customerAddress: 'Test delivery address',
  goodsType: 'Delivery package',
  deliveryFee: 750,
  vendorLocation: vendor,
  customerLocation: customer,
  status: RiderOrderStatus.accepted,
  pickupVerified: pickedUp,
  pickupStops: multiple
      ? [
          RiderPickupStop(
            shipmentId: 'one',
            sequence: 1,
            sellerName: 'Fixture kitchen',
            address: 'Test pickup address',
            location: vendor,
          ),
          const RiderPickupStop(
            shipmentId: 'two',
            sequence: 2,
            sellerName: 'Fixture store',
            address: 'Second test pickup',
            location: LatLng(6.53, 3.37),
          ),
        ]
      : [],
);

Position fixturePosition({double lat = 6.51, double lng = 3.35}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Map<String, dynamic> fixtureRoad(LatLng origin, LatLng destination) => {
  'success': true,
  'points': [
    [origin.latitude, origin.longitude],
    [destination.latitude, destination.longitude],
  ],
  'distanceMeters': 2400,
  'durationSeconds': 360,
  'steps': [
    {
      'instruction': 'Turn left onto Test Street',
      'roadName': 'Test Street',
      'distanceMeters': 250,
      'durationSeconds': 40,
      'maneuverType': 'turn',
      'modifier': 'left',
    },
  ],
};

RiderMapController fixtureMap({
  DirectionsLoader? directions,
  Future<bool> Function()? permission,
  Future<Position> Function()? position,
  Stream<Position> Function()? stream,
  Future<void> Function(LatLng)? publish,
  void Function(Map<String, dynamic>)? emit,
  Future<bool> Function(Uri)? launch,
}) => RiderMapController(
  directionsLoader: directions ?? (a, b) async => fixtureRoad(a, b),
  configLoader: () async => {'hasToken': false},
  permissionChecker: permission ?? () async => false,
  positionReader: position ?? () async => fixturePosition(),
  positionStream: stream ?? () => const Stream<Position>.empty(),
  locationPublisher: publish ?? (_) async {},
  locationEmitter: emit ?? (_) {},
  navigationLauncher: launch ?? (_) async => true,
);

Future<void> flushRiderAsync() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void registerFixtureDelivery(
  FixtureDeliveryController delivery,
  RiderMapController map, {
  RiderOrder? order,
}) {
  Get.put<DeliveryController>(delivery);
  Get.put<RiderMapController>(map);
  if (order != null) delivery.setActiveOrder(order);
}
