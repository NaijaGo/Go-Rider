import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naijago_ridersapp/features/location/controller/rider_location_controller.dart';
import 'support/rider_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline status never starts GPS or sends a location', () async {
    var permissions = 0;
    var sent = 0;
    final controller = RiderLocationController(
      onlineReader: () => false,
      permissionChecker: () async {
        permissions++;
        return true;
      },
      locationPublisher: (_) async {
        sent++;
      },
    );
    await controller.startOnlineLocationUpdates();
    expect(permissions, 0);
    expect(sent, 0);
    expect(controller.isTrackingOnlineLocation.value, isFalse);
    controller.onClose();
  });
  test('background permission denial prevents online tracking', () async {
    final controller = RiderLocationController(
      onlineReader: () => true,
      permissionChecker: () async => false,
    );
    await controller.startOnlineLocationUpdates();
    expect(controller.isTrackingOnlineLocation.value, isFalse);
    expect(controller.locationError.value, contains('background'));
    controller.onClose();
  });
  test(
    'going offline during permission lookup cannot resurrect the stream',
    () async {
      var online = true;
      var streams = 0;
      final permission = Completer<bool>();
      final controller = RiderLocationController(
        onlineReader: () => online,
        permissionChecker: () => permission.future,
        positionStream: () {
          streams++;
          return const Stream<Position>.empty();
        },
      );
      final starting = controller.startOnlineLocationUpdates();
      online = false;
      controller.stopOnlineLocationUpdates();
      permission.complete(true);
      await starting;
      expect(streams, 0);
      expect(controller.isTrackingOnlineLocation.value, isFalse);
      controller.onClose();
    },
  );
  test(
    'failed fresh position never returns an old fix for going online',
    () async {
      var fail = false;
      final controller = RiderLocationController(
        onlineReader: () => false,
        permissionChecker: () async => true,
        positionReader: () async {
          if (fail) throw StateError('GPS unavailable');
          return fixturePosition();
        },
      );
      expect(
        await controller.refreshCurrentLocation(sendToServerWhenOnline: false),
        const LatLng(6.51, 3.35),
      );
      fail = true;
      expect(
        await controller.refreshCurrentLocation(sendToServerWhenOnline: false),
        isNull,
      );
      expect(controller.locationError.value, contains('fresh GPS'));
      controller.onClose();
    },
  );
  test(
    'offline while a GPS fix is pending prevents late location publication',
    () async {
      var online = true;
      var sent = 0;
      final position = Completer<Position>();
      final gps = StreamController<Position>();
      final controller = RiderLocationController(
        onlineReader: () => online,
        permissionChecker: () async => true,
        positionReader: () => position.future,
        positionStream: () => gps.stream,
        locationPublisher: (_) async {
          sent++;
        },
        locationEmitter: (_) {},
      );
      final starting = controller.startOnlineLocationUpdates();
      await flushRiderAsync();
      online = false;
      controller.stopOnlineLocationUpdates();
      position.complete(fixturePosition());
      await starting;
      expect(sent, 0);
      expect(controller.currentLocation.value, isNull);
      controller.onClose();
      await gps.close();
    },
  );
  test(
    'online stream failure stops tracking and reports a retryable state',
    () async {
      final gps = StreamController<Position>();
      final controller = RiderLocationController(
        onlineReader: () => true,
        permissionChecker: () async => true,
        positionReader: () async => fixturePosition(),
        positionStream: () => gps.stream,
        locationPublisher: (_) async {},
        locationEmitter: (_) {},
      );
      await controller.startOnlineLocationUpdates();
      expect(controller.isTrackingOnlineLocation.value, isTrue);
      gps.addError(StateError('disconnect'));
      await flushRiderAsync();
      expect(controller.isTrackingOnlineLocation.value, isFalse);
      expect(controller.locationError.value, contains('disconnected'));
      controller.onClose();
      await gps.close();
    },
  );
  test(
    'rapid online updates serialize requests and send the latest pending position',
    () async {
      final gps = StreamController<Position>();
      final pending = Completer<void>();
      final sent = <LatLng>[];
      final controller = RiderLocationController(
        onlineReader: () => true,
        permissionChecker: () async => true,
        positionReader: () async => fixturePosition(),
        positionStream: () => gps.stream,
        locationPublisher: (point) async {
          sent.add(point);
          if (sent.length == 1) await pending.future;
        },
        locationEmitter: (_) {},
      );
      final starting = controller.startOnlineLocationUpdates();
      await flushRiderAsync();
      gps.add(fixturePosition(lat: 6.512));
      gps.add(fixturePosition(lat: 6.514));
      await flushRiderAsync();
      expect(sent.length, 1);
      pending.complete();
      await starting;
      await flushRiderAsync();
      expect(sent, [const LatLng(6.51, 3.35), const LatLng(6.514, 3.35)]);
      controller.onClose();
      await gps.close();
    },
  );
  test(
    'invalid GPS does not produce pins, HTTP updates or socket updates',
    () async {
      final gps = StreamController<Position>();
      var sent = 0;
      var emitted = 0;
      final controller = RiderLocationController(
        onlineReader: () => true,
        permissionChecker: () async => true,
        positionReader: () async => fixturePosition(lat: 0, lng: 0),
        positionStream: () => gps.stream,
        locationPublisher: (_) async {
          sent++;
        },
        locationEmitter: (_) {
          emitted++;
        },
      );
      await controller.startOnlineLocationUpdates();
      gps.add(fixturePosition(lat: 91));
      await flushRiderAsync();
      expect(sent, 0);
      expect(emitted, 0);
      expect(controller.currentLocation.value, isNull);
      expect(controller.locationError.value, contains('invalid'));
      controller.onClose();
      await gps.close();
    },
  );
}
