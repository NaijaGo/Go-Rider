import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naijago_ridersapp/features/auth/view/google_login_view.dart';
import 'package:naijago_ridersapp/core/auth/google_auth_service.dart';

const session = {
  'httpStatus': 200,
  '_id': 'local-rider',
  'status': 'approved',
  'token': 'local-session',
};
Future<void> open(
  WidgetTester tester,
  Future<Map<String, dynamic>> Function(String, String?) request, {
  Future<String?> Function()? authenticate,
  void Function(Map<String, dynamic>?)? result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final value = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => GoogleLoginView(
                        authenticate:
                            authenticate ?? () async => 'local-google-token',
                        request: request,
                      ),
                    ),
                  );
              result?.call(value);
            },
            child: const Text('Login fixture'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Login fixture'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('approved session returns to existing rider login flow', (
    tester,
  ) async {
    Map<String, dynamic>? returned;
    await open(tester, (token, password) async {
      expect(token, 'local-google-token');
      expect(password, isNull);
      return session;
    }, result: (value) => returned = value);
    expect(returned?['token'], 'local-session');
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets(
    'new rider receives profile onboarding without an operational token',
    (tester) async {
      Map<String, dynamic>? returned;
      await open(
        tester,
        (_, _) async => {
          'httpStatus': 202,
          'code': 'GOOGLE_RIDER_ONBOARDING_REQUIRED',
          'profile': {'email': 'local@gmail.com', 'fullName': 'Local Rider'},
        },
        result: (value) => returned = value,
      );
      expect(returned?['googleIdToken'], 'local-google-token');
      expect(returned?.containsKey('token'), false);
      expect((returned?['profile'] as Map)['email'], 'local@gmail.com');
    },
  );
  for (final status in ['pending', 'rejected', 'suspended']) {
    testWidgets('blocked $status remains a safe error', (tester) async {
      await open(
        tester,
        (_, _) async => {'httpStatus': 401, 'message': 'Account $status'},
      );
      expect(find.text('Account $status'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  }
  testWidgets(
    'existing account password is supplied only on explicit linking',
    (tester) async {
      var calls = 0;
      String? linkedPassword;
      await open(tester, (_, password) async {
        calls++;
        linkedPassword = password;
        return calls == 1
            ? {'httpStatus': 409, 'code': 'GOOGLE_LINK_REQUIRED'}
            : session;
      });
      await tester.enterText(find.byType(TextField), 'existing-password');
      await tester.tap(find.text('Link and continue'));
      await tester.pumpAndSettle();
      expect(linkedPassword, 'existing-password');
      expect(calls, 2);
    },
  );
  testWidgets('malformed session is rejected', (tester) async {
    await open(
      tester,
      (_, _) async => {'httpStatus': 200, '_id': 'local-rider'},
    );
    expect(
      find.text(
        'Unable to connect right now. Please try again or use email and password.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('cancel sends no request', (tester) async {
    var calls = 0;
    await open(tester, (_, _) async {
      calls++;
      return session;
    }, authenticate: () async => null);
    expect(calls, 0);
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets('configuration missing preserves password login', (tester) async {
    await open(
      tester,
      (_, _) async => session,
      authenticate: GoogleAuthService.idToken,
    );
    expect(
      find.text(
        'Google sign-in is not available yet. Please use email and password.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('duplicate requests are disabled while pending', (tester) async {
    final completion = Completer<Map<String, dynamic>>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleLoginView(
          authenticate: () async => 'local-token',
          request: (_, _) {
            calls++;
            return completion.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(FilledButton), findsNothing);
    completion.complete({'httpStatus': 503, 'message': 'Try later.'});
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
