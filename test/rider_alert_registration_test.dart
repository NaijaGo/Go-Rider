import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:naijago_ridersapp/core/push/rider_alerts.dart';
import 'package:naijago_ridersapp/core/push/onesignal_service.dart';
import 'package:naijago_ridersapp/core/storage/app_storage.dart';
import 'package:naijago_ridersapp/features/auth/service/registration_checks.dart';
import 'package:naijago_ridersapp/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = Directory.systemTemp.createTempSync(
      'rider-alert-fixtures-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await GetStorage('GetStorage', directory.path).initStorage;
  });
  tearDown(() => Get.reset());

  final now = DateTime(2026, 10, 13);
  for (final condition in ['offline', 'unapproved', 'background']) {
    test('incoming job cannot foreground an $condition rider', () {
      expect(
        RiderAlertPolicy().shouldAlert(
          {'type': 'delivery_offer', 'orderId': 'local'},
          approved: condition != 'unapproved',
          online: condition != 'offline',
          foreground: condition != 'background',
          now: now,
        ),
        isFalse,
      );
    });
  }
  test('push and socket copies alert once, different jobs still alert', () {
    final policy = RiderAlertPolicy();
    bool alert(String type, String id, DateTime date) => policy.shouldAlert(
      {'type': type, 'orderId': id},
      approved: true,
      online: true,
      foreground: true,
      now: date,
    );
    expect(alert('delivery_offer', 'a', now), isTrue);
    expect(alert('rider_order_assigned', 'a', now), isFalse);
    expect(alert('delivery_offer', 'b', now), isTrue);
    expect(
      alert('delivery_offer', 'a', now.add(const Duration(seconds: 16))),
      isTrue,
    );
    expect(alert('order_updated', 'a', now), isFalse);
  });
  for (final type in [
    'pickup_required',
    'confirm_pickup',
    'arrived_at_vendor',
    'delivery_required',
    'confirm_delivery',
    'arrived_at_customer',
  ]) {
    test('$type notification never skips arrival/OTP progression', () {
      expect(RiderAlerts.destination({'type': type}), AppRoutes.activeDelivery);
    });
  }
  test(
    'offers, payout and unknown updates open appropriate existing screens',
    () {
      expect(
        RiderAlerts.destination({'type': 'delivery_offer'}),
        AppRoutes.assignedOrders,
      );
      expect(
        RiderAlerts.destination({'type': 'delivery_payout'}),
        AppRoutes.earnings,
      );
      expect(
        RiderAlerts.destination({'type': 'general'}),
        AppRoutes.notifications,
      );
    },
  );
  test(
    'accepted assignments open active delivery rather than unclaimed offers',
    () {
      expect(
        RiderAlerts.destination({'type': 'order_assigned'}),
        AppRoutes.activeDelivery,
      );
      final policy = RiderAlertPolicy();
      expect(
        policy.shouldAlert(
          {'type': 'delivery_offer', 'orderId': 'a'},
          approved: true,
          online: true,
          foreground: true,
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.shouldAlert(
          {'type': 'order_assigned', 'orderId': 'a'},
          approved: true,
          online: true,
          foreground: true,
          now: now,
        ),
        isTrue,
      );
    },
  );

  test('foreground sound invokes native notification tone once', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(RiderAlerts.channel, (call) async {
          calls.add(call.method);
          return null;
        });
    await RiderAlerts.play();
    expect(calls, ['playAlert']);
  });
  test('unsupported native sound falls back without throwing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          RiderAlerts.channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    await expectLater(RiderAlerts.play(), completes);
  });

  testWidgets(
    'cold-start tap waits through login/pending then opens for approved session',
    (tester) async {
      Get.testMode = true;
      await tester.runAsync(() async {
        await AppStorage.clear();
      });
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.login,
          getPages: [
            for (final route in [
              AppRoutes.login,
              AppRoutes.pendingApproval,
              AppRoutes.dashboard,
              AppRoutes.assignedOrders,
            ])
              GetPage(
                name: route,
                page: () => Scaffold(body: Text(route)),
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => OneSignalService.handleNotificationTap({
          'type': 'delivery_offer',
          'orderId': 'fixture',
        }),
      );
      expect(Get.currentRoute, AppRoutes.login);
      expect(GetStorage().read('pending_notification_destination'), isNotNull);
      await tester.runAsync(() async {
        await AppStorage.saveToken('fixture-token');
        await AppStorage.saveRiderStatus('pending');
      });
      Get.offAllNamed(AppRoutes.pendingApproval);
      await tester.pumpAndSettle();
      await tester.runAsync(OneSignalService.consumePendingDestination);
      expect(Get.currentRoute, AppRoutes.pendingApproval);
      await tester.runAsync(() => AppStorage.saveRiderStatus('approved'));
      Get.offAllNamed(AppRoutes.dashboard);
      await tester.pumpAndSettle();
      await tester.runAsync(OneSignalService.consumePendingDestination);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.assignedOrders);
      expect(GetStorage().read('pending_notification_destination'), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('impossible dates are rejected instead of normalized', () {
    expect(RegistrationChecks.field('Date of Birth', '1995-02-31'), isNotNull);
  });

  testWidgets(
    'online foreground dashboard opens jobs once for push/socket copies',
    (tester) async {
      Get.testMode = true;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(RiderAlerts.channel, (call) async {
            calls.add(call.method);
            return true;
          });
      await tester.runAsync(() async {
        await AppStorage.clear();
        await AppStorage.saveToken('fixture-token');
        await AppStorage.saveRiderStatus('approved');
        await AppStorage.saveRiderOnline(true);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.dashboard,
          getPages: [
            for (final route in [AppRoutes.dashboard, AppRoutes.assignedOrders])
              GetPage(
                name: route,
                page: () => Scaffold(body: Text(route)),
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      RiderAlerts.incoming({
        'type': 'delivery_offer',
        'orderId': 'foreground-fixture',
      });
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.assignedOrders);
      expect(calls, ['playAlert']);
      RiderAlerts.incoming({
        'type': 'rider_order_assigned',
        'orderId': 'foreground-fixture',
      });
      await tester.pumpAndSettle();
      expect(calls, ['playAlert']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final entry in {
    'Email': ['invalid', 'rider@example.test'],
    'Phone Number': ['----------', '+2348012345678'],
    'Emergency Contact Phone': ['abc', '08012345678'],
    'Account Number': ['123', '0123456789'],
    'Password': ['123', 'test-pass'],
    'Vehicle Type': ['airplane', 'bicycle'],
    'Date of Birth': ['2099-01-01', '1990-04-12'],
  }.entries) {
    test('registration checks ${entry.key} before upload', () {
      expect(
        RegistrationChecks.field(entry.key, entry.value.first, today: now),
        isNotNull,
      );
      expect(
        RegistrationChecks.field(entry.key, entry.value.last, today: now),
        isNull,
      );
    });
  }
  test(
    'optional fields and bicycle license do not block signup; motor license does',
    () {
      expect(RegistrationChecks.field('Gender', ''), isNull);
      expect(RegistrationChecks.field('Preferred Delivery Zone', ''), isNull);
      expect(
        RegistrationChecks.field(
          "Driver's License Number",
          '',
          vehicle: 'bicycle',
        ),
        isNull,
      );
      expect(
        RegistrationChecks.field(
          "Driver's License Number",
          '',
          vehicle: 'motorcycle',
        ),
        isNotNull,
      );
      expect(
        RegistrationChecks.field(
          'Confirm Password',
          'wrong',
          password: 'test-pass',
        ),
        isNotNull,
      );
    },
  );
}
