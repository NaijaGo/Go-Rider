import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:naijago_ridersapp/core/api/api_client.dart';
import 'package:naijago_ridersapp/core/api/api_paths.dart';
import 'package:naijago_ridersapp/core/storage/app_storage.dart';
import 'package:naijago_ridersapp/features/agreement/controller/rider_agreement_controller.dart';
import 'package:naijago_ridersapp/features/agreement/service/rider_agreement_api.dart';
import 'package:naijago_ridersapp/features/agreement/view/rider_agreement_view.dart';
import 'package:naijago_ridersapp/features/orders/controller/delivery_controller.dart';
import 'package:naijago_ridersapp/routes/app_routes.dart';
import 'package:naijago_ridersapp/features/dashboard/view/daily_bonus_card.dart';
import 'package:naijago_ridersapp/core/theme/app_theme.dart';
import 'package:naijago_ridersapp/features/auth/controller/auth_controller.dart';
import 'package:naijago_ridersapp/features/auth/view/login_view.dart';
import 'package:naijago_ridersapp/features/auth/view/register_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naijago_ridersapp/features/dashboard/view/dashboard_view.dart';
import 'package:naijago_ridersapp/features/earnings/controller/withdrawal_controller.dart';
import 'package:naijago_ridersapp/features/earnings/view/earnings_view.dart';
import 'package:naijago_ridersapp/features/notifications/controller/notification_controller.dart';
import 'package:naijago_ridersapp/features/orders/view/active_delivery_view.dart';
import 'package:naijago_ridersapp/features/map/view/delivery_map_view.dart';
import 'package:naijago_ridersapp/features/orders/controller/orders_controller.dart';
import 'package:naijago_ridersapp/features/orders/view/assigned_orders_view.dart';
import 'package:naijago_ridersapp/features/orders/view/confirm_pickup_view.dart';
import 'package:naijago_ridersapp/features/orders/view/confirm_delivered_view.dart';
import 'package:naijago_ridersapp/features/profile/controller/rider_profile_controller.dart';
import 'package:naijago_ridersapp/features/profile/view/profile_view.dart';
import 'package:naijago_ridersapp/features/notifications/view/notifications_view.dart';
import 'support/rider_fixtures.dart';

