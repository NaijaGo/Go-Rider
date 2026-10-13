import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:naijago_ridersapp/core/theme/app_theme.dart';
import 'package:naijago_ridersapp/features/agreement/controller/rider_agreement_controller.dart';
import 'package:naijago_ridersapp/features/agreement/view/rider_agreement_view.dart';

final _id = 'a' * 24, _hash = 'b' * 64;
Map<String, dynamic> status({
  bool accepted = false,
  String version = '1.0',
  bool full = true,
}) => {
  'success': true,
  'accepted': accepted,
  'requiresAcceptance': !accepted,
  'requiredVersion': version,
  'agreement': {
    'agreementId': _id,
    'version': version,
    'contentHash': _hash,
    if (full)
      'content':
          'Complete fixture agreement.\n\nSafety obligations, delivery responsibilities and full terms supplied by the administrator.',
  },
  'acceptance': accepted
      ? {
          'agreementId': _id,
          'version': version,
          'contentHash': _hash,
          'acceptedAt': '2026-10-13T10:00:00Z',
        }
      : null,
};
DioException failure(int code, {String? reason}) => DioException(
  requestOptions: RequestOptions(),
  response: Response(
    requestOptions: RequestOptions(),
    statusCode: code,
    data: {'code': reason},
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  test(
    'complete server document is required and consent starts unchecked',
    () async {
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => status(),
      );
      await c.load();
      expect(c.agreement.value!.content, contains('full terms'));
      expect(c.consent.value, false);
      expect(c.canSubmit, false);
      c.consent.value = true;
      expect(c.canSubmit, true);
      await c.load();
      expect(c.consent.value, false);
    },
  );
  test('invalid or missing document cannot be accepted', () async {
    for (final key in ['agreementId', 'contentHash', 'content', 'version']) {
      final data = status();
      (data['agreement'] as Map).remove(key);
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => data,
      );
      await c.load();
      c.consent.value = true;
      expect(c.canSubmit, false);
      expect(c.confirmed.value, false);
    }
  });
  test('malformed positive status fails closed', () async {
    for (final key in ['agreementId', 'contentHash', 'version']) {
      final data = status(accepted: true);
      (data['agreement'] as Map).remove(key);
      (data['acceptance'] as Map).remove(key);
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchStatus: () async => data,
      );
      expect(await c.ensureAccepted(navigate: false), false);
    }
  });
  test('no POST before explicit consent', () async {
    var posts = 0;
    final c = RiderAgreementController(
      hasSession: () => true,
      fetchCurrent: () async => status(),
      saveAcceptance: (_) async {
        posts++;
        return status(accepted: true);
      },
    );
    await c.load();
    await c.accept();
    expect(posts, 0);
  });
  test(
    'duplicate taps share one save and require authoritative GET before success',
    () async {
      var posts = 0, continued = 0;
      final gate = Completer<Map<String, dynamic>>();
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => status(),
        saveAcceptance: (body) {
          posts++;
          expect(body['accepted'], true);
          expect(body['contentHash'], _hash);
          return gate.future;
        },
        fetchStatus: () async => status(accepted: true, full: false),
        onAccepted: () => continued++,
      );
      await c.load();
      c.consent.value = true;
      final first = c.accept();
      await c.accept();
      expect(posts, 1);
      expect(continued, 0);
      expect(c.confirmed.value, false);
      gate.complete(status(accepted: true));
      await first;
      expect(c.confirmed.value, true);
      expect(continued, 1);
    },
  );
  test(
    'a successful POST without confirmed GET does not show success',
    () async {
      var continued = false;
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => status(),
        saveAcceptance: (_) async => status(accepted: true),
        fetchStatus: () async => status(),
        onAccepted: () => continued = true,
      );
      await c.load();
      c.consent.value = true;
      await c.accept();
      expect(c.confirmed.value, false);
      expect(c.consent.value, false);
      expect(continued, false);
    },
  );
  test(
    'lost POST response reconciles a saved acceptance without another POST',
    () async {
      var posts = 0, continued = 0;
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => status(),
        saveAcceptance: (_) async {
          posts++;
          throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.receiveTimeout,
          );
        },
        fetchStatus: () async => status(accepted: true),
        onAccepted: () => continued++,
      );
      await c.load();
      c.consent.value = true;
      await c.accept();
      expect(posts, 1);
      expect(continued, 1);
      expect(c.confirmed.value, true);
    },
  );
  test('lost POST and failed reconciliation keep work restricted', () async {
    var posts = 0;
    final c = RiderAgreementController(
      hasSession: () => true,
      fetchCurrent: () async => status(),
      saveAcceptance: (_) async {
        posts++;
        throw failure(503);
      },
      fetchStatus: () async => throw failure(503),
    );
    await c.load();
    c.consent.value = true;
    await c.accept();
    expect(posts, 1);
    expect(c.confirmed.value, false);
    expect(c.consent.value, false);
    expect(c.error.value, isNotEmpty);
    c.consent.value = true;
    expect(c.canSubmit, false);
    await c.accept();
    expect(posts, 1);
  });
  test('outdated version refreshes full text and resets consent', () async {
    var version = '1.0';
    final c = RiderAgreementController(
      hasSession: () => true,
      fetchCurrent: () async => status(version: version),
      saveAcceptance: (_) async {
        version = '2.0';
        throw failure(409, reason: 'RIDER_AGREEMENT_CHANGED');
      },
      fetchStatus: () async => status(version: version),
    );
    await c.load();
    c.consent.value = true;
    await c.accept();
    expect(c.agreement.value!.version, '2.0');
    expect(c.consent.value, false);
    expect(c.error.value, contains('changed'));
  });
  test('expired authentication signs out and never retries POST', () async {
    var expired = 0, reads = 0;
    final c = RiderAgreementController(
      hasSession: () => true,
      fetchCurrent: () async => status(),
      saveAcceptance: (_) async => throw failure(401),
      fetchStatus: () async {
        reads++;
        return status();
      },
      onExpired: () async => expired++,
    );
    await c.load();
    c.consent.value = true;
    await c.accept();
    expect(expired, 1);
    expect(reads, 0);
    expect(c.confirmed.value, false);
  });
  test('session loss and backend failures fail closed', () async {
    final c = RiderAgreementController(
      hasSession: () => false,
      fetchStatus: () async => throw StateError('must not fetch'),
    );
    expect(await c.ensureAccepted(navigate: false), false);
    final failed = RiderAgreementController(
      hasSession: () => true,
      fetchStatus: () async => throw failure(503),
    );
    expect(await failed.ensureAccepted(navigate: false), false);
    expect(failed.error.value, isNotEmpty);
  });
  test(
    'invalidation cancels stale verification and permits a fresh document load',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var reads = 0;
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () {
          reads++;
          return reads == 1
              ? gate.future
              : Future.value(status(version: '2.0'));
        },
      );
      final old = c.load();
      c.invalidate();
      await c.load();
      gate.complete(status());
      await old;
      expect(c.agreement.value!.version, '2.0');
      expect(c.loading.value, false);
    },
  );
  test('parallel checks use one authoritative status request', () async {
    var reads = 0;
    final gate = Completer<Map<String, dynamic>>();
    final c = RiderAgreementController(
      hasSession: () => true,
      fetchStatus: () {
        reads++;
        return gate.future;
      },
    );
    final a = c.ensureAccepted(navigate: false),
        b = c.ensureAccepted(navigate: false);
    gate.complete(status(accepted: true));
    expect(await a, true);
    expect(await b, true);
    expect(reads, 1);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('full agreement layout fits $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = RiderAgreementController(
        hasSession: () => true,
        fetchCurrent: () async => status(),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 850),
              textScaler: const TextScaler.linear(1.6),
            ),
            child: RiderAgreementView(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('complete-rider-agreement')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('complete-rider-agreement')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('I Agree and Accept'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'I Agree and Accept'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(c.canSubmit, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