class _OfflineTiles extends TileProvider {
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

class _MockApi implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool dashboardUnavailable = false;
  bool dashboardOnline = false;
  int availabilityStatus = 200;
  int verificationStatus = 200;
  int bonusCount = 18;
  String? bonusState;
  Future<void>? verificationGate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/riders/daily-bonus/request') bonusState = 'pending';
    final dashboard = options.path == ApiPaths.dashboard;
    final verifying = {
      ApiPaths.verifyPickup,
      ApiPaths.verifyDelivery,
    }.contains(options.path);
    if (verifying && verificationGate != null) await verificationGate;
    final status = dashboard && dashboardUnavailable
        ? 503
        : options.path == ApiPaths.riderStatus
        ? availabilityStatus
        : verifying
        ? verificationStatus
        : 200;
    final body = options.path == '/riders/daily-bonus'
        ? {
            'success': true,
            'threshold': 20,
            'amount': 10000,
            'completedOrders': bonusCount,
            'eligible': bonusCount >= 20,
            'claim': bonusState == null ? null : {'state': bonusState},
          }
        : dashboard
        ? {
            'todayEarnings': 123456.75,
            'completedDeliveries': 18,
            'activeDeliveries': 1,
            'isActive': dashboardOnline,
            'isAvailable': dashboardOnline,
            'message': 'Dashboard temporarily unavailable',
          }
        : {
            'success': status == 200,
            'message': status == 200 ? 'Verified' : 'Invalid code',
            'earnings': 750,
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FixtureNotifications extends NotificationController {
  // Fixture deliberately skips network and plugin startup.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> setOnlineStatus(bool online) async {}
}

class _FixtureWallet extends WithdrawalController {
  // Fixture deliberately skips network and plugin startup.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadEarnings() async {}
}

class _FixtureOrders extends OrdersController {
  @override
  // Fixture deliberately skips network startup.
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadAssignedOrders() async {}
}

class _BlockedAgreement extends RiderAgreementController {
  _BlockedAgreement()
    : super(
        hasSession: () => true,
        fetchStatus: () async => {
          'success': true,
          'accepted': false,
          'requiresAcceptance': true,
        },
      );
  bool prompted = false;
  @override
  void requireReview() {
    prompted = true;
    invalidate();
  }
}

final _previewKey = GlobalKey();
Future<void> _memoryOnlineStatus(bool _) async {}
Future<void> _savePreview(WidgetTester tester, String filename) async {
  if (!const bool.fromEnvironment('RIDER_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = Directory('output/previews');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$filename.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _show(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  double scale = 1,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: _previewKey, child: page),
    ),
  );
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text(label).last,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockApi api;
  setUpAll(() async {
    if (const bool.fromEnvironment('RIDER_UI_PREVIEWS')) {
      for (final entry in {
        'Roboto': 'RIDER_PREVIEW_FONT',
        'MaterialIcons': 'RIDER_PREVIEW_ICONS',
      }.entries) {
        final bytes = await File(
          Platform.environment[entry.value]!,
        ).readAsBytes();
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
    // Only a new temporary fixture store is used; never rider device storage.
    final directory = Directory.systemTemp.createTempSync('naijago-rider-ui-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await GetStorage('GetStorage', directory.path).initStorage;
    ApiClient.dio.options.baseUrl = 'https://fixture.invalid/api';
  });
  setUp(() {
    Get.testMode = true;
    api = _MockApi();
    ApiClient.dio.httpClientAdapter = api;
  });
  tearDown(() async {
    Get.reset();
  });

  Map<String, dynamic> pauseStatus(String status) => {
    'success': true,
    'enforcementEnabled': false,
    'enforcementPaused': true,
    'accepted': false,
    'requiresAcceptance': false,
    'workAllowed': status == 'approved',
    'riderStatus': status,
    'agreement': null,
    'acceptance': null,
    'requiredVersion': null,
    'acceptedVersion': null,
    'acceptedAt': null,
  };

  test(
    'real order loading recognizes verified pause and stops after invalidation',
    () async {
      await AppStorage.saveToken('fixture-work-token');
      await AppStorage.saveRiderStatus('approved');
      final agreement = Get.put(
        RiderAgreementController(
          fetchStatus: () async => pauseStatus('approved'),
        ),
      );
      expect(await agreement.ensureAccepted(navigate: false), true);
      expect(agreement.confirmed.value, false);
      final orders = OrdersController();
      await orders.loadAssignedOrders();
      expect(
        api.requests.where((r) => r.path == ApiPaths.availableOrders),
        hasLength(1),
      );
      agreement.invalidate();
      await orders.loadAssignedOrders();
      expect(
        api.requests.where((r) => r.path == ApiPaths.availableOrders),
        hasLength(1),
      );
      await AppStorage.clear();
    },
  );

  testWidgets(
    'pending agreement-only session continues to approval and never dashboard during pause',
    (tester) async {
      await AppStorage.clear();
      await AppStorage.saveAgreementToken('fixture-enrollment-token');
      await AppStorage.saveRiderStatus('pending');
      final agreement = RiderAgreementController(
        fetchCurrent: () async => pauseStatus('pending'),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: RiderAgreementView(controller: agreement),
          getPages: [
            GetPage(
              name: AppRoutes.pendingApproval,
              page: () =>
                  const Scaffold(body: Text('Pending fixture approval')),
            ),
            GetPage(
              name: AppRoutes.dashboard,
              page: () =>
                  const Scaffold(body: Text('Operational fixture dashboard')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continue'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Pending fixture approval'), findsOneWidget);
      expect(find.text('Operational fixture dashboard'), findsNothing);
      expect(AppStorage.token, isNull);
      expect(agreement.confirmed.value, false);
      expect(api.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await AppStorage.clear();
    },
  );

  test(
    'agreement API preserves explicit enrollment token without substituting a work token',
    () async {
      await AppStorage.saveToken('fixture-work-token');
      await AppStorage.saveAgreementToken('fixture-enrollment-token');
      await RiderAgreementApi.current();
      final request = api.requests.last;
      expect(request.path, '/riders/agreements/current');
      expect(
        request.headers['Authorization'],
        'Bearer fixture-enrollment-token',
      );
      expect(request.extra['agreementRequest'], true);
      await AppStorage.clear();
    },
  );

  test(
    'real order controller blocks claim request until acceptance is verified',
    () async {
      await AppStorage.saveToken('fixture-work-token');
      final agreement = Get.put<RiderAgreementController>(_BlockedAgreement());
      final orders = _FixtureOrders();
      await orders.acceptOrder(fixtureOrder());
      expect(api.requests.where((r) => r.path.contains('/claim/')), isEmpty);
      expect((agreement as _BlockedAgreement).prompted, true);
      expect(orders.isLoading.value, false);
      await AppStorage.clear();
    },
  );

  testWidgets(
    'agreement gate blocks going online before GPS or availability requests',
    (tester) async {
      Get.put<NotificationController>(_FixtureNotifications());
      final agreement = Get.put<RiderAgreementController>(_BlockedAgreement());
      await _show(
        tester,
        const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect((agreement as _BlockedAgreement).prompted, true);
      expect(
        api.requests.where((r) => r.path == ApiPaths.riderStatus),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily bonus displays backend progress and waits for admin approval',
    (tester) async {
      api.bonusCount = 20;
      await _show(
        tester,
        const Scaffold(body: SingleChildScrollView(child: DailyBonusCard())),
        width: 320,
        scale: 1.6,
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(find.text('20 / 20 completed orders today'), findsOneWidget);
      await tester.ensureVisible(find.text('Request daily bonus'));
      await tester.tap(find.text('Request daily bonus'));
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(find.text('Bonus request pending admin review'), findsOneWidget);
      expect(find.text('Approved and credited to your wallet'), findsNothing);
      expect(
        api.requests
            .where((r) => r.path.endsWith('/daily-bonus/request'))
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unaccepted rider can restore an owned active delivery when agreement verification is unavailable',
    (tester) async {
      await tester.runAsync(() async {
        await AppStorage.saveToken('fixture-work-token');
        await AppStorage.saveRiderStatus('approved');
      });
      final delivery = Get.put<DeliveryController>(FixtureDeliveryController());
      delivery.activeOrder.value = fixtureOrder();
      final agreement = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async =>
            throw StateError('Fixture agreement unavailable'),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          getPages: [
            GetPage(
              name: AppRoutes.activeDelivery,
              page: () => const Scaffold(body: Text('Existing delivery flow')),
            ),
          ],
          home: RiderAgreementView(controller: agreement),
        ),
      );
      await tester.pumpAndSettle();
      expect(agreement.confirmed.value, false);
      await tester.tap(find.text('Finish an already claimed delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Existing delivery flow'), findsOneWidget);
      expect(
        api.requests.where(
          (r) => r.path.contains('/claim/') || r.path == ApiPaths.riderStatus,
        ),
        isEmpty,
      );
      await tester.runAsync(AppStorage.clear);
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<void> continueSignup(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'registration steps keep fields and documents at $width width',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = Get.put(AuthController());
        auth.fullNameController.text = 'Fixture Rider';
        auth.phoneController.text = '+2348012345678';
        auth.emailController.text = 'rider@example.test';
        auth.dateOfBirthController.text = '1995-04-12';
        auth.homeAddressController.text = 'Fixture home address';
        auth.registerPasswordController.text = 'local-pass';
        auth.confirmPasswordController.text = 'local-pass';
        auth.stateController.text = 'Lagos';
        auth.cityController.text = 'Ikeja';
        auth.vehicleTypeController.text = 'motorcycle';
        auth.vehicleModelController.text = 'Fixture motorcycle';
        auth.plateNumberController.text = 'TEST-001';
        auth.licenseNumberController.text = 'fixture-license';
        auth.idNumberController.text = '12345678901';
        auth.bankNameController.text = 'Fixture bank';
        auth.accountNumberController.text = '0123456789';
        auth.accountNameController.text = 'Fixture Rider';
        await _show(tester, const RegisterView(), width: width, scale: 1.6);
        expect(find.text('Step 1 of 5'), findsOneWidget);
        await _savePreview(tester, 'rider-registration-accessible');
        expect(find.text('Upload Selfie'), findsNothing);
        expect(find.byTooltip('Show password'), findsNWidgets(2));
        await continueSignup(tester);
        expect(find.text('Step 2 of 5'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        await continueSignup(tester);
        expect(find.text('Step 3 of 5'), findsOneWidget);
        await continueSignup(tester);
        expect(find.text('Step 3 of 5'), findsOneWidget);
        expect(find.textContaining('all four verification'), findsOneWidget);
        // Fixture names only: no picker, real photo upload or provider is used.
        for (final target in [
          auth.ninFront,
          auth.ninBack,
          auth.platePhoto,
          auth.selfie,
        ]) {
          target.value = XFile('fixture.jpg');
        }
        await continueSignup(tester);
        expect(find.text('Step 4 of 5'), findsOneWidget);
        await continueSignup(tester);
        expect(find.text('Step 5 of 5'), findsOneWidget);
        expect(find.text('Emergency Contact'), findsOneWidget);
        expect(find.text('Submit Registration'), findsOneWidget);
        await tester.ensureVisible(find.text('Previous'));
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();
        expect(find.text('Step 4 of 5'), findsOneWidget);
        expect(auth.accountNumberController.text, '0123456789');
        expect(auth.ninFront.value, isNotNull);
        expect(tester.takeException(), isNull);
        expect(api.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('registration validates current step before continuing', (
    tester,
  ) async {
    Get.put(AuthController());
    await _show(tester, const RegisterView());
    await continueSignup(tester);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Please enter full name'), findsOneWidget);
    expect(api.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'map layout fits $width width with enlarged text and labelled stops',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final delivery = FixtureDeliveryController();
        final map = fixtureMap();
        map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
        registerFixtureDelivery(
          delivery,
          map,
          order: fixtureOrder(multiple: true),
        );
        await _show(
          tester,
          DeliveryMapView(tileProvider: _OfflineTiles()),
          width: width,
          scale: 1.6,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Navigate to vendor'), findsOneWidget);
        expect(find.byKey(const ValueKey('map-pickup-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('map-pickup-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('map-drop-off')), findsOneWidget);
        expect(find.text('2.4 km · 6 min'), findsOneWidget);
        expect(find.byTooltip('Show all stops'), findsOneWidget);
        expect(find.byTooltip('Centre on rider'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'missing map pins show no invented markers and disable navigation',
    (tester) async {
      final delivery = FixtureDeliveryController();
      final map = fixtureMap();
      registerFixtureDelivery(
        delivery,
        map,
        order: fixtureOrder(
          vendor: const LatLng(0, 0),
          customer: const LatLng(0, 0),
        ),
      );
      await _show(tester, DeliveryMapView(tileProvider: _OfflineTiles()));
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      expect(_button(tester, 'Open Google Maps').onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('map has a safe empty state without active delivery', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    registerFixtureDelivery(FixtureDeliveryController(), fixtureMap());
    await _show(tester, const DeliveryMapView());
    expect(find.text('No active delivery'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
  testWidgets('active delivery hides invented ETA when GPS is unavailable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final delivery = FixtureDeliveryController();
    final map = fixtureMap();
    registerFixtureDelivery(delivery, map, order: fixtureOrder());
    await _show(tester, const ActiveDeliveryView(), width: 320, scale: 1.6);
    await tester.scrollUntilVisible(
      find.text('Route pending'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 mins'), findsNothing);
    expect(find.text('Route pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'active delivery enables pickup verification only after all pickup stops',
    (tester) async {
      final delivery = FixtureDeliveryController();
      final map = fixtureMap();
      registerFixtureDelivery(
        delivery,
        map,
        order: fixtureOrder(multiple: true),
      );
      await _show(tester, const ActiveDeliveryView());
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Confirm Pickup'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_button(tester, 'Confirm Pickup').onPressed, isNull);
      delivery.markArrivedAtVendor();
      await tester.pumpAndSettle();
      expect(_button(tester, 'Confirm Pickup').onPressed, isNull);
      expect(_button(tester, 'Continue to Pickup 2').onPressed, isNotNull);
      delivery.advanceToNextPickupStop();
      delivery.markArrivedAtVendor();
      await tester.pumpAndSettle();
      expect(_button(tester, 'Confirm Pickup').onPressed, isNotNull);
      expect(_button(tester, 'Confirm Delivered').onPressed, isNull);
      delivery.markPickedUp();
      await tester.pumpAndSettle();
      expect(_button(tester, 'Confirm Pickup').onPressed, isNull);
      expect(_button(tester, 'Confirm Delivered').onPressed, isNull);
      delivery.markArrivedAtCustomer();
      await tester.pumpAndSettle();
      expect(_button(tester, 'Confirm Delivered').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final fail in [true, false]) {
    testWidgets(
      'pickup API ${fail ? 'failure retains vendor stage' : 'success changes to customer stage'}',
      (tester) async {
        final delivery = FixtureDeliveryController();
        final map = fixtureMap();
        registerFixtureDelivery(delivery, map, order: fixtureOrder());
        delivery.markArrivedAtVendor();
        await _show(tester, const Scaffold(body: Text('Fixture')));
        api.verificationStatus = fail ? 400 : 200;
        final result = await tester.runAsync(
          () => delivery.confirmPickup('fixture-otp'),
        );
        await tester.pumpAndSettle();
        expect(result, !fail);
        expect(delivery.hasPickedUp, !fail);
        final request = api.requests.singleWhere(
          (r) => r.path == ApiPaths.verifyPickup,
        );
        expect(request.method, 'POST');
        expect(request.data, {
          'orderId': 'fixture-order',
          'pickupOTP': 'fixture-otp',
        });
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  }
  for (final fail in [true, false]) {
    testWidgets(
      'delivery API ${fail ? 'failure retains order' : 'success clears delivery'}',
      (tester) async {
        final delivery = FixtureDeliveryController();
        final map = fixtureMap();
        registerFixtureDelivery(
          delivery,
          map,
          order: fixtureOrder(pickedUp: true),
        );
        delivery.markArrivedAtCustomer();
        await _show(tester, const Scaffold(body: Text('Fixture')));
        api.verificationStatus = fail ? 400 : 200;
        final result = await tester.runAsync(
          () => delivery.confirmDelivery('fixture-otp'),
        );
        await tester.pumpAndSettle();
        expect(result, !fail);
        expect(delivery.activeOrder.value == null, !fail);
        final request = api.requests.singleWhere(
          (r) => r.path == ApiPaths.verifyDelivery,
        );
        expect(request.data, {
          'orderId': 'fixture-order',
          'deliveryOTP': 'fixture-otp',
        });
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'dashboard fits narrow screen and preserves action destinations',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<NotificationController>(_FixtureNotifications());
      await _show(
        tester,
        const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
        width: 320,
        scale: 1.6,
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(find.text('NaijaGo Rider'), findsOneWidget);
      expect(find.text('₦123456.75'), findsOneWidget);
      for (final action in [
        'Assigned Orders',
        'Active Delivery',
        'Earnings',
        'Notifications',
        'Profile',
      ]) {
        await tester.scrollUntilVisible(
          find.text(action),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(action), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'dashboard failure offers retry and disables unconfirmed availability',
    (tester) async {
      Get.put<NotificationController>(_FixtureNotifications());
      api.dashboardUnavailable = true;
      await _show(
        tester,
        const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(find.text('Retry dashboard'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      api.dashboardUnavailable = false;
      await tester.ensureVisible(find.text('Retry dashboard'));
      await tester.tap(find.text('Retry dashboard'));
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(find.text('Retry dashboard'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'going offline with an active order requires explicit confirmation',
    (tester) async {
      api.dashboardOnline = true;
      Get.put<NotificationController>(_FixtureNotifications());
      final delivery = FixtureDeliveryController();
      registerFixtureDelivery(delivery, fixtureMap(), order: fixtureOrder());
      await _show(
        tester,
        const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Active delivery in progress'), findsOneWidget);
      await tester.tap(find.text('Stay Online'));
      await tester.pumpAndSettle();
      expect(
        api.requests.where((r) => r.path == ApiPaths.riderStatus),
        isEmpty,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Go Offline'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      final request = api.requests.singleWhere(
        (r) => r.path == ApiPaths.riderStatus,
      );
      expect(request.data, {'isAvailable': false, 'isActive': false});
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(delivery.activeOrder.value, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed availability update retains backend-confirmed online status',
    (tester) async {
      api.dashboardOnline = true;
      api.availabilityStatus = 403;
      Get.put<NotificationController>(_FixtureNotifications());
      await _show(
        tester,
        const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
      );
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(flushRiderAsync);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('going online requires accepting the location disclosure first', (
    tester,
  ) async {
    Get.put<NotificationController>(_FixtureNotifications());
    await _show(
      tester,
      const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
    );
    await tester.runAsync(flushRiderAsync);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Location access while you are online'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.path == ApiPaths.riderStatus), isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
  testWidgets('earnings fits large balances on narrow screens', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final wallet = _FixtureWallet();
    Get.put<WithdrawalController>(wallet);
    wallet.availableBalance.value = 123456.75;
    wallet.totalEarnings.value = 12345678.75;
    await _show(tester, const EarningsView(), width: 320, scale: 1.6);
    await tester.scrollUntilVisible(
      find.text('Withdrawn'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'login retains password, Google and account recovery controls on narrow screens',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<AuthController>(AuthController());
      await _show(tester, const LoginView(), width: 320, scale: 1.6);
      expect(find.text('Welcome Rider'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Continue with Google'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in <String, Widget>{
    'assigned orders': const AssignedOrdersView(),
    'profile': const ProfileView(),
    'notifications': const NotificationsView(),
    'pickup confirmation': const ConfirmPickupView(),
    'delivery confirmation': const ConfirmDeliveredView(),
  }.entries) {
    testWidgets('${entry.key} fits narrow screen with enlarged text', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<AuthController>(AuthController());
      Get.put<RiderProfileController>(RiderProfileController());
      Get.put<NotificationController>(_FixtureNotifications());
      final orders = _FixtureOrders();
      orders.assignedOrders.add(fixtureOrder(multiple: true));
      Get.put<OrdersController>(orders);
      registerFixtureDelivery(
        FixtureDeliveryController(),
        fixtureMap(),
        order: fixtureOrder(),
      );
      await _show(tester, entry.value, width: 320, scale: 1.6);
      expect(tester.takeException(), isNull);
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('standard rider screens render correctly for visual review', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put<AuthController>(AuthController());
    Get.put<NotificationController>(_FixtureNotifications());
    final delivery = FixtureDeliveryController();
    final map = fixtureMap();
    map.updateRiderGpsLocation(const LatLng(6.51, 3.35));
    registerFixtureDelivery(delivery, map, order: fixtureOrder(multiple: true));
    await _show(
      tester,
      const DashboardView(onlineStatusSaver: _memoryOnlineStatus),
    );
    await tester.runAsync(flushRiderAsync);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _savePreview(tester, 'rider-dashboard');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _show(tester, const ActiveDeliveryView());
    expect(tester.takeException(), isNull);
    await _savePreview(tester, 'rider-active-delivery');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _show(tester, const LoginView());
    expect(tester.takeException(), isNull);
    await _savePreview(tester, 'rider-login');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _show(tester, const RegisterView());
    expect(tester.takeException(), isNull);
    await _savePreview(tester, 'rider-registration');
  });
  for (final pickup in [true, false]) {
    testWidgets(
      'late ${pickup ? 'pickup' : 'delivery'} response cannot change a new active order',
      (tester) async {
        final delivery = FixtureDeliveryController();
        registerFixtureDelivery(
          delivery,
          fixtureMap(),
          order: fixtureOrder(pickedUp: !pickup),
        );
        await _show(tester, const Scaffold(body: Text('Fixture')));
        final gate = Completer<void>();
        api.verificationGate = gate.future;
        late Future<bool> completion;
        await tester.runAsync(() async {
          completion = pickup
              ? delivery.confirmPickup('fixture-otp')
              : delivery.confirmDelivery('fixture-otp');
          await flushRiderAsync();
        });
        expect(api.requests.length, 1);
        delivery.setActiveOrder(fixtureOrder(id: 'new-order'));
        gate.complete();
        expect(await tester.runAsync(() => completion), isFalse);
        expect(delivery.activeOrder.value?.id, 'new-order');
        expect(delivery.isGoingToVendor, isTrue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
